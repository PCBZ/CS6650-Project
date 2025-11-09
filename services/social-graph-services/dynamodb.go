package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// FollowerRecord represents a follower relationship in DynamoDB
type FollowerRecord struct {
	UserID     int64  `dynamodbav:"user_id"`
	FollowerID int64  `dynamodbav:"follower_id"`
	CreatedAt  int64  `dynamodbav:"created_at"`
	Username   string `dynamodbav:"follower_username,omitempty"`
}

// FollowingRecord represents a following relationship in DynamoDB
type FollowingRecord struct {
	UserID     int64  `dynamodbav:"user_id"`
	FolloweeID int64  `dynamodbav:"followee_id"`
	CreatedAt  int64  `dynamodbav:"created_at"`
	Username   string `dynamodbav:"followee_username,omitempty"`
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

// InsertFollowRelationship inserts a follow relationship into both tables
func (db *DynamoDBClient) InsertFollowRelationship(ctx context.Context, followerID, followeeID int64) error {
	now := time.Now().Unix()

	// Insert into FollowersTable (user_id = followee, follower_id = follower)
	followerRecord := FollowerRecord{
		UserID:     followeeID,
		FollowerID: followerID,
		CreatedAt:  now,
	}

	followerItem, err := attributevalue.MarshalMap(followerRecord)
	if err != nil {
		return fmt.Errorf("failed to marshal follower record: %w", err)
	}

	_, err = db.client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(db.followersTableName),
		Item:      followerItem,
	})
	if err != nil {
		return fmt.Errorf("failed to insert into FollowersTable: %w", err)
	}

	// Insert into FollowingTable (user_id = follower, followee_id = followee)
	followingRecord := FollowingRecord{
		UserID:     followerID,
		FolloweeID: followeeID,
		CreatedAt:  now,
	}

	followingItem, err := attributevalue.MarshalMap(followingRecord)
	if err != nil {
		return fmt.Errorf("failed to marshal following record: %w", err)
	}

	_, err = db.client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(db.followingTableName),
		Item:      followingItem,
	})
	if err != nil {
		return fmt.Errorf("failed to insert into FollowingTable: %w", err)
	}

	return nil
}

// DeleteFollowRelationship removes a follow relationship from both tables
func (db *DynamoDBClient) DeleteFollowRelationship(ctx context.Context, followerID, followeeID int64) error {
	// Delete from FollowersTable
	_, err := db.client.DeleteItem(ctx, &dynamodb.DeleteItemInput{
		TableName: aws.String(db.followersTableName),
		Key: map[string]types.AttributeValue{
			"user_id":     &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", followeeID)},
			"follower_id": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", followerID)},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to delete from FollowersTable: %w", err)
	}

	// Delete from FollowingTable
	_, err = db.client.DeleteItem(ctx, &dynamodb.DeleteItemInput{
		TableName: aws.String(db.followingTableName),
		Key: map[string]types.AttributeValue{
			"user_id":     &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", followerID)},
			"followee_id": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", followeeID)},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to delete from FollowingTable: %w", err)
	}

	return nil
}

// GetFollowers retrieves all followers of a user
func (db *DynamoDBClient) GetFollowers(ctx context.Context, userID int64, limit int32, lastEvaluatedKey map[string]types.AttributeValue) ([]int64, map[string]types.AttributeValue, error) {
	input := &dynamodb.QueryInput{
		TableName:              aws.String(db.followersTableName),
		KeyConditionExpression: aws.String("user_id = :uid"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":uid": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", userID)},
		},
		Limit: aws.Int32(limit),
	}

	if lastEvaluatedKey != nil {
		input.ExclusiveStartKey = lastEvaluatedKey
	}

	result, err := db.client.Query(ctx, input)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to query followers: %w", err)
	}

	followers := make([]int64, 0, len(result.Items))
	for _, item := range result.Items {
		var record FollowerRecord
		err := attributevalue.UnmarshalMap(item, &record)
		if err != nil {
			log.Printf("failed to unmarshal follower record: %v", err)
			continue
		}
		followers = append(followers, record.FollowerID)
	}

	return followers, result.LastEvaluatedKey, nil
}

// GetFollowing retrieves all users that a user follows
func (db *DynamoDBClient) GetFollowing(ctx context.Context, userID int64, limit int32, lastEvaluatedKey map[string]types.AttributeValue) ([]int64, map[string]types.AttributeValue, error) {
	input := &dynamodb.QueryInput{
		TableName:              aws.String(db.followingTableName),
		KeyConditionExpression: aws.String("user_id = :uid"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":uid": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", userID)},
		},
		Limit: aws.Int32(limit),
	}

	if lastEvaluatedKey != nil {
		input.ExclusiveStartKey = lastEvaluatedKey
	}

	result, err := db.client.Query(ctx, input)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to query following: %w", err)
	}

	following := make([]int64, 0, len(result.Items))
	for _, item := range result.Items {
		var record FollowingRecord
		err := attributevalue.UnmarshalMap(item, &record)
		if err != nil {
			log.Printf("failed to unmarshal following record: %v", err)
			continue
		}
		following = append(following, record.FolloweeID)
	}

	return following, result.LastEvaluatedKey, nil
}

