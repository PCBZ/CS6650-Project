package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"strconv"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// FollowerRecord represents a user's follower list in DynamoDB
type FollowerRecord struct {
	UserID      string   `dynamodbav:"user_id"`
	FollowerIDs []string `dynamodbav:"follower_ids"`
}

// FollowingRecord represents a user's following list in DynamoDB
type FollowingRecord struct {
	UserID       string   `dynamodbav:"user_id"`
	FollowingIDs []string `dynamodbav:"following_ids"`
}

// DynamoDBClient wraps the AWS DynamoDB client
type DynamoDBClient struct {
	client             *dynamodb.Client
	followersTableName string
	followingTableName string
}

// NewDynamoDBClient creates a new DynamoDB client
func NewDynamoDBClient(client *dynamodb.Client, followersTable, followingTable string) *DynamoDBClient {
	return &DynamoDBClient{
		client:             client,
		followersTableName: followersTable,
		followingTableName: followingTable,
	}
}

// InsertFollowRelationship inserts a follow relationship into both tables using list format
// Uses DynamoDB's list append operation (if not exists, creates new list)
func (db *DynamoDBClient) InsertFollowRelationship(ctx context.Context, followerID, followeeID int64) error {
	followerIDStr := fmt.Sprintf("%d", followerID)
	followeeIDStr := fmt.Sprintf("%d", followeeID)

	// Add to FollowersTable (user_id = followee, add follower to follower_ids list)
	_, err := db.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: aws.String(db.followersTableName),
		Key: map[string]types.AttributeValue{
			"user_id": &types.AttributeValueMemberS{Value: followeeIDStr},
		},
		UpdateExpression: aws.String("SET follower_ids = list_append(if_not_exists(follower_ids, :empty_list), :new_follower)"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":new_follower": &types.AttributeValueMemberL{
				Value: []types.AttributeValue{
					&types.AttributeValueMemberS{Value: followerIDStr},
				},
			},
			":empty_list": &types.AttributeValueMemberL{Value: []types.AttributeValue{}},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to update FollowersTable: %w", err)
	}

	// Add to FollowingTable (user_id = follower, add followee to following_ids list)
	_, err = db.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: aws.String(db.followingTableName),
		Key: map[string]types.AttributeValue{
			"user_id": &types.AttributeValueMemberS{Value: followerIDStr},
		},
		UpdateExpression: aws.String("SET following_ids = list_append(if_not_exists(following_ids, :empty_list), :new_following)"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":new_following": &types.AttributeValueMemberL{
				Value: []types.AttributeValue{
					&types.AttributeValueMemberS{Value: followeeIDStr},
				},
			},
			":empty_list": &types.AttributeValueMemberL{Value: []types.AttributeValue{}},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to update FollowingTable: %w", err)
	}

	return nil
}

// DeleteFollowRelationship removes a follow relationship from both tables using list format
// Note: This is O(n) operation - finds and removes the ID from the list
func (db *DynamoDBClient) DeleteFollowRelationship(ctx context.Context, followerID, followeeID int64) error {
	followerIDStr := fmt.Sprintf("%d", followerID)
	followeeIDStr := fmt.Sprintf("%d", followeeID)

	// First, get the current follower list to find the index
	getFollowersResult, err := db.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(db.followersTableName),
		Key: map[string]types.AttributeValue{
			"user_id": &types.AttributeValueMemberS{Value: followeeIDStr},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to get followers list: %w", err)
	}

	// Find index of follower to remove
	if getFollowersResult.Item != nil {
		var record FollowerRecord
		if err := attributevalue.UnmarshalMap(getFollowersResult.Item, &record); err == nil {
			for idx, fid := range record.FollowerIDs {
				if fid == followerIDStr {
					// Remove from FollowersTable using index
					_, err = db.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
						TableName: aws.String(db.followersTableName),
						Key: map[string]types.AttributeValue{
							"user_id": &types.AttributeValueMemberS{Value: followeeIDStr},
						},
						UpdateExpression: aws.String(fmt.Sprintf("REMOVE follower_ids[%d]", idx)),
					})
					if err != nil {
						return fmt.Errorf("failed to remove from FollowersTable: %w", err)
					}
					break
				}
			}
		}
	}

	// Get the current following list to find the index
	getFollowingResult, err := db.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(db.followingTableName),
		Key: map[string]types.AttributeValue{
			"user_id": &types.AttributeValueMemberS{Value: followerIDStr},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to get following list: %w", err)
	}

	// Find index of followee to remove
	if getFollowingResult.Item != nil {
		var record FollowingRecord
		if err := attributevalue.UnmarshalMap(getFollowingResult.Item, &record); err == nil {
			for idx, fid := range record.FollowingIDs {
				if fid == followeeIDStr {
					// Remove from FollowingTable using index
					_, err = db.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
						TableName: aws.String(db.followingTableName),
						Key: map[string]types.AttributeValue{
							"user_id": &types.AttributeValueMemberS{Value: followerIDStr},
						},
						UpdateExpression: aws.String(fmt.Sprintf("REMOVE following_ids[%d]", idx)),
					})
					if err != nil {
						return fmt.Errorf("failed to remove from FollowingTable: %w", err)
					}
					break
				}
			}
		}
	}

	return nil
}

