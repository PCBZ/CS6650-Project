package grpc

import (
	"context"
	"fmt"

	socialgraphpb "github.com/cs6650/proto/social_graph"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
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

// GetFollowing calls GetFollowingList from SocialGraphService
func (c *GRPCSocialGraphServiceClient) GetFollowing(ctx context.Context, userID int64) ([]int64, error) {
	req := &socialgraphpb.GetFollowingListRequest{
		UserId: userID,
	}
	resp, err := c.client.GetFollowingList(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to call GetFollowingList: %w", err)
	}
	if resp.ErrorCode != "" {
		return nil, fmt.Errorf("social graph service error [%s]: %s", resp.ErrorCode, resp.ErrorMessage)
	}
	return resp.FollowingUserIds, nil
}

// NewSocialGraphServiceClient creates a new Social Graph Service client
func NewSocialGraphServiceClient(endpoint string) SocialGraphServiceClient {
	conn, err := grpc.NewClient(
		endpoint,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		panic(fmt.Sprintf("Failed to connect to social graph service at %s: %v", endpoint, err))
	}
	client := socialgraphpb.NewSocialGraphServiceClient(conn)
	return &GRPCSocialGraphServiceClient{
		client: client,
		conn:   conn,
	}
}