// GetFollowersCount returns the count of followers for a user
func (db *DynamoDBClient) GetFollowersCount(ctx context.Context, userID int64) (int32, error) {
	input := &dynamodb.QueryInput{
		TableName:              aws.String(db.followersTableName),
		KeyConditionExpression: aws.String("user_id = :uid"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":uid": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", userID)},
		},
		Select: types.SelectCount,
	}

	result, err := db.client.Query(ctx, input)
	if err != nil {
		return 0, fmt.Errorf("failed to count followers: %w", err)
	}

	return result.Count, nil
}

// GetFollowingCount returns the count of users that a user follows
func (db *DynamoDBClient) GetFollowingCount(ctx context.Context, userID int64) (int32, error) {
	input := &dynamodb.QueryInput{
		TableName:              aws.String(db.followingTableName),
		KeyConditionExpression: aws.String("user_id = :uid"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":uid": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", userID)},
		},
		Select: types.SelectCount,
	}

	result, err := db.client.Query(ctx, input)
	if err != nil {
		return 0, fmt.Errorf("failed to count following: %w", err)
	}

	return result.Count, nil
}

// CheckFollowRelationship checks if follower follows followee
func (db *DynamoDBClient) CheckFollowRelationship(ctx context.Context, followerID, followeeID int64) (bool, error) {
	result, err := db.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(db.followingTableName),
		Key: map[string]types.AttributeValue{
			"user_id":     &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", followerID)},
			"followee_id": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", followeeID)},
		},
	})
	if err != nil {
		return false, fmt.Errorf("failed to check follow relationship: %w", err)
	}

	return result.Item != nil, nil
}

// BatchInsertFollowRelationships inserts multiple follow relationships
func (db *DynamoDBClient) BatchInsertFollowRelationships(ctx context.Context, relationships [][2]int64) error {
	const batchSize = 25 // DynamoDB BatchWriteItem limit

	for i := 0; i < len(relationships); i += batchSize {
		end := i + batchSize
		if end > len(relationships) {
			end = len(relationships)
		}

		batch := relationships[i:end]
		if err := db.batchWriteFollowRelationships(ctx, batch); err != nil {
			return fmt.Errorf("failed to batch write relationships: %w", err)
		}
	}

	return nil
}

func (db *DynamoDBClient) batchWriteFollowRelationships(ctx context.Context, relationships [][2]int64) error {
	now := time.Now().Unix()

	followerRequests := make([]types.WriteRequest, 0, len(relationships))
	followingRequests := make([]types.WriteRequest, 0, len(relationships))

	for _, rel := range relationships {
		followerID, followeeID := rel[0], rel[1]

		// FollowersTable request
		followerRecord := FollowerRecord{
			UserID:     followeeID,
			FollowerID: followerID,
			CreatedAt:  now,
		}
		followerItem, err := attributevalue.MarshalMap(followerRecord)
		if err != nil {
			return err
		}
		followerRequests = append(followerRequests, types.WriteRequest{
			PutRequest: &types.PutRequest{Item: followerItem},
		})

		// FollowingTable request
		followingRecord := FollowingRecord{
			UserID:     followerID,
			FolloweeID: followeeID,
			CreatedAt:  now,
		}
		followingItem, err := attributevalue.MarshalMap(followingRecord)
		if err != nil {
			return err
		}
		followingRequests = append(followingRequests, types.WriteRequest{
			PutRequest: &types.PutRequest{Item: followingItem},
		})
	}

	// Write to FollowersTable
	_, err := db.client.BatchWriteItem(ctx, &dynamodb.BatchWriteItemInput{
		RequestItems: map[string][]types.WriteRequest{
			db.followersTableName: followerRequests,
		},
	})
	if err != nil {
		return fmt.Errorf("failed to batch write to FollowersTable: %w", err)
	}

	// Write to FollowingTable
	_, err = db.client.BatchWriteItem(ctx, &dynamodb.BatchWriteItemInput{
		RequestItems: map[string][]types.WriteRequest{
			db.followingTableName: followingRequests,
		},
	})
	if err != nil {
		return fmt.Errorf("failed to batch write to FollowingTable: %w", err)
	}

	return nil
}
