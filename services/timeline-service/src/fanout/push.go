package fanout

import (
	"context"
	"fmt"
	"time"

	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/models"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

type PushStrategy struct {
	dynamoClient   *dynamodb.Client
	postsTableName string
	batchSize      int
}

func NewPushStrategy(dynamoClient *dynamodb.Client, postsTableName string) *PushStrategy {
	return &PushStrategy{
		dynamoClient:   dynamoClient,
		postsTableName: postsTableName,
		batchSize:      25, // DynamoDB batch write limit
	}
}

func (s *PushStrategy) GetName() string {
	return "push"
}

// FanoutPost writes the post to all followers' timelines
func (s *PushStrategy) FanoutPost(req *models.FanoutRequest, followerIDs []int64) error {
	if len(followerIDs) == 0 {
		return nil
	}

	// Process in batches
	for i := 0; i < len(followerIDs); i += s.batchSize {
		end := i + s.batchSize
		if end > len(followerIDs) {
			end = len(followerIDs)
		}

		batch := followerIDs[i:end]
		if err := s.writeBatch(req, batch); err != nil {
			return fmt.Errorf("failed to write batch: %w", err)
		}
	}

	return nil
}

func (s *PushStrategy) writeBatch(req *models.FanoutRequest, followerIDs []int64) error {
	writeRequests := make([]types.WriteRequest, 0, len(followerIDs))

	// Use the create time from the request in ISO 8601 format
	timeString := req.CreatedAt.Format(time.RFC3339)

	for _, followerID := range followerIDs {
		// Create timeline entry for each follower
		timelinePostID := fmt.Sprintf("%s_%d", req.PostID, followerID)

		item := map[string]types.AttributeValue{
			"post_id":    &types.AttributeValueMemberS{Value: timelinePostID},
			"user_id":    &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", followerID)},   // 时间线拥有者(接收者)
			"author_id":  &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", req.AuthorID)}, // 帖子作者
			"username":   &types.AttributeValueMemberS{Value: req.AuthorName},                  // 作者用户名
			"content":    &types.AttributeValueMemberS{Value: req.Content},
			"created_at": &types.AttributeValueMemberS{Value: timeString},
		}

		writeRequests = append(writeRequests, types.WriteRequest{
			PutRequest: &types.PutRequest{
				Item: item,
			},
		})
	}

	_, err := s.dynamoClient.BatchWriteItem(context.Background(), &dynamodb.BatchWriteItemInput{
		RequestItems: map[string][]types.WriteRequest{
			s.postsTableName: writeRequests,
		},
	})

	return err
}

// GetTimeline retrieves posts from a user's timeline
func (s *PushStrategy) GetTimeline(userID int64, limit int) (*models.TimelineResponse, error) {
	// Query posts table using UserPostsIndex to get user's timeline
	input := &dynamodb.QueryInput{
		TableName:              aws.String(s.postsTableName),
		IndexName:              aws.String("UserPostsIndex"),
		KeyConditionExpression: aws.String("user_id = :userId"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":userId": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", userID)},
		},
		ScanIndexForward: aws.Bool(false), // DESC order (newest first)
		Limit:            aws.Int32(int32(limit)),
	}

	result, err := s.dynamoClient.Query(context.Background(), input)
	if err != nil {
		return nil, fmt.Errorf("failed to query timeline: %w", err)
	}

	if result.Count == 0 {
		return &models.TimelineResponse{
			Timeline:   []models.TimelinePost{},
			TotalCount: 0,
		}, nil
	}

	// Unmarshal items to TimelinePost
	var timelinePosts []models.TimelinePost
	err = attributevalue.UnmarshalListOfMaps(result.Items, &timelinePosts)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal posts: %w", err)
	}

	return &models.TimelineResponse{
		Timeline:   timelinePosts,
		TotalCount: int(result.Count),
	}, nil
}
