package grpc

import (
	"context"
	"fmt"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	postpb "github.com/PCBZ/CS6650-Project/timeline-service/proto/post"
	"github.com/PCBZ/CS6650-Project/timeline-service/src/models"
)

// PostServiceClient defines the interface for calling Post Service
type PostServiceClient interface {
	BatchGetPosts(ctx context.Context, userIDs []int64, limit int32) (map[int64][]models.TimelinePost, error)
}

// GRPCPostServiceClient implements PostServiceClient using gRPC calls
type GRPCPostServiceClient struct {
	client postpb.PostServiceClient
	conn   *grpc.ClientConn
}

// BatchGetPosts makes gRPC call to Post Service's BatchGetPosts method
func (c *GRPCPostServiceClient) BatchGetPosts(ctx context.Context, userIDs []int64, limit int32) (map[int64][]models.TimelinePost, error) {
	// Create gRPC request
	req := &postpb.BatchGetPostsRequest{
		UserIds: userIDs,
		Limit:   limit,
	}

	// Make gRPC call
	resp, err := c.client.BatchGetPosts(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to call post service: %w", err)
	}

	// Check for service-level errors
	if resp.ErrorMessage != "" {
		return nil, fmt.Errorf("post service error: %s", resp.ErrorMessage)
	}

	// Convert protobuf response to our timeline post format
	result := make(map[int64][]models.TimelinePost)
	for userID, userPosts := range resp.UserPosts {
		var timelinePosts []models.TimelinePost

		for _, post := range userPosts.Posts {
			// Convert Unix timestamp to time.Time
			createdAt := time.Unix(post.Timestamp, 0)

			timelinePosts = append(timelinePosts, models.TimelinePost{
				PostID:     fmt.Sprintf("%d", post.PostId), // Convert int64 to string
				UserID:     0,                              // Timeline owner - will be set by caller
				AuthorID:   post.UserId,
				AuthorName: "", // Will be filled by user service
				Content:    post.Content,
				CreatedAt:  createdAt,
			})
		}

		result[userID] = timelinePosts
	}

	return result, nil
}

// Close closes the gRPC connection
func (c *GRPCPostServiceClient) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

// MockPostServiceClient is a fallback implementation for development
type MockPostServiceClient struct{}

// BatchGetPosts implements a mock version that returns sample posts
func (m *MockPostServiceClient) BatchGetPosts(ctx context.Context, userIDs []int64, limit int32) (map[int64][]models.TimelinePost, error) {
	// Simulate network delay
	select {
	case <-time.After(10 * time.Millisecond):
	case <-ctx.Done():
		return nil, ctx.Err()
	}

	result := make(map[int64][]models.TimelinePost)

	// Generate mock posts for each requested user ID
	for _, userID := range userIDs {
		var posts []models.TimelinePost

		// Generate up to limit posts per user
		postsCount := int32(3) // Mock: generate 3 posts per user
		if limit > 0 && limit < postsCount {
			postsCount = limit
		}

		for i := int32(0); i < postsCount; i++ {
			posts = append(posts, models.TimelinePost{
				PostID:     fmt.Sprintf("mock-post-%d-%d", userID, i),
				UserID:     0,      // Will be set by caller (timeline owner)
				AuthorID:   userID, // Post author
				AuthorName: fmt.Sprintf("user_%d", userID),
				Content:    fmt.Sprintf("Mock post %d from user %d", i, userID),
				CreatedAt:  time.Now().Add(-time.Duration(i) * time.Hour),
			})
		}

		result[userID] = posts
	}

	return result, nil
}

// NewPostServiceClient creates a new Post Service client
func NewPostServiceClient(endpoint string) PostServiceClient {
	if endpoint == "" || endpoint == "mock" {
		// Use mock client for development
		return &MockPostServiceClient{}
	}

	// Create gRPC connection
	conn, err := grpc.NewClient(endpoint, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		// Fallback to mock if connection fails
		fmt.Printf("Failed to connect to post service at %s: %v, using mock client\n", endpoint, err)
		return &MockPostServiceClient{}
	}

	// Create gRPC client
	client := postpb.NewPostServiceClient(conn)

	return &GRPCPostServiceClient{
		client: client,
		conn:   conn,
	}
}
