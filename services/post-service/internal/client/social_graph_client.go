package client

import (
	"context"
	"fmt"
	"log"
	"time"

	pb "github.com/cs6650/proto/social_graph"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type SocialGraphClient struct {
	client  pb.SocialGraphServiceClient
	conn    *grpc.ClientConn
	address string
}

func NewSocialGraphClient(address string) (*SocialGraphClient, error) {
	log.Printf("Creating Social Graph Service client for %s (lazy connection)...", address)

	// Use non-blocking connection - gRPC will connect when first RPC is made
	// This allows the service to start even if social-graph-service isn't ready yet
	// Remove WithBlock() to allow lazy connection
	conn, err := grpc.Dial(
		address,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		// No WithBlock() - connection will be established on first RPC call
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create gRPC client for %s: %w", address, err)
	}

	log.Printf("Social Graph Service client created for %s (will connect on first use)", address)
	return &SocialGraphClient{
		client:  pb.NewSocialGraphServiceClient(conn),
		conn:    conn,
		address: address,
	}, nil
}

func (c *SocialGraphClient) GetFollowers(ctx context.Context, userID int64, limit, offset int32) (*pb.GetFollowersResponse, error) {
	// Add timeout to the context if not already set
	callCtx := ctx
	var cancel context.CancelFunc
	if _, hasTimeout := ctx.Deadline(); !hasTimeout {
		callCtx, cancel = context.WithTimeout(ctx, 10*time.Second)
		defer cancel()
	}

	// Retry logic for connection issues
	var lastErr error
	maxRetries := 3
	for i := 0; i < maxRetries; i++ {
		if i > 0 {
			// Check if context is cancelled before retrying
			select {
			case <-callCtx.Done():
				return nil, fmt.Errorf("context cancelled: %w", callCtx.Err())
			default:
			}

			// Exponential backoff: 1s, 2s
			backoff := time.Duration(1<<uint(i-1)) * time.Second
			log.Printf("Retrying GetFollowers (attempt %d/%d) after %v...", i+1, maxRetries, backoff)
			
			select {
			case <-time.After(backoff):
			case <-callCtx.Done():
				return nil, fmt.Errorf("context cancelled during retry: %w", callCtx.Err())
			}
		}

		resp, err := c.client.GetFollowers(callCtx, &pb.GetFollowersRequest{
			UserId: userID,
			Limit:  limit,
			Offset: offset,
		})

		if err == nil {
			return resp, nil
		}

		lastErr = err
		// Log error but continue retrying
		if i < maxRetries-1 {
			log.Printf("GetFollowers failed (attempt %d/%d): %v", i+1, maxRetries, err)
		}
	}

	return nil, fmt.Errorf("failed to get followers after %d attempts: %w", maxRetries, lastErr)
}

func (c *SocialGraphClient) Close() {
    c.conn.Close()
}


