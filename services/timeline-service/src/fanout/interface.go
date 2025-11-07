package fanout

import (
	"github.com/PCBZ/CS6650-Project/timeline-service/src/models"
)

// Strategy defines the interface for different fan-out algorithms
type Strategy interface {
	// GetName returns the strategy name
	GetName() string

	// FanoutPost distributes a post to followers' timelines
	FanoutPost(req *models.FanoutRequest, followerIDs []int64) error

	// GetTimeline retrieves the timeline for a user
	GetTimeline(userID int64, limit int) (*models.TimelineResponse, error)
}
