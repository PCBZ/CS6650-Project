package handler

import (
	"context"
	"log"
	"post-service/internal/service"

	pb "github.com/cs6650/proto/post"
)

type GRPCHandler struct {
	pb.UnimplementedPostServiceServer
	postService *service.PostService
}

func NewGRPCHandler(postService *service.PostService) *GRPCHandler {
	return &GRPCHandler{
		postService: postService,
	}
}

// BatchGetPosts endpoint
func (h *GRPCHandler) BatchGetPosts(ctx context.Context, req *pb.BatchGetPostsRequest) (*pb.BatchGetPostsResponse, error) {
	log.Printf("BatchGetPosts called with %d user IDs", len(req.UserIds))
	userPosts, err := h.postService.BatchGetPosts(ctx, req)
	if err != nil {
		return &pb.BatchGetPostsResponse{
			ErrorMessage: err.Error(),
		}, nil
	}
	return &pb.BatchGetPostsResponse{
		UserPosts: userPosts,
	},nil
}
