package sqs

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

// SQSClient wraps the AWS SQS client
type SQSClient struct {
	client *sqs.Client
}

// NewSQSClient creates a new SQS client
func NewSQSClient(ctx context.Context, region string) (*SQSClient, error) {
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		return nil, err
	}

	return &SQSClient{
		client: sqs.NewFromConfig(cfg),
	}, nil
}

// GetClient returns the underlying SQS client
func (c *SQSClient) GetClient() *sqs.Client {
	return c.client
}
