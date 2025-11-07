package grpc

import (
	"context"
	"fmt"
)

// UserInfo represents basic user information
type UserInfo struct {
	UserID   int64  `json:"user_id"`
	Username string `json:"username"`
}

// BatchGetUserInfoRequest represents the request for batch user info retrieval
type BatchGetUserInfoRequest struct {
	UserIDs []int64 `json:"user_ids"`
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

// MockUserServiceClient is a temporary implementation for development
type MockUserServiceClient struct{}

// BatchGetUserInfo implements a mock version that returns placeholder usernames
func (m *MockUserServiceClient) BatchGetUserInfo(ctx context.Context, userIDs []int64) (*BatchGetUserInfoResponse, error) {
	users := make(map[int64]UserInfo)
	
	// Generate mock usernames for all requested user IDs
	for _, userID := range userIDs {
		users[userID] = UserInfo{
			UserID:   userID,
			Username: fmt.Sprintf("user_%d", userID),
		}
	}

	return &BatchGetUserInfoResponse{
		Users:    users,
		NotFound: []int64{}, // No users not found in mock
	}, nil
}

// NewUserServiceClient creates a new User Service client
// In real implementation, this would establish gRPC connection
func NewUserServiceClient(endpoint string) UserServiceClient {
	// TODO: Replace with actual gRPC client implementation
	return &MockUserServiceClient{}
}
