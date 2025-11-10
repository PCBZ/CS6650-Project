package main

import (
	"context"
	"fmt"
	"log"
	"time"

	pb "github.com/cs6650/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// UserServiceClient interface for User Service gRPC operations
type UserServiceClient interface {
	BatchGetUserInfo(ctx context.Context, userIDs []int64) (map[int64]*pb.UserInfo, []int64, error)
	Close() error
}

// userServiceClient implements UserServiceClient with actual gRPC calls
type userServiceClient struct {
	client pb.UserServiceClient
	conn   *grpc.ClientConn
}

// BatchGetUserInfo calls the User Service via gRPC to get user information
func (c *userServiceClient) BatchGetUserInfo(ctx context.Context, userIDs []int64) (map[int64]*pb.UserInfo, []int64, error) {
	if len(userIDs) == 0 {
		return make(map[int64]*pb.UserInfo), nil, nil
	}

	// Create gRPC request
	req := &pb.BatchGetUserInfoRequest{
		UserIds: userIDs,
	}

	// Call gRPC service with timeout
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	resp, err := c.client.BatchGetUserInfo(ctx, req)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to call BatchGetUserInfo: %w", err)
	}

	// Check for error in response
	if resp.ErrorCode != "" {
		return nil, nil, fmt.Errorf("user service error: %s - %s", resp.ErrorCode, resp.ErrorMessage)
	}

	return resp.Users, resp.NotFound, nil
}

// Close closes the gRPC connection
func (c *userServiceClient) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

// NewUserServiceClient creates a new User Service client with real gRPC connection
func NewUserServiceClient(endpoint string) (UserServiceClient, error) {
	log.Printf("Connecting to User Service at %s...", endpoint)

	// Establish gRPC connection
	conn, err := grpc.NewClient(
		endpoint,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create User Service client for %s: %w", endpoint, err)
	}

	log.Printf("User Service client created for %s", endpoint)

	return &userServiceClient{
		client: pb.NewUserServiceClient(conn),
		conn:   conn,
	}, nil
}

// MockUserServiceClient is a fallback implementation for development/testing
type MockUserServiceClient struct{}

// BatchGetUserInfo returns mock user information
func (m *MockUserServiceClient) BatchGetUserInfo(ctx context.Context, userIDs []int64) (map[int64]*pb.UserInfo, []int64, error) {
	users := make(map[int64]*pb.UserInfo)
	for _, userID := range userIDs {
		users[userID] = &pb.UserInfo{
			UserId:   userID,
			Username: fmt.Sprintf("user_%d", userID),
		}
	}
	return users, nil, nil
}

// Close does nothing for mock client
func (m *MockUserServiceClient) Close() error {
	return nil
}
