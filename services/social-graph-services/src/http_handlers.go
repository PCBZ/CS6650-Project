package main

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// HTTPHandler handles HTTP API requests
type HTTPHandler struct {
	db                *DynamoDBClient
	userServiceClient UserServiceClient
}

// NewHTTPHandler creates a new HTTP handler
func NewHTTPHandler(db *DynamoDBClient, userServiceClient UserServiceClient) *HTTPHandler {
	return &HTTPHandler{
		db:                db,
		userServiceClient: userServiceClient,
	}
}

// FollowRequest represents the request body for follow/unfollow actions
type FollowRequest struct {
	FollowerUserID string `json:"follower_user_id" binding:"required"`
	TargetUserID   string `json:"target_user_id" binding:"required"`
	Action         string `json:"action" binding:"required,oneof=follow unfollow"`
}

// Health returns service health status
func (h *HTTPHandler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "healthy",
		"service": "social-graph-service",
		"version": "1.0.0",
	})
}

// GetFollowerCount returns the follower count for a user
func (h *HTTPHandler) GetFollowerCount(c *gin.Context) {
	userID := c.Param("userId")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "userId is required",
		})
		return
	}

	count, err := h.db.GetFollowerCount(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get follower count",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"userId":         userID,
		"followerCount": count,
	})
}

// GetFollowingCount returns the following count for a user
func (h *HTTPHandler) GetFollowingCount(c *gin.Context) {
	userID := c.Param("userId")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "userId is required",
		})
		return
	}

	// Convert string ID to int64
	uid, err := strconv.ParseInt(userID, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid userId format",
		})
		return
	}

	count, err := h.db.GetFollowingCount(c.Request.Context(), uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get following count",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"userId":          userID,
		"followingCount": count,
	})
}

// CheckFollowRelationship checks if a follow relationship exists
func (h *HTTPHandler) CheckFollowRelationship(c *gin.Context) {
	followerID := c.Query("followerId")
	targetID := c.Query("targetId")

	if followerID == "" || targetID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "followerId and targetId are required",
		})
		return
	}

	// Convert string IDs to int64
	fid, err := strconv.ParseInt(followerID, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid followerId format",
		})
		return
	}

	tid, err := strconv.ParseInt(targetID, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid targetId format",
		})
		return
	}

	exists, err := h.db.CheckFollowRelationship(c.Request.Context(), fid, tid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to check follow relationship",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"followerId":  followerID,
		"targetId":    targetID,
		"isFollowing": exists,
	})
}

// FollowUser handles follow/unfollow actions
func (h *HTTPHandler) FollowUser(c *gin.Context) {
	var req FollowRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":      "Invalid request body",
			"error_code": "INVALID_REQUEST",
		})
		return
	}

	// Validate: cannot follow yourself
	if req.FollowerUserID == req.TargetUserID {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":      "Cannot follow yourself",
			"error_code": "SELF_FOLLOW_NOT_ALLOWED",
		})
		return
	}

	// Convert string IDs to int64
	followerID, err := strconv.ParseInt(req.FollowerUserID, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":      "Invalid follower_user_id",
			"error_code": "INVALID_REQUEST",
		})
		return
	}

	targetID, err := strconv.ParseInt(req.TargetUserID, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":      "Invalid target_user_id",
			"error_code": "INVALID_REQUEST",
		})
		return
	}

	if req.Action == "follow" {
		// Check if already following
		exists, err := h.db.CheckFollowRelationship(c.Request.Context(), followerID, targetID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":      "Failed to check follow relationship",
				"error_code": "INTERNAL_ERROR",
			})
			return
		}

		if exists {
			c.JSON(http.StatusConflict, gin.H{
				"error":      "Already following this user",
				"error_code": "ALREADY_FOLLOWING",
			})
			return
		}

		// Add follow relationship
		if err := h.db.InsertFollowRelationship(c.Request.Context(), followerID, targetID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":      "Failed to create follow relationship",
				"error_code": "INTERNAL_ERROR",
			})
			return
		}

		// Success response without 'success' field
		c.JSON(http.StatusCreated, gin.H{
			"follower_id":  followerID,
			"following_id": targetID,
			"created_at":   time.Now().UTC().Format(time.RFC3339),
		})
	} else if req.Action == "unfollow" {
		// Check if following exists
		exists, err := h.db.CheckFollowRelationship(c.Request.Context(), followerID, targetID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":      "Failed to check follow relationship",
				"error_code": "INTERNAL_ERROR",
			})
			return
		}

		if !exists {
			c.JSON(http.StatusNotFound, gin.H{
				"error":      "Not following this user",
				"error_code": "NOT_FOLLOWING",
			})
			return
		}

		// Remove follow relationship
		if err := h.db.DeleteFollowRelationship(c.Request.Context(), followerID, targetID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":      "Failed to remove follow relationship",
				"error_code": "INTERNAL_ERROR",
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message": "Successfully unfollowed user",
		})
	}
}

