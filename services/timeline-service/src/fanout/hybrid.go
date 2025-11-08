package fanout

import (
	"container/heap"
	"fmt"

	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/grpc"
	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/models"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

type HybridStrategy struct {
	pushStrategy *PushStrategy
	pullStrategy *PullStrategy
}

func NewHybridStrategy(dynamoClient *dynamodb.Client, postsTableName string, postServiceClient grpc.PostServiceClient, socialGraphServiceClient grpc.SocialGraphServiceClient) *HybridStrategy {
	return &HybridStrategy{
		pushStrategy: NewPushStrategy(dynamoClient, postsTableName),
		pullStrategy: NewPullStrategy(postServiceClient, socialGraphServiceClient),
	}
}

func (s *HybridStrategy) GetName() string {
	return "hybrid"
}

// FanoutPost uses push strategy to store posts in DynamoDB cache
// In hybrid mode, we always cache posts for quick access while also supporting on-demand fetching
func (s *HybridStrategy) FanoutPost(req *models.FanoutRequest, followerIDs []int64) error {
	// Use push strategy to cache the post in followers' timelines for fast access
	return s.pushStrategy.FanoutPost(req, followerIDs)
}

// GetTimeline implements hybrid approach: concurrently fetch from both strategies and merge results
func (s *HybridStrategy) GetTimeline(userID int64, limit int) (*models.TimelineResponse, error) {
	// Use channels to collect results from both strategies concurrently
	type result struct {
		timeline *models.TimelineResponse
		err      error
		source   string
	}

	pushChan := make(chan result, 1)
	pullChan := make(chan result, 1)

	// Execute push strategy concurrently
	go func() {
		timeline, err := s.pushStrategy.GetTimeline(userID, limit)
		pushChan <- result{timeline: timeline, err: err, source: "push"}
	}()

	// Execute pull strategy concurrently
	go func() {
		timeline, err := s.pullStrategy.GetTimeline(userID, limit)
		pullChan <- result{timeline: timeline, err: err, source: "pull"}
	}()

	// Wait for both results
	var pushResult, pullResult result
	for i := 0; i < 2; i++ {
		select {
		case pushResult = <-pushChan:
		case pullResult = <-pullChan:
		}
	}

	// Merge results - combine posts from both strategies
	return s.mergeTimelines(pushResult.timeline, pullResult.timeline, pushResult.err, pullResult.err, limit)
}

// mergeTimelines combines results from push and pull strategies
func (s *HybridStrategy) mergeTimelines(pushTimeline, pullTimeline *models.TimelineResponse, pushErr, pullErr error, limit int) (*models.TimelineResponse, error) {
	// If both strategies failed, return error
	if pushErr != nil && pullErr != nil {
		return nil, fmt.Errorf("both strategies failed - push: %v, pull: %v", pushErr, pullErr)
	}

	// If only one strategy succeeded, return its result
	if pushErr != nil && pullErr == nil {
		return pullTimeline, nil
	}
	if pullErr != nil && pushErr == nil {
		return pushTimeline, nil
	}

	// Both strategies succeeded - merge their timelines using heap for efficient top-k selection
	postMap := make(map[string]models.TimelinePost) // Use map to deduplicate by PostID

	// Add posts from push strategy (cached posts)
	if pushTimeline != nil {
		for _, post := range pushTimeline.Timeline {
			postMap[post.PostID] = post
		}
	}

	// Add posts from pull strategy (real-time posts) - these will overwrite cached ones if duplicate
	if pullTimeline != nil {
		for _, post := range pullTimeline.Timeline {
			postMap[post.PostID] = post
		}
	}

	// Use min-heap to efficiently select top limit posts by creation time
	postHeap := &PostHeap{}
	heap.Init(postHeap)

	for _, post := range postMap {
		if postHeap.Len() < limit {
			// Heap not full, add the post
			heap.Push(postHeap, post)
		} else if post.CreatedAt.After((*postHeap)[0].CreatedAt) {
			// Post is newer than oldest in heap, replace oldest
			heap.Pop(postHeap)
			heap.Push(postHeap, post)
		}
	}

	// Extract posts from heap and store them, then reverse in place
	heapSize := postHeap.Len()
	mergedPosts := make([]models.TimelinePost, heapSize)
	for i := heapSize - 1; i >= 0; i-- {
		mergedPosts[i] = heap.Pop(postHeap).(models.TimelinePost)
	}

	// Calculate total count
	totalCount := len(mergedPosts)
	if pushTimeline != nil && pullTimeline != nil {
		// Use the maximum count from both strategies as an approximation
		if pushTimeline.TotalCount > totalCount {
			totalCount = pushTimeline.TotalCount
		}
		if pullTimeline.TotalCount > totalCount {
			totalCount = pullTimeline.TotalCount
		}
	}

	return &models.TimelineResponse{
		Timeline:   mergedPosts,
		TotalCount: totalCount,
	}, nil
}
