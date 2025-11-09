package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"

	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	pb "github.com/PCBZ/CS6650-Project/services/social-graph-services/socialgraph"
)

// SocialGraphServer implements the gRPC service
type SocialGraphServer struct {
	pb.UnimplementedSocialGraphServiceServer
	db *DynamoDBClient
}

// NewSocialGraphServer creates a new gRPC server
func NewSocialGraphServer(db *DynamoDBClient) *SocialGraphServer {
	return &SocialGraphServer{db: db}
}

// FollowUser creates a follow relationship
func (s *SocialGraphServer) FollowUser(ctx context.Context, req *pb.FollowUserRequest) (*pb.FollowUserResponse, error) {
	followerID := req.FollowerUserId
	targetID := req.TargetUserId

	// Validation
	if followerID == targetID {
		return &pb.FollowUserResponse{
			Success:      false,
			ErrorMessage: "Cannot follow yourself",
			ErrorCode:    "SELF_FOLLOW_NOT_ALLOWED",
		}, nil
	}

	// Check if already following
	exists, err := s.db.CheckFollowRelationship(ctx, followerID, targetID)
	if err != nil {
		log.Printf("Error checking follow relationship: %v", err)
		return &pb.FollowUserResponse{
			Success:      false,
			ErrorMessage: "Failed to check follow relationship",
			ErrorCode:    "INTERNAL_ERROR",
		}, nil
	}

	if exists {
		return &pb.FollowUserResponse{
			Success:      false,
			ErrorMessage: "Already following this user",
			ErrorCode:    "ALREADY_FOLLOWING",
		}, nil
	}

	// Insert relationship
	err = s.db.InsertFollowRelationship(ctx, followerID, targetID)
	if err != nil {
		log.Printf("Error inserting follow relationship: %v", err)
		return &pb.FollowUserResponse{
			Success:      false,
			ErrorMessage: "Failed to create follow relationship",
			ErrorCode:    "INTERNAL_ERROR",
		}, nil
	}

	return &pb.FollowUserResponse{
		Success: true,
	}, nil
}

// UnfollowUser removes a follow relationship
func (s *SocialGraphServer) UnfollowUser(ctx context.Context, req *pb.UnfollowUserRequest) (*pb.UnfollowUserResponse, error) {
	followerID := req.FollowerUserId
	targetID := req.TargetUserId

	// Check if relationship exists
	exists, err := s.db.CheckFollowRelationship(ctx, followerID, targetID)
	if err != nil {
		log.Printf("Error checking follow relationship: %v", err)
		return &pb.UnfollowUserResponse{
			Success:      false,
			ErrorMessage: "Failed to check follow relationship",
			ErrorCode:    "INTERNAL_ERROR",
		}, nil
	}

	if !exists {
		return &pb.UnfollowUserResponse{
			Success:      false,
			ErrorMessage: "Not following this user",
			ErrorCode:    "NOT_FOLLOWING",
		}, nil
	}

	// Delete relationship
	err = s.db.DeleteFollowRelationship(ctx, followerID, targetID)
	if err != nil {
		log.Printf("Error deleting follow relationship: %v", err)
		return &pb.UnfollowUserResponse{
			Success:      false,
			ErrorMessage: "Failed to remove follow relationship",
			ErrorCode:    "INTERNAL_ERROR",
		}, nil
	}

	return &pb.UnfollowUserResponse{
		Success: true,
	}, nil
}

// GetFollowers retrieves followers of a user
func (s *SocialGraphServer) GetFollowers(ctx context.Context, req *pb.GetFollowersRequest) (*pb.GetFollowersResponse, error) {
	userID := req.UserId
	limit := req.Limit
	if limit == 0 {
		limit = 50 // Default limit
	}

	// Decode pagination cursor
	var lastEvaluatedKey map[string]types.AttributeValue
	if req.NextCursor != "" {
		decoded, err := base64.StdEncoding.DecodeString(req.NextCursor)
		if err != nil {
			log.Printf("Error decoding cursor: %v", err)
		} else {
			json.Unmarshal(decoded, &lastEvaluatedKey)
		}
	}

	// Get followers
	followers, nextKey, err := s.db.GetFollowers(ctx, userID, limit, lastEvaluatedKey)
	if err != nil {
		log.Printf("Error getting followers: %v", err)
		return &pb.GetFollowersResponse{
			ErrorMessage: "Failed to get followers",
		}, nil
	}

	// Get total count
	totalCount, err := s.db.GetFollowersCount(ctx, userID)
	if err != nil {
		log.Printf("Error getting followers count: %v", err)
		totalCount = int32(len(followers))
	}

	// Encode next cursor
	var nextCursor string
	hasMore := false
	if nextKey != nil {
		encoded, _ := json.Marshal(nextKey)
		nextCursor = base64.StdEncoding.EncodeToString(encoded)
		hasMore = true
	}

	return &pb.GetFollowersResponse{
		FollowerIds: followers,
		TotalCount:  totalCount,
		NextCursor:  nextCursor,
		HasMore:     hasMore,
	}, nil
}

