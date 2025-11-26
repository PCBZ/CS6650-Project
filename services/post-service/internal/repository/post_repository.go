package repository

import (
	"context"
	"fmt"
	"log"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"

	pb "github.com/cs6650/proto/post"
)

type PostRepository struct {
	client    *dynamodb.Client
	tableName string
}

// Create a new repository
func NewPostRepository(client *dynamodb.Client, tableName string) *PostRepository {
	return &PostRepository{
		client:    client,
		tableName: tableName,
	}
}

// Create a new post and save to dynamodb
func (r *PostRepository) CreatePost(ctx context.Context, post *pb.Post) error {
	// Manually create DynamoDB item with correct field names (post_id, user_id, etc.)
	item := map[string]types.AttributeValue{
		"post_id": &types.AttributeValueMemberN{
			Value: fmt.Sprintf("%d", post.PostId),
		},
		"user_id": &types.AttributeValueMemberN{
			Value: fmt.Sprintf("%d", post.UserId),
		},
		"content": &types.AttributeValueMemberS{
			Value: post.Content,
		},
		"timestamp": &types.AttributeValueMemberN{
			Value: fmt.Sprintf("%d", post.Timestamp),
		},
	}

	_, err := r.client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(r.tableName),
		Item:      item,
	})

	if err != nil {
		return fmt.Errorf("failed to create post: %w", err)
	}

	return nil
}

// Retrieves a single post by PostID
func (r *PostRepository) GetPost(ctx context.Context, postID int64) (*pb.Post, error) {
	result, err := r.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(r.tableName),
		Key: map[string]types.AttributeValue{
			"post_id": &types.AttributeValueMemberN{
				Value: fmt.Sprintf("%d", postID),
			},
		},
	})

	if err != nil {
		return nil, err
	}

	if result.Item == nil {
		return nil, fmt.Errorf("post not found")
	}

	var post pb.Post
	err = attributevalue.UnmarshalMap(result.Item, &post)
	return &post, err
}

// batchCheckUsersHasPosts performs parallel COUNT queries to check which users have posts
func (r *PostRepository) batchCheckUsersHasPosts(ctx context.Context, userIDs []int64) (map[int64]bool, error) {
	if len(userIDs) == 0 {
		return make(map[int64]bool), nil
	}

	hasPostsMap := make(map[int64]bool, len(userIDs))
	hasPostsMutex := &sync.Mutex{}
	maxWorkers := min(50, len(userIDs))

	// Create worker pool for COUNT queries
	userIDChan := make(chan int64, len(userIDs))
	for _, userID := range userIDs {
		userIDChan <- userID
	}
	close(userIDChan)

	var wg sync.WaitGroup
	errChan := make(chan error, len(userIDs))

	// Launch worker pool for parallel COUNT queries
	for i := 0; i < maxWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()

			for userID := range userIDChan {
				hasPosts, err := r.checkUserHasPosts(ctx, userID)
				if err != nil {
					errChan <- fmt.Errorf("failed to check posts for user %d: %w", userID, err)
					continue
				}

				hasPostsMutex.Lock()
				hasPostsMap[userID] = hasPosts
				hasPostsMutex.Unlock()
			}
		}()
	}

	wg.Wait()
	close(errChan)

	// Check for errors
	for err := range errChan {
		if err != nil {
			return nil, err
		}
	}

	return hasPostsMap, nil
}

