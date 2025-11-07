package fanout

import (
	"container/heap"
	"context"
	"fmt"
	"sort"

	"github.com/PCBZ/CS6650-Project/timeline-service/src/grpc"
	"github.com/PCBZ/CS6650-Project/timeline-service/src/models"
)

// PostHeap implements heap.Interface for models.TimelinePost
// This is a min-heap based on creation time (oldest posts at top)
type PostHeap []models.TimelinePost

func (h PostHeap) Len() int           { return len(h) }
func (h PostHeap) Less(i, j int) bool { return h[i].CreatedAt.Before(h[j].CreatedAt) } // Min-heap: oldest first
func (h PostHeap) Swap(i, j int)      { h[i], h[j] = h[j], h[i] }

func (h *PostHeap) Push(x interface{}) {
	*h = append(*h, x.(models.TimelinePost))
}

func (h *PostHeap) Pop() interface{} {
	old := *h
	n := len(old)
	x := old[n-1]
	*h = old[0 : n-1]
	return x
}

type PullStrategy struct {
	postServiceClient        grpc.PostServiceClient
	socialGraphServiceClient grpc.SocialGraphServiceClient
}

func NewPullStrategy(postServiceClient grpc.PostServiceClient, socialGraphServiceClient grpc.SocialGraphServiceClient) *PullStrategy {
	return &PullStrategy{
		postServiceClient:        postServiceClient,
		socialGraphServiceClient: socialGraphServiceClient,
	}
}

func (s *PullStrategy) GetName() string {
	return "pull"
}

// FanoutPost does nothing for pull strategy - posts are not pre-distributed
func (s *PullStrategy) FanoutPost(req *models.FanoutRequest, followerIDs []int64) error {
	// No fan-out needed for pull strategy
	return nil
}

// GetTimeline retrieves posts from followed users in real-time via gRPC calls
func (s *PullStrategy) GetTimeline(userID int64, limit int) (*models.TimelineResponse, error) {
	ctx := context.Background()

	// Step 1: Get list of users this user follows from Social Graph Service
	followingList, err := s.socialGraphServiceClient.GetFollowing(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get following list from Social Graph Service: %w", err)
	}

	// If user doesn't follow anyone, return empty timeline
	if len(followingList) == 0 {
		return &models.TimelineResponse{
			Timeline:   []models.TimelinePost{},
			TotalCount: 0,
		}, nil
	}

	// Step 2: Get recent posts from each followed user via Post Service
	// Request more posts per user to ensure we have enough for sorting and limiting
	postsPerUser := int32(limit) // Request 'limit' posts from each user
	if postsPerUser < 10 {
		postsPerUser = 10 // Minimum 10 posts per user to ensure good coverage
	}

	userPostsMap, err := s.postServiceClient.BatchGetPosts(ctx, followingList, postsPerUser)
	if err != nil {
		return nil, fmt.Errorf("failed to get posts from Post Service: %w", err)
	}

	// Step 3: Use heap to efficiently get the newest 'limit' posts
	var topPosts []models.TimelinePost

	if limit <= 0 {
		limit = 10 // Default to 10 if limit is invalid
	}

	// Use a min-heap to maintain the top 'limit' newest posts
	minHeap := &PostHeap{}
	heap.Init(minHeap)

	// Process all posts from all users
	for _, userPosts := range userPostsMap {
		for _, post := range userPosts {
			if minHeap.Len() < limit {
				// Heap not full, add the post
				heap.Push(minHeap, post)
			} else if post.CreatedAt.After((*minHeap)[0].CreatedAt) {
				// This post is newer than the oldest post in heap
				heap.Pop(minHeap)        // Remove oldest
				heap.Push(minHeap, post) // Add newer post
			}
		}
	}

	// Extract posts from heap and convert to slice
	topPosts = make([]models.TimelinePost, minHeap.Len())
	for i := len(topPosts) - 1; i >= 0; i-- {
		topPosts[i] = heap.Pop(minHeap).(models.TimelinePost)
	}

	// Final sort of the top posts (newest first)
	// This is efficient since we only sort 'limit' posts, not all posts
	sort.Slice(topPosts, func(i, j int) bool {
		return topPosts[i].CreatedAt.After(topPosts[j].CreatedAt)
	})

	return &models.TimelineResponse{
		Timeline:   topPosts,
		TotalCount: len(topPosts),
	}, nil
}
