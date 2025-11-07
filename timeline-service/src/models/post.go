package models

import "time"

type Post struct {
	PostID    string    `json:"post_id" dynamodbav:"post_id"`
	UserID    int64     `json:"user_id" dynamodbav:"user_id"`
	Username  string    `json:"username" dynamodbav:"username"`
	Content   string    `json:"content" dynamodbav:"content"`
	CreatedAt time.Time `json:"created_at" dynamodbav:"created_at"`
}

type TimelinePost struct {
	PostID     string    `json:"post_id" dynamodbav:"post_id"`
	UserID     int64     `json:"user_id" dynamodbav:"user_id"`      // 时间线拥有者ID (接收者)
	AuthorID   int64     `json:"author_id" dynamodbav:"author_id"`  // 帖子作者ID (发布者)
	AuthorName string    `json:"author_name" dynamodbav:"username"` // 作者用户名
	Content    string    `json:"content" dynamodbav:"content"`
	CreatedAt  time.Time `json:"created_at" dynamodbav:"created_at"`
}

type TimelineResponse struct {
	Timeline   []TimelinePost `json:"timeline"`
	TotalCount int            `json:"total_count"`
}

type FanoutRequest struct {
	PostID      string    `json:"post_id" binding:"required"`
	AuthorID    int64     `json:"author_id" binding:"required"`   // 帖子作者ID
	AuthorName  string    `json:"author_name" binding:"required"` // 作者用户名
	Content     string    `json:"content" binding:"required"`
	FollowerIDs []int64   `json:"follower_ids" binding:"required"`
	CreatedAt   time.Time `json:"created_at" binding:"required"`
}
