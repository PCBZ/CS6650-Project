package models

import (
	"time"

	"github.com/google/uuid"
)

// SQSFeedMessage represents the SQS message from Post Service
type SQSFeedMessage struct {
	EventType     string    `json:"event_type"`
	AuthorID      int64     `json:"author_id"`
	TargetUserIDs []int64   `json:"target_user_ids"`
	Content       string    `json:"content"`
	CreatedTime   time.Time `json:"created_time"`
}

// ToFanoutRequest converts SQS message to FanoutRequest
func (msg *SQSFeedMessage) ToFanoutRequest(authorName string) *FanoutRequest {
	// Generate a new UUID for the post ID
	postID := uuid.New().String()

	return &FanoutRequest{
		PostID:      postID,
		AuthorID:    msg.AuthorID,
		AuthorName:  authorName,
		Content:     msg.Content,
		FollowerIDs: msg.TargetUserIDs,
		CreatedAt:   msg.CreatedTime,
	}
}
