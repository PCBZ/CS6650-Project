package service

import (
	"context"
	"fmt"
	"log"
	"post-service/internal/model"
	"post-service/internal/repository"
	"time"

	pb "github.com/cs6650/proto/post"
)

const (
	FanoutThreshold = 10000
	PostsLimit = 50
)

type PostService struct {
	repo *repository.PostRepository
	fanoutService *FanoutService
}

func NewPostService(repo *repository.PostRepository, fanoutService *FanoutService) *PostService {
	return &PostService{
		repo: repo,
		fanoutService: fanoutService,
	}
}

// createPost creates a new post object from the request
func (s *PostService) createPost(req *model.CreatePostRequest) *pb.Post {
	return &pb.Post{
		PostId:    time.Now().UnixNano(),
		UserId:    req.UserID,
		Content:   req.Content,
		Timestamp: time.Now().Unix(),
	}
}

func (s *PostService)PushStrategy(ctx context.Context, req *model.CreatePostRequest) (*pb.Post, error) {
	post := s.createPost(req)

	// Fanout
	go func() {
		if err := s.fanoutService.ExecutePushFanout(context.Background(), post); err!= nil {
			fmt.Printf("Fan-out error for post %d: %v\n", post.PostId, err)
		}
	}()
	return post, nil
}

func (s *PostService)PullStrategy(ctx context.Context, req *model.CreatePostRequest) (*pb.Post, error) {
	post := s.createPost(req)

	// Save to DynamoDB
	if err:= s.repo.CreatePost(ctx, post); err != nil {
		return nil, fmt.Errorf("failed to create post: %w", err)
	}
	return post, nil
}

func (s *PostService)HybridStrategy(ctx context.Context, req *model.CreatePostRequest) (*pb.Post, error) {
	post := s.createPost(req)

	// Get follower count
    followers, err := s.fanoutService.socialGraphClient.GetFollowers(ctx, post.UserId, 1, 0)
    if err != nil {
        return post, fmt.Errorf("failed to get followers: %w", err)
    }

    log.Printf("User %d has %d followers", post.UserId, followers.TotalCount)

    // Check threshold
    if followers.TotalCount >= FanoutThreshold {
        log.Printf("User %d has >= %d followers, skipping push fan-out", post.UserId, FanoutThreshold)
        return s.PullStrategy(ctx,req)
	}

	return s.PushStrategy(ctx, req)
}

// Get single post
func (s *PostService)GetPost(ctx context.Context, postID int64) (*pb.Post, error) {
	return s.repo.GetPost(ctx, postID)
}

// BatchGetPosts for Timeline Service
func (s *PostService) BatchGetPosts(ctx context.Context, req *pb.BatchGetPostsRequest)(map[int64]*pb.PostList, error) {
	if req.Limit == 0 {
		req.Limit = PostsLimit
	}

	posts, err := s.repo.GetPostByUserIDs(ctx, req.UserIds, req.Limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get posts: %w", err)
	}

	result := make(map[int64]*pb.PostList)
	for userID, posts := range posts {
		result[userID] = &pb.PostList{Posts: posts}
	}
	return result, nil
}
