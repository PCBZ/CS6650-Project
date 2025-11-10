package grpc

import (
	"context"
	"fmt"
	"log"
	"time"

	pb "github.com/cs6650/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// UserInfo represents basic user information
type UserInfo struct {
	UserID   int64  `json:"user_id"`
	Username string `json:"username"`
}

// BatchGetUserInfoResponse represents the response for batch user info retrieval
type BatchGetUserInfoResponse struct {
	Users        map[int64]UserInfo `json:"users"`
	NotFound     []int64            `json:"not_found"`
	ErrorCode    string             `json:"error_code,omitempty"`
	ErrorMessage string             `json:"error_message,omitempty"`
}

// UserServiceClient interface for User Service gRPC operations
type UserServiceClient interface {
	BatchGetUserInfo(ctx context.Context, userIDs []int64) (*BatchGetUserInfoResponse, error)
}

// userServiceClient implements UserServiceClient with actual gRPC calls
type userServiceClient struct {
	client pb.UserServiceClient
	conn   *grpc.ClientConn
}

// BatchGetUserInfo calls the real User Service via gRPC
func (c *userServiceClient) BatchGetUserInfo(ctx context.Context, userIDs []int64) (*BatchGetUserInfoResponse, error) {
	// Create gRPC request
	req := &pb.BatchGetUserInfoRequest{
		UserIds: userIDs,
	}

	// Call gRPC service with timeout
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	resp, err := c.client.BatchGetUserInfo(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to call BatchGetUserInfo: %w", err)
	}

	// Check for error in response
	if resp.ErrorCode != "" {
		return nil, fmt.Errorf("user service error: %s - %s", resp.ErrorCode, resp.ErrorMessage)
	}

	// Convert protobuf response to internal format
	users := make(map[int64]UserInfo)
	for userID, userInfo := range resp.Users {
		users[userID] = UserInfo{
			UserID:   userInfo.UserId,
			Username: userInfo.Username,
		}
	}

	return &BatchGetUserInfoResponse{
		Users:        users,
		NotFound:     resp.NotFound,
		ErrorCode:    resp.ErrorCode,
		ErrorMessage: resp.ErrorMessage,
	}, nil
}

// NewUserServiceClient creates a new User Service client with real gRPC connection
func NewUserServiceClient(endpoint string) (UserServiceClient, error) {
	log.Printf("Connecting to User Service at %s...", endpoint)

	// Use Dial with Block to ensure connection is established and DNS is resolved
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	conn, err := grpc.DialContext(
		ctx,
		endpoint,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(), // Block until connection is established
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
