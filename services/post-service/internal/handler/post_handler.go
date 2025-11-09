package handler

import (
	"net/http"
	"os"
	"post-service/internal/model"
	"post-service/internal/service"
	"strings"

	pb "github.com/cs6650/proto/post"

	"github.com/gin-gonic/gin"
)

type PostHandler struct {
	postService *service.PostService
}

func NewPostHandler(postService *service.PostService) *PostHandler {
	return &PostHandler{
		postService: postService,
	}
}

// Execute different strategies based on the request
func (h *PostHandler) ExecuteStrategy(c *gin.Context) {
	var req model.CreatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get strategy from environment variable, default to "hybrid"
	strategy := strings.ToLower(os.Getenv("POST_STRATEGY"))
	if strategy == "" {
		strategy = "hybrid"
	}

	var post *pb.Post
	var err error
	var message string

	switch strategy {
	case "push":
		post, err = h.postService.PushStrategy(c.Request.Context(), &req)
		message = "Push to Followers' Feeds successfully"
	case "pull":
		post, err = h.postService.PullStrategy(c.Request.Context(), &req)
		message = "Save to Posts(Pull) successfully"
	case "hybrid":
		post, err = h.postService.HybridStrategy(c.Request.Context(), &req)
		message = "Run Hybrid Strategy successfully"
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid POST_STRATEGY. Must be 'push', 'pull', or 'hybrid'"})
		return
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"post": post, "message": message, "strategy": strategy})
}

// PushStategy handler
func (h *PostHandler)PushStrategy(c *gin.Context, req *model.CreatePostRequest){

	post, err := h.postService.PushStrategy(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	}

	c.JSON(http.StatusOK, gin.H{"post": post, "message": "Push to Followers' Feeds successfully"})
}

// PullStrategy Handler
func (h *PostHandler)PullStrategy(c *gin.Context, req *model.CreatePostRequest){
	post, err := h.postService.PullStrategy(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	}

	c.JSON(http.StatusOK, gin.H{"post": post, "message": "Save to Posts(Pull) successfully"})
}

// HybridStrategy Handler
func (h *PostHandler)HybridStrategy(c *gin.Context, req *model.CreatePostRequest){
	post, err := h.postService.HybridStrategy(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	}

	c.JSON(http.StatusOK, gin.H{"post": post, "message": "Run Hybrid Strategy successfully"})
}


// BatchGetPosts handler
func (h *PostHandler) BatchGetPosts(c *gin.Context) {
	var req pb.BatchGetPostsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := h.postService.BatchGetPosts(c.Request.Context(), &req) 
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	}

	c.JSON(http.StatusOK, gin.H{"result": result, "message": "Run Hybrid Strategy successfully"})
}

// Health check endpoint
func (h *PostHandler) Health(c *gin.Context) {
	strategy := strings.ToLower(os.Getenv("POST_STRATEGY"))
	if strategy == "" {
		strategy = "hybrid"
	}
	c.JSON(http.StatusOK, gin.H{
		"status":               "healthy",
		"service":              "post-service",
		"current_strategy":     strategy,
		"available_strategies": []string{"push", "pull", "hybrid"},
		"endpoints": gin.H{
			"posts": "GET /api/posts",
			"health":   "GET /api/health",
		},
	})
}