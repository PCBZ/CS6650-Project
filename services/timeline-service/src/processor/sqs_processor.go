package processor

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/PCBZ/CS6650-Project/timeline-service/src/fanout"
	"github.com/PCBZ/CS6650-Project/timeline-service/src/grpc"
	"github.com/PCBZ/CS6650-Project/timeline-service/src/models"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
)

type SQSProcessor struct {
	sqsClient         *sqs.Client
	queueURL          string
	pushStrategy      fanout.Strategy
	userServiceClient grpc.UserServiceClient
}

func NewSQSProcessor(sqsClient *sqs.Client, queueURL string, pushStrategy fanout.Strategy, userServiceClient grpc.UserServiceClient) *SQSProcessor {
	return &SQSProcessor{
		sqsClient:         sqsClient,
		queueURL:          queueURL,
		pushStrategy:      pushStrategy,
		userServiceClient: userServiceClient,
	}
}

// ProcessMessages polls SQS and processes incoming messages
func (p *SQSProcessor) ProcessMessages(ctx context.Context) error {
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			// Poll for messages
			result, err := p.sqsClient.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
				QueueUrl:            &p.queueURL,
				MaxNumberOfMessages: int32(10),
				WaitTimeSeconds:     int32(20), // Long polling
			})
			if err != nil {
				continue
			}

			// Process each message
			for _, message := range result.Messages {
				if err := p.processMessage(ctx, message); err != nil {
					continue
				}

				// Delete message after successful processing
				p.deleteMessage(ctx, message)
			}
		}
	}
}

// processMessage processes a single SQS message
func (p *SQSProcessor) processMessage(ctx context.Context, message types.Message) error {
	// Parse the SQS message
	var sqsMessage models.SQSFeedMessage
	if err := json.Unmarshal([]byte(*message.Body), &sqsMessage); err != nil {
		return fmt.Errorf("failed to unmarshal SQS message: %w", err)
	}

	// Validate message
	if sqsMessage.EventType != "FeedWrite" {
		return fmt.Errorf("unsupported event type: %s", sqsMessage.EventType)
	}

	// Get author name from User Service via gRPC
	userInfoResponse, err := p.userServiceClient.BatchGetUserInfo(ctx, []int64{sqsMessage.AuthorID})
	if err != nil {
		return fmt.Errorf("failed to get author info: %w", err)
	}

	// Check if author was found
	authorInfo, found := userInfoResponse.Users[sqsMessage.AuthorID]
	if !found {
		return fmt.Errorf("author not found: %d", sqsMessage.AuthorID)
	}

	// Convert to FanoutRequest with author username
	fanoutReq := sqsMessage.ToFanoutRequest(authorInfo.Username)

	// Process through push strategy (fan-out to DynamoDB)
	if err := p.pushStrategy.FanoutPost(fanoutReq, sqsMessage.TargetUserIDs); err != nil {
		return fmt.Errorf("failed to fanout post: %w", err)
	}

	return nil
}

// deleteMessage deletes a message from SQS queue
func (p *SQSProcessor) deleteMessage(ctx context.Context, message types.Message) error {
	_, err := p.sqsClient.DeleteMessage(ctx, &sqs.DeleteMessageInput{
		QueueUrl:      &p.queueURL,
		ReceiptHandle: message.ReceiptHandle,
	})
	return err
}
