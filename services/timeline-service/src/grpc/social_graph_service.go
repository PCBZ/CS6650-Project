package grpc

import (
	"context"
	"fmt"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	socialgraphpb "github.com/cs6650/proto/social_graph"
)

// SocialGraphServiceClient defines the interface for calling Social Graph Service
type SocialGraphServiceClient interface {
	GetFollowing(ctx context.Context, userID int64) ([]int64, error)
}

// GRPCSocialGraphServiceClient implements SocialGraphServiceClient using gRPC calls
type GRPCSocialGraphServiceClient struct {
	client socialgraphpb.SocialGraphServiceClient
	conn   *grpc.ClientConn
}

// GetFollowing makes gRPC call to Social Graph Service's GetFollowingList method
func (c *GRPCSocialGraphServiceClient) GetFollowing(ctx context.Context, userID int64) ([]int64, error) {
	// Create gRPC request
	req := &socialgraphpb.GetFollowingListRequest{
		UserId: userID,
	}

	// Make gRPC call
	resp, err := c.client.GetFollowingList(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to call social graph service: %w", err)
	}

	// Check for service-level errors
	if resp.ErrorCode != "" {
		return nil, fmt.Errorf("social graph service error [%s]: %s", resp.ErrorCode, resp.ErrorMessage)
	}

	return resp.FollowingUserIds, nil
}

// Close closes the gRPC connection
func (c *GRPCSocialGraphServiceClient) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

// MockSocialGraphServiceClient is a fallback implementation for development
type MockSocialGraphServiceClient struct{}

// GetFollowing implements a mock version that returns some test following list
func (m *MockSocialGraphServiceClient) GetFollowing(ctx context.Context, userID int64) ([]int64, error) {
	// Simulate network delay
	select {
	case <-time.After(5 * time.Millisecond):
	case <-ctx.Done():
		return nil, ctx.Err()
	}

	// Return mock following list (user follows users with IDs userID+1, userID+2, userID+3)
	following := []int64{userID + 1, userID + 2, userID + 3}
	return following, nil
}

// NewSocialGraphServiceClient creates a new Social Graph Service client
func NewSocialGraphServiceClient(endpoint string) SocialGraphServiceClient {
	if endpoint == "" || endpoint == "mock" {
		// Use mock client for development
		return &MockSocialGraphServiceClient{}
	}

	// Create gRPC connection
	conn, err := grpc.NewClient(endpoint, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		// Fallback to mock if connection fails
		fmt.Printf("Failed to connect to social graph service at %s: %v, using mock client\n", endpoint, err)
		return &MockSocialGraphServiceClient{}
	}

	// Create gRPC client
	client := socialgraphpb.NewSocialGraphServiceClient(conn)

	return &GRPCSocialGraphServiceClient{
		client: client,
		conn:   conn,
	}
}