// GetFollowing retrieves users that a user follows
func (s *SocialGraphServer) GetFollowing(ctx context.Context, req *pb.GetFollowingRequest) (*pb.GetFollowingResponse, error) {
	userID := req.UserId
	limit := req.Limit
	if limit == 0 {
		limit = 50
	}

	// Decode pagination cursor
	var lastEvaluatedKey map[string]types.AttributeValue
	if req.NextCursor != "" {
		decoded, err := base64.StdEncoding.DecodeString(req.NextCursor)
		if err != nil {
			log.Printf("Error decoding cursor: %v", err)
		} else {
			json.Unmarshal(decoded, &lastEvaluatedKey)
		}
	}

	// Get following
	following, nextKey, err := s.db.GetFollowing(ctx, userID, limit, lastEvaluatedKey)
	if err != nil {
		log.Printf("Error getting following: %v", err)
		return &pb.GetFollowingResponse{
			ErrorMessage: "Failed to get following",
		}, nil
	}

	// Get total count
	totalCount, err := s.db.GetFollowingCount(ctx, userID)
	if err != nil {
		log.Printf("Error getting following count: %v", err)
		totalCount = int32(len(following))
	}

	// Encode next cursor
	var nextCursor string
	hasMore := false
	if nextKey != nil {
		encoded, _ := json.Marshal(nextKey)
		nextCursor = base64.StdEncoding.EncodeToString(encoded)
		hasMore = true
	}

	return &pb.GetFollowingResponse{
		FollowingIds: following,
		TotalCount:   totalCount,
		NextCursor:   nextCursor,
		HasMore:      hasMore,
	}, nil
}

// GetFollowersCount returns follower count
func (s *SocialGraphServer) GetFollowersCount(ctx context.Context, req *pb.GetFollowersCountRequest) (*pb.GetFollowersCountResponse, error) {
	userID := req.UserId

	count, err := s.db.GetFollowersCount(ctx, userID)
	if err != nil {
		log.Printf("Error getting followers count: %v", err)
		return &pb.GetFollowersCountResponse{
			UserId:       userID,
			ErrorMessage: "Failed to get followers count",
		}, nil
	}

	return &pb.GetFollowersCountResponse{
		UserId:         userID,
		FollowersCount: count,
	}, nil
}

// GetFollowingCount returns following count
func (s *SocialGraphServer) GetFollowingCount(ctx context.Context, req *pb.GetFollowingCountRequest) (*pb.GetFollowingCountResponse, error) {
	userID := req.UserId

	count, err := s.db.GetFollowingCount(ctx, userID)
	if err != nil {
		log.Printf("Error getting following count: %v", err)
		return &pb.GetFollowingCountResponse{
			UserId:       userID,
			ErrorMessage: "Failed to get following count",
		}, nil
	}

	return &pb.GetFollowingCountResponse{
		UserId:         userID,
		FollowingCount: count,
	}, nil
}

// CheckFollowRelationship checks if a follow relationship exists
func (s *SocialGraphServer) CheckFollowRelationship(ctx context.Context, req *pb.CheckFollowRelationshipRequest) (*pb.CheckFollowRelationshipResponse, error) {
	followerID := req.FollowerUserId
	targetID := req.TargetUserId

	exists, err := s.db.CheckFollowRelationship(ctx, followerID, targetID)
	if err != nil {
		log.Printf("Error checking follow relationship: %v", err)
		return &pb.CheckFollowRelationshipResponse{
			ErrorMessage: "Failed to check follow relationship",
		}, nil
	}

	return &pb.CheckFollowRelationshipResponse{
		IsFollowing: exists,
	}, nil
}

// BatchCreateFollowRelationships creates multiple relationships (for data generation)
func (s *SocialGraphServer) BatchCreateFollowRelationships(ctx context.Context, req *pb.BatchCreateFollowRelationshipsRequest) (*pb.BatchCreateFollowRelationshipsResponse, error) {
	relationships := req.Relationships

	if len(relationships) == 0 {
		return &pb.BatchCreateFollowRelationshipsResponse{
			Success:      false,
			ErrorMessage: "No relationships provided",
		}, nil
	}

	// Convert to format expected by DB
	dbRelationships := make([][2]int64, 0, len(relationships))
	for _, rel := range relationships {
		// Validate
		if rel.FollowerUserId == rel.TargetUserId {
			continue // Skip self-follows
		}
		dbRelationships = append(dbRelationships, [2]int64{rel.FollowerUserId, rel.TargetUserId})
	}

	// Batch insert
	err := s.db.BatchInsertFollowRelationships(ctx, dbRelationships)
	if err != nil {
		log.Printf("Error batch inserting relationships: %v", err)
		return &pb.BatchCreateFollowRelationshipsResponse{
			Success:      false,
			FailedCount:  int32(len(dbRelationships)),
			ErrorMessage: fmt.Sprintf("Failed to batch insert: %v", err),
		}, nil
	}

	return &pb.BatchCreateFollowRelationshipsResponse{
		Success:      true,
		CreatedCount: int32(len(dbRelationships)),
	}, nil
}
