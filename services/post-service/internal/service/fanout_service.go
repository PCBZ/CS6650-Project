package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"post-service/internal/client"
	"post-service/internal/model"
	pb "post-service/pkg/generated/post"
	"time"

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
	// Fetch all followers
	allFollowers :=  []int64{}
	offset := int32(0)
	for {
		batch, err := s.socialGraphClient.GetFollowers(ctx, post.UserId, BatchSize, offset)
		if err != nil {
			return fmt.Errorf("failed to fetch followers batch through rpc: %w", err)
		}

		allFollowers = append(allFollowers, batch.UserIds...)
		if ! batch.HasMore {
			break
		}
		offset += BatchSize

		// Publish post to SNS
		message := model.FanoutMessage{
			EventType: "FeedWrite",
			AuthorID: post.UserId,
			TargetUserIDs: batch.UserIds,
			Content: post.Content,
			CreatedTime: time.Unix(post.Timestamp, 0).UTC().Format("2006-01-02T15:04:05.000Z"),
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
        	return fmt.Errorf("failed to publish to SNS: %w", err)
    	}
	}
	log.Printf("Successfully published fan-out message to SNS for post %d", post.PostId)
	return nil	
}
