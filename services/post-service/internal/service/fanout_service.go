package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"post-service/internal/client"
	"post-service/internal/model"
	"time"

	pb "github.com/cs6650/proto/post"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sns"
)

const (
	BatchSize = 1000
)

type FanoutService struct {
	socialGraphClient *client.SocialGraphClient
	snsClient *sns.Client
	snsTopicARN string
}

func NewFanoutService(socialGraphClient *client.SocialGraphClient, snsClient * sns.Client, snsTopicARN string) *FanoutService {
	return &FanoutService{
		socialGraphClient: socialGraphClient,
		snsClient: snsClient,
		snsTopicARN: snsTopicARN,
	}
}

func (s *FanoutService)ExecutePushFanout(ctx context.Context, post *pb.Post) error {
	offset := int32(0)
	for {
		batch, err := s.socialGraphClient.GetFollowers(ctx, post.UserId, BatchSize, offset)
		if err != nil {
			return fmt.Errorf("failed to fetch followers batch through rpc: %w", err)
		}

		// Publish post to SNS for this batch
		message := model.FanoutMessage{
			EventType:     "FeedWrite",
			AuthorID:      post.UserId,
			TargetUserIDs: batch.UserIds,
			Content:       post.Content,
			CreatedTime:   time.Unix(post.Timestamp, 0).UTC(),
		}

		messageJSON, err := json.Marshal(message)
		if err != nil {
			return fmt.Errorf("failed to marshal fanout message: %w", err)
		}

		_, err = s.snsClient.Publish(ctx, &sns.PublishInput{
			TopicArn: aws.String(s.snsTopicARN),
			Message: aws.String(string(messageJSON)),
		})

		if err != nil {
			return fmt.Errorf("failed to publish batch %d to SNS: %w", offset + 1, err)
		}

		// Check if this was the last batch after processing it
		if !batch.HasMore {
			break
		}

		offset += BatchSize
	}
	log.Printf("Successfully published fan-out message to SNS for post %d", post.PostId)
	return nil
}

// publishBatch publishes a single batch of followers to SNS
func (s *FanoutService) publishBatch(ctx context.Context, post *pb.Post, followers []int64, batchNum int) error {
	message := model.FanoutMessage{
		EventType: "FeedWrite",
		AuthorID: post.UserId,
		TargetUserIDs: followers,
		Content: post.Content,
		CreatedTime: time.Unix(post.Timestamp, 0).UTC(),
	}

	messageJSON, err := json.Marshal(message)
	if err != nil {
		return fmt.Errorf("failed to marshal fanout message for batch %d: %w", batchNum, err)
	}

	_, err = s.snsClient.Publish(ctx, &sns.PublishInput{
		TopicArn: aws.String(s.snsTopicARN),
		Message: aws.String(string(messageJSON)),
	})

	if err != nil {
		return fmt.Errorf("failed to publish batch %d to SNS: %w", batchNum, err)
	}
	
	log.Printf("Published batch %d to SNS for post %d (%d followers)", batchNum, post.PostId, len(followers))
	return nil
}
