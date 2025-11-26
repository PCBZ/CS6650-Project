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
	client   pb.UserServiceClient
	conn     *grpc.ClientConn
	endpoint string
}

const (
	userServiceReconnectMaxAttempts = 20               // Increased from 5 to 20 to handle slow startup
	userServiceReconnectBaseDelay   = 1 * time.Second  // Increased from 500ms to 1s
	userServiceReconnectMaxDelay    = 10 * time.Second // Maximum delay between retries
)

// ensureConnection ensures the gRPC connection is established, retrying if needed
func (c *userServiceClient) ensureConnection(ctx context.Context) error {
	if c.client != nil && c.conn != nil {
		// Connection already established
		return nil
	}

	// Try to reconnect with retries and exponential backoff
	var lastErr error
	for attempt := 1; attempt <= userServiceReconnectMaxAttempts; attempt++ {
		log.Printf("Attempting to reconnect to User Service at %s (attempt %d/%d)...", c.endpoint, attempt, userServiceReconnectMaxAttempts)

		connCtx, cancel := context.WithTimeout(ctx, 15*time.Second) // Increased timeout from 10s to 15s
		conn, err := grpc.DialContext(
			connCtx,
			c.endpoint,
			grpc.WithTransportCredentials(insecure.NewCredentials()),
			grpc.WithBlock(),
		)
		cancel()

		if err == nil {
			// Close previous connection if exists
			if c.conn != nil {
				_ = c.conn.Close()
			}

			c.conn = conn
			c.client = pb.NewUserServiceClient(conn)
			log.Printf("Successfully reconnected to User Service at %s", c.endpoint)
			return nil
		}

		lastErr = err
		log.Printf("Failed to reconnect to User Service (attempt %d/%d): %v", attempt, userServiceReconnectMaxAttempts, err)

		// Calculate exponential backoff delay with cap
		delay := userServiceReconnectBaseDelay * time.Duration(1<<uint(attempt-1)) // Exponential: 1s, 2s, 4s, 8s...
		if delay > userServiceReconnectMaxDelay {
			delay = userServiceReconnectMaxDelay
		}
		log.Printf("Waiting %v before next retry...", delay)

		// Respect context cancellation
		select {
		case <-ctx.Done():
			return fmt.Errorf("context cancelled while reconnecting to user service: %w", ctx.Err())
		case <-time.After(delay):
			// Continue to next attempt
		}
	}

	return fmt.Errorf("failed to reconnect to user service after %d attempts: %w", userServiceReconnectMaxAttempts, lastErr)
}

// BatchGetUserInfo calls the real User Service via gRPC
func (c *userServiceClient) BatchGetUserInfo(ctx context.Context, userIDs []int64) (*BatchGetUserInfoResponse, error) {
	// Ensure connection is established, retry if needed
	if err := c.ensureConnection(ctx); err != nil {
		return nil, fmt.Errorf("user service client not initialized - connection failed: %w", err)
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

// NewUserServiceClient creates a new User Service client
func NewUserServiceClient(endpoint string) UserServiceClient {
	// Use Dial with Block to ensure connection is established and DNS is resolved
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	log.Printf("Connecting to User Service at %s...", endpoint)
	conn, err := grpc.DialContext(
		ctx,
		endpoint,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(), // Block until connection is established
	)
	if err != nil {
		// Return a client that will retry on first use, but allow service to start
		log.Printf("Warning: Failed to connect to user service at %s: %v. Service will retry on first use.", endpoint, err)
		return &userServiceClient{
			client:   nil,
			conn:     nil,
			endpoint: endpoint,
		}
	}

	log.Printf("User Service client created for %s", endpoint)
	return &userServiceClient{
		client:   pb.NewUserServiceClient(conn),
		conn:     conn,
		endpoint: endpoint,
	}
}

// Close closes the gRPC connection
func (c *userServiceClient) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}
