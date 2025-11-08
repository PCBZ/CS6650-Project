package repository

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"

	pb "github.com/cs6650/proto/post"
)

type PostRepository struct{
	client *dynamodb.Client
	tableName string
}

// Create a new repository
func NewPostRepository(client *dynamodb.Client, tableName string) *PostRepository {
	return &PostRepository{
		client: client,
		tableName: tableName,
	}
}

// Create a new post and save to dynamodb 
func(r *PostRepository) CreatePost(ctx context.Context, post *pb.Post) error {
	item, err := attributevalue.MarshalMap(post)
	if err != nil {
		return fmt.Errorf("failed to marshal post: %w", err)
	}

	_, err = r.client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(r.tableName),
		Item: item,
	})

	return err
}

// Retrieves a single post by PostID
func(r *PostRepository)GetPost(ctx context.Context, postID int64)(*pb.Post, error) {
	result, err := r.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(r.tableName),
		Key: map[string]types.AttributeValue{
			"post_id": &types.AttributeValueMemberN{
				Value: fmt.Sprintf("%d", postID),
			},
		},
	})

	if err != nil{
		return nil, err
	}

	if result.Item == nil {
		return nil, fmt.Errorf("post not found")
	}

	var post pb.Post
	err = attributevalue.UnmarshalMap(result.Item, &post)
	return &post, err
}

// Retrieve recent posts for multiple users
func(r *PostRepository) GetPostByUserIDs(ctx context.Context, userIDs []int64, limit int32)(map[int64][]*pb.Post, error){
	result := make(map[int64][]*pb.Post)

	for _, userID := range userIDs{
		posts, err := r.GetPostByUserID(ctx, userID, limit)
		if err != nil{
			return nil, err
		}
		result[userID] = posts
	}
	return result, nil
}

// Retrieve recent posts for single user
func(r *PostRepository) GetPostByUserID(ctx context.Context, userID int64, limit int32)([]*pb.Post, error){
	result, err := r.client.Query(ctx, &dynamodb.QueryInput{
		TableName: aws.String(r.tableName),
		IndexName: aws.String("user_id-index"), // Use GSI for querying by user_id
		KeyConditionExpression: aws.String("user_id = :uid"),
		ExpressionAttributeValues: map[string]types.AttributeValue {
			":uid": &types.AttributeValueMemberN{
				Value: fmt.Sprintf("%d", userID),
			},
		},
		ScanIndexForward: aws.Bool(false),// Descending order
		Limit: aws.Int32(limit),
	})

	if err != nil {
		return nil, err
	}

	var posts []*pb.Post
	for _, item := range result.Items {
		var post pb.Post
		if err := attributevalue.UnmarshalMap(item, &post); err != nil {
			return nil, err
		}
		posts = append(posts, &post)
	}
	return posts, err
}