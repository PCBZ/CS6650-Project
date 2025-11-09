package db

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

type DynamoDBClient struct {
	client *dynamodb.Client
}

func NewDynamoDBClient(ctx context.Context, region string) (*DynamoDBClient, error) {
	// Load config with explicit credential providers to avoid IMDS issues
	cfg, err := config.LoadDefaultConfig(ctx, 
		config.WithRegion(region),
		config.WithEC2IMDSRegion(),  // Enable IMDSv2 support
	)
	if err != nil {
		return nil, fmt.Errorf("unable to load AWS config: %w", err)
	}

	client := dynamodb.NewFromConfig(cfg)
	return &DynamoDBClient{client: client}, nil
}

func (d *DynamoDBClient) GetClient() *dynamodb.Client {
	return d.client
}