// GetFollowers retrieves all followers of a user (from list format)
// Note: With list format, this is now O(1) instead of O(n) query
func (db *DynamoDBClient) GetFollowers(ctx context.Context, userID int64, limit int32, lastEvaluatedKey map[string]types.AttributeValue) ([]int64, map[string]types.AttributeValue, error) {
	userIDStr := fmt.Sprintf("%d", userID)

	result, err := db.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(db.followersTableName),
		Key: map[string]types.AttributeValue{
			"user_id": &types.AttributeValueMemberS{Value: userIDStr},
		},
	})
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get followers: %w", err)
	}

	if result.Item == nil {
		return []int64{}, nil, nil
	}

	var record FollowerRecord
	err = attributevalue.UnmarshalMap(result.Item, &record)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to unmarshal follower record: %w", err)
	}

	// Convert string IDs to int64
	followers := make([]int64, 0, len(record.FollowerIDs))
	for _, fidStr := range record.FollowerIDs {
		fid, err := strconv.ParseInt(fidStr, 10, 64)
		if err != nil {
			log.Printf("failed to parse follower ID %s: %v", fidStr, err)
			continue
		}
		followers = append(followers, fid)
	}

	// Simple pagination: slice the result
	// Note: This is in-memory pagination. For better efficiency, consider storing offset in cursor
	startIdx := 0
	if lastEvaluatedKey != nil {
		if offsetVal, ok := lastEvaluatedKey["offset"]; ok {
			if offsetN, ok := offsetVal.(*types.AttributeValueMemberN); ok {
				offset, _ := strconv.Atoi(offsetN.Value)
				startIdx = offset
			}
		}
	}

	endIdx := startIdx + int(limit)
	if endIdx > len(followers) {
		endIdx = len(followers)
	}

	paginatedFollowers := followers[startIdx:endIdx]

	// Create next cursor if there are more results
	var nextKey map[string]types.AttributeValue
	if endIdx < len(followers) {
		nextKey = map[string]types.AttributeValue{
			"offset": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", endIdx)},
		}
	}

	return paginatedFollowers, nextKey, nil
}

// GetFollowing retrieves all users that a user follows (from list format)
// Note: With list format, this is now O(1) instead of O(n) query
func (db *DynamoDBClient) GetFollowing(ctx context.Context, userID int64, limit int32, lastEvaluatedKey map[string]types.AttributeValue) ([]int64, map[string]types.AttributeValue, error) {
	userIDStr := fmt.Sprintf("%d", userID)

	result, err := db.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(db.followingTableName),
		Key: map[string]types.AttributeValue{
			"user_id": &types.AttributeValueMemberS{Value: userIDStr},
		},
	})
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get following: %w", err)
	}

	if result.Item == nil {
		return []int64{}, nil, nil
	}

	var record FollowingRecord
	err = attributevalue.UnmarshalMap(result.Item, &record)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to unmarshal following record: %w", err)
	}

	// Convert string IDs to int64
	following := make([]int64, 0, len(record.FollowingIDs))
	for _, fidStr := range record.FollowingIDs {
		fid, err := strconv.ParseInt(fidStr, 10, 64)
		if err != nil {
			log.Printf("failed to parse following ID %s: %v", fidStr, err)
			continue
		}
		following = append(following, fid)
	}

	// Simple pagination: slice the result
	startIdx := 0
	if lastEvaluatedKey != nil {
		if offsetVal, ok := lastEvaluatedKey["offset"]; ok {
			if offsetN, ok := offsetVal.(*types.AttributeValueMemberN); ok {
				offset, _ := strconv.Atoi(offsetN.Value)
				startIdx = offset
			}
		}
	}

	endIdx := startIdx + int(limit)
	if endIdx > len(following) {
		endIdx = len(following)
	}

	paginatedFollowing := following[startIdx:endIdx]

	// Create next cursor if there are more results
	var nextKey map[string]types.AttributeValue
	if endIdx < len(following) {
		nextKey = map[string]types.AttributeValue{
			"offset": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", endIdx)},
		}
	}

	return paginatedFollowing, nextKey, nil
}

