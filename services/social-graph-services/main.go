package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	pb "github.com/PCBZ/CS6650-Project/services/social-graph-services/socialgraph"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

func main() {
	// Load AWS configuration
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(getEnv("AWS_REGION", "us-east-1")),
	)
	if err != nil {
		log.Fatalf("Unable to load SDK config: %v", err)
	}

	// Create DynamoDB client
	dynamoClient := dynamodb.NewFromConfig(cfg)
	
	// Get table names from environment or use defaults
	followersTableName := getEnv("FOLLOWERS_TABLE", "FollowersTable")
	followingTableName := getEnv("FOLLOWING_TABLE", "FollowingTable")
	
	// Initialize DynamoDB client wrapper
	dbClient := NewDynamoDBClient(dynamoClient, followersTableName, followingTableName)

	// Create gRPC server
	grpcPort := getEnv("GRPC_PORT", "50051")
	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", grpcPort))
	if err != nil {
		log.Fatalf("Failed to listen on port %s: %v", grpcPort, err)
	}

	grpcServer := grpc.NewServer()
	
	// Register service
	socialGraphServer := NewSocialGraphServer(dbClient)
	pb.RegisterSocialGraphServiceServer(grpcServer, socialGraphServer)
	
	// Enable reflection for debugging with grpcurl
	reflection.Register(grpcServer)

	log.Printf("✅ Social Graph Service listening on port %s", grpcPort)
	log.Printf("📊 DynamoDB Tables: %s, %s", followersTableName, followingTableName)
	
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