// Retrieve recent posts for multiple users (parallel execution with worker pool for better performance)
func (r *PostRepository) GetPostByUserIDs(ctx context.Context, userIDs []int64, limit int32) (map[int64][]*pb.Post, error) {
	// Check if we're in hybrid mode (read from environment variable)
	postStrategy := os.Getenv("POST_STRATEGY")
	checkCountFirst := postStrategy == "hybrid"
	startTime := time.Now()
	// Pre-allocate result map with expected capacity to reduce reallocation
	result := make(map[int64][]*pb.Post, len(userIDs))
	resultMutex := &sync.Mutex{}

	// If in hybrid mode, first batch check which users have posts
	var usersToQuery []int64
	if checkCountFirst {
		countStart := time.Now()
		hasPostsMap, err := r.batchCheckUsersHasPosts(ctx, userIDs)
		if err != nil {
			return nil, fmt.Errorf("failed to batch check users has posts: %w", err)
		}
		countDuration := time.Since(countStart)

		// Filter users that have posts
		usersToQuery = make([]int64, 0, len(userIDs))
		for _, userID := range userIDs {
			if hasPostsMap[userID] {
				usersToQuery = append(usersToQuery, userID)
			} else {
				// User has no posts, set empty result immediately
				result[userID] = []*pb.Post{}
			}
		}

		log.Printf("[BatchGetPosts] Batch COUNT check: users=%d, has_posts=%d, no_posts=%d, duration=%v",
			len(userIDs), len(usersToQuery), len(userIDs)-len(usersToQuery), countDuration)
	} else {
		// Not in hybrid mode, query all users
		usersToQuery = userIDs
	}

	// If no users have posts, return early
	if len(usersToQuery) == 0 {
		totalDuration := time.Since(startTime)
		log.Printf("[BatchGetPosts] Completed: users=%d, duration=%v (all users have no posts)",
			len(userIDs), totalDuration)
		return result, nil
	}

	// Limit concurrent goroutines to avoid resource exhaustion
	maxWorkers := min(50, len(usersToQuery))

	// Create worker pool using buffered channel
	userIDChan := make(chan int64, len(usersToQuery))
	for _, userID := range usersToQuery {
		userIDChan <- userID
	}
	close(userIDChan)

	// Use WaitGroup to wait for all workers to complete
	var wg sync.WaitGroup
	errChan := make(chan error, len(usersToQuery))

	// Launch worker pool - now we know these users have posts, so skip COUNT check
	for i := 0; i < maxWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()

			for userID := range userIDChan {
				queryStart := time.Now()
				// Skip COUNT check since we already verified these users have posts
				posts, err := r.GetPostByUserID(ctx, userID, limit, false)
				queryDuration := time.Since(queryStart)

				if err != nil {
					errChan <- fmt.Errorf("failed to get posts for user %d: %w", userID, err)
					continue
				}

				// Optimization: Only write to result map if posts exist or if we want to track empty results
				// For hybrid mode, we may want to skip empty results to reduce map size
				// But for consistency, we'll include all users (even with empty posts)
				resultMutex.Lock()
				result[userID] = posts
				resultMutex.Unlock()

				// Log slow queries for analysis
				if queryDuration > 50*time.Millisecond {
					log.Printf("[BatchGetPosts] Slow query: user_id=%d, duration=%v, posts=%d", userID, queryDuration, len(posts))
				}
			}
		}()
	}

	// Wait for all workers to complete
	wg.Wait()
	close(errChan)

	// Check for errors
	for err := range errChan {
		if err != nil {
			return nil, err
		}
	}

	totalDuration := time.Since(startTime)
	log.Printf("[BatchGetPosts] Completed: users=%d, duration=%v",
		len(userIDs), totalDuration)

	return result, nil
}

// checkUserHasPosts quickly checks if a user has any posts using COUNT query
func (r *PostRepository) checkUserHasPosts(ctx context.Context, userID int64) (bool, error) {
	result, err := r.client.Query(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(r.tableName),
		IndexName:              aws.String("user_id-index"),
		KeyConditionExpression: aws.String("user_id = :uid"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":uid": &types.AttributeValueMemberN{
				Value: fmt.Sprintf("%d", userID),
			},
		},
		Select: types.SelectCount, // Only return count, not data
		Limit:  aws.Int32(1),      // Only need to know if count > 0
	})

	if err != nil {
		return false, err
	}

	return result.Count > 0, nil
}

// Retrieve recent posts for single user
func (r *PostRepository) GetPostByUserID(ctx context.Context, userID int64, limit int32, checkCountFirst bool) ([]*pb.Post, error) {
	// Optimization for hybrid mode: First check if user has posts using COUNT query
	// This avoids fetching data for users with no posts
	if checkCountFirst {
		hasPosts, err := r.checkUserHasPosts(ctx, userID)
		if err != nil {
			return nil, err
		}

		if !hasPosts {
			// User has no posts, return empty slice immediately
			return []*pb.Post{}, nil
		}
	}

	// User has posts (or checkCountFirst is false), fetch the actual data
	result, err := r.client.Query(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(r.tableName),
		IndexName:              aws.String("user_id-index"), // Use GSI for querying by user_id
		KeyConditionExpression: aws.String("user_id = :uid"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":uid": &types.AttributeValueMemberN{
				Value: fmt.Sprintf("%d", userID),
			},
		},
		ScanIndexForward: aws.Bool(false), // Descending order
		Limit:            aws.Int32(limit),
	})

	if err != nil {
		return nil, err
	}

	var posts []*pb.Post
	for _, item := range result.Items {
		post := &pb.Post{}

		// Manually extract and convert fields due to DynamoDB type vs protobuf type mismatch
		// post_id is stored as Number in DynamoDB
		if postIDAttr, ok := item["post_id"].(*types.AttributeValueMemberN); ok {
			if parsed, err := strconv.ParseInt(postIDAttr.Value, 10, 64); err == nil {
				post.PostId = parsed
			}
		}

		// user_id is stored as Number in DynamoDB
		if userIDAttr, ok := item["user_id"].(*types.AttributeValueMemberN); ok {
			if parsed, err := strconv.ParseInt(userIDAttr.Value, 10, 64); err == nil {
				post.UserId = parsed
			}
		}

		// content is stored as String
		if contentAttr, ok := item["content"].(*types.AttributeValueMemberS); ok {
			post.Content = contentAttr.Value
		}

		// timestamp is stored as Number
		if timestampAttr, ok := item["timestamp"].(*types.AttributeValueMemberN); ok {
			if parsed, err := strconv.ParseInt(timestampAttr.Value, 10, 64); err == nil {
				post.Timestamp = parsed
			}
		}

		posts = append(posts, post)
	}
	return posts, nil
}