// GetFollowersCount returns the count of followers for a user (from list format)
func (db *DynamoDBClient) GetFollowersCount(ctx context.Context, userID int64) (int32, error) {
	userIDStr := fmt.Sprintf("%d", userID)

	result, err := db.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(db.followersTableName),
		Key: map[string]types.AttributeValue{
			"user_id": &types.AttributeValueMemberS{Value: userIDStr},
		},
		ProjectionExpression: aws.String("follower_ids"),
	})
	if err != nil {
		return 0, fmt.Errorf("failed to get followers count: %w", err)
	}

	if result.Item == nil {
		return 0, nil
	}

	var record FollowerRecord
	err = attributevalue.UnmarshalMap(result.Item, &record)
	if err != nil {
		return 0, fmt.Errorf("failed to unmarshal follower record: %w", err)
	}

	count := int32(len(record.FollowerIDs))
	// Debug logging for verification
	sampleSize := 5
	if len(record.FollowerIDs) < sampleSize {
		sampleSize = len(record.FollowerIDs)
	}
	log.Printf("GetFollowersCount: user=%d, count=%d, sample_ids=%v", userID, count, record.FollowerIDs[:sampleSize])
	
	return count, nil
}

// GetFollowingCount returns the count of users that a user follows (from list format)
func (db *DynamoDBClient) GetFollowingCount(ctx context.Context, userID int64) (int32, error) {
	userIDStr := fmt.Sprintf("%d", userID)

	result, err := db.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(db.followingTableName),
		Key: map[string]types.AttributeValue{
			"user_id": &types.AttributeValueMemberS{Value: userIDStr},
		},
		ProjectionExpression: aws.String("following_ids"),
	})
	if err != nil {
		return 0, fmt.Errorf("failed to get following count: %w", err)
	}

	if result.Item == nil {
		return 0, nil
	}

	var record FollowingRecord
	err = attributevalue.UnmarshalMap(result.Item, &record)
	if err != nil {
		return 0, fmt.Errorf("failed to unmarshal following record: %w", err)
	}

	return int32(len(record.FollowingIDs)), nil
}

// CheckFollowRelationship checks if follower follows followee (from list format)
func (db *DynamoDBClient) CheckFollowRelationship(ctx context.Context, followerID, followeeID int64) (bool, error) {
	followerIDStr := fmt.Sprintf("%d", followerID)
	followeeIDStr := fmt.Sprintf("%d", followeeID)

	result, err := db.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(db.followingTableName),
		Key: map[string]types.AttributeValue{
			"user_id": &types.AttributeValueMemberS{Value: followerIDStr},
		},
		ProjectionExpression: aws.String("following_ids"),
	})
	if err != nil {
		return false, fmt.Errorf("failed to check follow relationship: %w", err)
	}

	if result.Item == nil {
		return false, nil
	}

	var record FollowingRecord
	err = attributevalue.UnmarshalMap(result.Item, &record)
	if err != nil {
		return false, fmt.Errorf("failed to unmarshal following record: %w", err)
	}

	// Check if followee is in the list
	for _, fid := range record.FollowingIDs {
		if fid == followeeIDStr {
			return true, nil
		}
	}

	return false, nil
}

// BatchInsertFollowRelationships inserts multiple follow relationships
// Note: For list format, this uses individual UpdateItem calls (not optimal for bulk loading)
// For initial data loading, use the Python script which writes directly in list format
func (db *DynamoDBClient) BatchInsertFollowRelationships(ctx context.Context, relationships [][2]int64) error {
	// Process each relationship individually
	for _, rel := range relationships {
		followerID, followeeID := rel[0], rel[1]
		if err := db.InsertFollowRelationship(ctx, followerID, followeeID); err != nil {
			log.Printf("Failed to insert relationship %d -> %d: %v", followerID, followeeID, err)
			// Continue with other relationships instead of failing completely
		}
	}

	return nil
}