// GetFollowers returns the list of followers for a user
func (h *HTTPHandler) GetFollowers(c *gin.Context) {
	userID := c.Param("user_id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":      "user_id is required",
			"error_code": "INVALID_REQUEST",
		})
		return
	}

	// Get query parameters
	limitStr := c.DefaultQuery("limit", "50")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 || limit > 100 {
		limit = 50
	}

	cursor := c.Query("cursor")

	// Get followers list with pagination
	followers, nextCursor, hasMore, err := h.db.GetFollowersList(c.Request.Context(), userID, int32(limit), cursor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":      "Failed to get followers",
			"error_code": "INTERNAL_ERROR",
		})
		return
	}

	// Populate usernames from User Service
	userServiceAvailable := true
	if err := h.populateFollowerUsernames(c.Request.Context(), followers); err != nil {
		// Log error but don't fail the request
		// Usernames will be empty if User Service is unavailable
		userServiceAvailable = false
		// Note: We continue with empty usernames instead of failing
	}

	// Get total count
	totalCount, err := h.db.GetFollowerCount(c.Request.Context(), userID)
	if err != nil {
		totalCount = 0 // Fallback to 0 if count fails
	}

	response := gin.H{
		"user_id":     userID,
		"followers":   followers,
		"total_count": totalCount,
		"next_cursor": nextCursor,
		"has_more":    hasMore,
	}

	// Add warning if user service is unavailable
	if !userServiceAvailable {
		response["warning"] = "User information unavailable, usernames will be empty"
	}

	c.JSON(http.StatusOK, response)
}

// GetFollowing returns the list of users that a user follows
func (h *HTTPHandler) GetFollowing(c *gin.Context) {
	userID := c.Param("user_id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":      "user_id is required",
			"error_code": "INVALID_REQUEST",
		})
		return
	}

	// Get query parameters
	limitStr := c.DefaultQuery("limit", "50")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 || limit > 100 {
		limit = 50
	}

	cursor := c.Query("cursor")

	// Get following list with pagination
	following, nextCursor, hasMore, err := h.db.GetFollowingList(c.Request.Context(), userID, int32(limit), cursor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":      "Failed to get following",
			"error_code": "INTERNAL_ERROR",
		})
		return
	}

	// Convert string userID to int64 for count query
	uid, err := strconv.ParseInt(userID, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":      "Invalid userId format",
			"error_code": "INVALID_REQUEST",
		})
		return
	}

	// Get total count
	totalCount, err := h.db.GetFollowingCount(c.Request.Context(), uid)
	if err != nil {
		totalCount = 0 // Fallback to 0 if count fails
	}

	// Populate usernames from User Service
	userServiceAvailable := true
	if err := h.populateFollowingUsernames(c.Request.Context(), following); err != nil {
		// Log error but don't fail the request
		userServiceAvailable = false
		// Note: We continue with empty usernames instead of failing
	}

	response := gin.H{
		"user_id":     userID,
		"following":   following,
		"total_count": totalCount,
		"next_cursor": nextCursor,
		"has_more":    hasMore,
	}

	// Add warning if user service is unavailable
	if !userServiceAvailable {
		response["warning"] = "User information unavailable, usernames will be empty"
	}

	c.JSON(http.StatusOK, response)
}

// populateFollowerUsernames fetches usernames from User Service and populates the FollowerInfo slice
func (h *HTTPHandler) populateFollowerUsernames(ctx context.Context, followers []FollowerInfo) error {
	if len(followers) == 0 {
		return nil
	}

	// Extract user IDs
	userIDs := make([]int64, len(followers))
	for i, follower := range followers {
		userIDs[i] = follower.UserID
	}

	// Batch get user info from User Service
	users, _, err := h.userServiceClient.BatchGetUserInfo(ctx, userIDs)
	if err != nil {
		return err
	}

	// Populate usernames
	for i := range followers {
		if userInfo, ok := users[followers[i].UserID]; ok {
			followers[i].Username = userInfo.Username
		}
	}

	return nil
}

// populateFollowingUsernames fetches usernames from User Service and populates the FollowingInfo slice
func (h *HTTPHandler) populateFollowingUsernames(ctx context.Context, following []FollowingInfo) error {
	if len(following) == 0 {
		return nil
	}

	// Extract user IDs
	userIDs := make([]int64, len(following))
	for i, f := range following {
		userIDs[i] = f.UserID
	}

	// Batch get user info from User Service
	users, _, err := h.userServiceClient.BatchGetUserInfo(ctx, userIDs)
	if err != nil {
		return err
	}

	// Populate usernames
	for i := range following {
		if userInfo, ok := users[following[i].UserID]; ok {
			following[i].Username = userInfo.Username
		}
	}

	return nil
}

// LoadTestDataRequest represents the request body for loading test data
type LoadTestDataRequest struct {
	NumUsers int `json:"num_users" binding:"required,min=100"`
}

// LoadTestData triggers the Python script to generate and load test data into DynamoDB
// This is an admin endpoint for testing purposes
func (h *HTTPHandler) LoadTestData(c *gin.Context) {
	var req LoadTestDataRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request: " + err.Error(),
		})
		return
	}

	// TODO: Add authentication/authorization check here
	// This endpoint should only be accessible by admins

	c.JSON(http.StatusOK, gin.H{
		"message": "Test data loading initiated",
		"status":  "processing",
		"num_users": req.NumUsers,
		"note":    "Please use the Python script directly: python scripts/load_dynamodb.py --users " + strconv.Itoa(req.NumUsers),
	})
}
