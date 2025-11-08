package model

// A social media post
type Post struct {
	PostID  	int64 	`json:"post_id" dynamodbav:"post_id"`
	UserID		int64 	`json:"user_id" dynamodbav:"user_id"`
	Content 	string 	`json:"content" dynamodbav:"content"`
	Timestamp 	int64 	`json:"timestamp" dynamodbav:"timestamp"`
}

// Post Request/Response
type CreatePostRequest struct {
	UserID		int64 	`json:"user_id" binding:"required"`
	Content 	string 	`json:"content" binding:"required"`	
}

type BatchGetPostsRequest struct{
	UserIDs []int64 `json:"user_ids" binding:"required"`
    Limit   int32   `json:"limit"`
}

type BatchGetPostsResponse struct{
	UserPosts    map[int64][]Post `json:"user_posts"`
    ErrorMessage string           `json:"error_message,omitempty"`
}

// SNS message payload for fan-out
type FanoutMessage struct {
	EventType     string  `json:"event_type"`
    AuthorID      int64   `json:"author_id"`
    TargetUserIDs []int64 `json:"target_user_ids"`
    Content       string  `json:"content"`
    CreatedTime    string   `json:"created_time"`
}