// FollowerInfo represents a follower with user information
type FollowerInfo struct {
	UserID   int64  `json:"user_id"`
	Username string `json:"username,omitempty"`
}

// FollowingInfo represents a following user with user information
type FollowingInfo struct {
	UserID   int64  `json:"user_id"`
	Username string `json:"username,omitempty"`
}

// GetFollowersList retrieves followers with cursor-based pagination
// Returns list of followers, next cursor (base64 encoded), and hasMore flag
func (db *DynamoDBClient) GetFollowersList(ctx context.Context, userID string, limit int32, cursor string) ([]FollowerInfo, string, bool, error) {
	// Convert string userID to int64
	uid, err := strconv.ParseInt(userID, 10, 64)
	if err != nil {
		return nil, "", false, fmt.Errorf("invalid user ID: %w", err)
	}

	// Decode cursor if provided
	var lastEvaluatedKey map[string]types.AttributeValue
	if cursor != "" {
		cursorBytes, err := base64.StdEncoding.DecodeString(cursor)
		if err != nil {
			return nil, "", false, fmt.Errorf("invalid cursor: %w", err)
		}
		if err := json.Unmarshal(cursorBytes, &lastEvaluatedKey); err != nil {
			return nil, "", false, fmt.Errorf("invalid cursor format: %w", err)
		}
	}

	// Get followers from DynamoDB
	followerIDs, newLastEvaluatedKey, err := db.GetFollowers(ctx, uid, limit, lastEvaluatedKey)
	if err != nil {
		return nil, "", false, err
	}

	// Convert to FollowerInfo list
	followers := make([]FollowerInfo, len(followerIDs))
	for i, fid := range followerIDs {
		followers[i] = FollowerInfo{
			UserID: fid,
			// Username can be populated later if needed (requires user service call)
		}
	}

	// Encode next cursor
	var nextCursor string
	hasMore := newLastEvaluatedKey != nil
	if hasMore {
		cursorBytes, err := json.Marshal(newLastEvaluatedKey)
		if err != nil {
			return nil, "", false, fmt.Errorf("failed to encode cursor: %w", err)
		}
		nextCursor = base64.StdEncoding.EncodeToString(cursorBytes)
	}

	return followers, nextCursor, hasMore, nil
}

// GetFollowingList retrieves following users with cursor-based pagination
// Returns list of following users, next cursor (base64 encoded), and hasMore flag
func (db *DynamoDBClient) GetFollowingList(ctx context.Context, userID string, limit int32, cursor string) ([]FollowingInfo, string, bool, error) {
	// Convert string userID to int64
	uid, err := strconv.ParseInt(userID, 10, 64)
	if err != nil {
		return nil, "", false, fmt.Errorf("invalid user ID: %w", err)
	}

	// Decode cursor if provided
	var lastEvaluatedKey map[string]types.AttributeValue
	if cursor != "" {
		cursorBytes, err := base64.StdEncoding.DecodeString(cursor)
		if err != nil {
			return nil, "", false, fmt.Errorf("invalid cursor: %w", err)
		}
		if err := json.Unmarshal(cursorBytes, &lastEvaluatedKey); err != nil {
			return nil, "", false, fmt.Errorf("invalid cursor format: %w", err)
		}
	}

	// Get following from DynamoDB
	followingIDs, newLastEvaluatedKey, err := db.GetFollowing(ctx, uid, limit, lastEvaluatedKey)
	if err != nil {
		return nil, "", false, err
	}

	// Convert to FollowingInfo list
	following := make([]FollowingInfo, len(followingIDs))
	for i, fid := range followingIDs {
		following[i] = FollowingInfo{
			UserID: fid,
			// Username can be populated later if needed (requires user service call)
		}
	}

	// Encode next cursor
	var nextCursor string
	hasMore := newLastEvaluatedKey != nil
	if hasMore {
		cursorBytes, err := json.Marshal(newLastEvaluatedKey)
		if err != nil {
			return nil, "", false, fmt.Errorf("failed to encode cursor: %w", err)
		}
		nextCursor = base64.StdEncoding.EncodeToString(cursorBytes)
	}

	return following, nextCursor, hasMore, nil
}

// GetFollowerCount is an alias for GetFollowersCount for HTTP API consistency
func (db *DynamoDBClient) GetFollowerCount(ctx context.Context, userID string) (int32, error) {
	uid, err := strconv.ParseInt(userID, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid user ID: %w", err)
	}
	return db.GetFollowersCount(ctx, uid)
}