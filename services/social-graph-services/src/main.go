package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"sync"

	appConfig "github.com/PCBZ/CS6650-Project/services/social-graph-services/src/config"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	pb "github.com/PCBZ/CS6650-Project/services/social-graph-services/socialgraph"
	"github.com/gin-gonic/gin"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

// corsMiddleware handles CORS for requests from API Gateway
func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		c.Writer.Header().Set("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusOK)
			return
		}

		c.Next()
	}
}

func main() {
	// Load configuration
	cfg := appConfig.Load()
	log.Printf("Loaded config: %+v", cfg)
	log.Printf("Social Graph Service starting - Environment: %s, HTTP Port: %d, gRPC Port: %d",
		cfg.Env, cfg.HTTPPort, cfg.GRPCPort)

	// Load AWS configuration
	awsCfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(cfg.AWSRegion),
	)
	if err != nil {
		log.Fatalf("Unable to load SDK config: %v", err)
	}

	// Create DynamoDB client
	dynamoClient := dynamodb.NewFromConfig(awsCfg)
	
	// Initialize DynamoDB client wrapper
	dbClient := NewDynamoDBClient(dynamoClient, cfg.FollowersTableName, cfg.FollowingTableName)
	log.Printf("DynamoDB Tables: %s, %s", cfg.FollowersTableName, cfg.FollowingTableName)

	// Initialize handlers
	grpcHandler := NewSocialGraphServer(dbClient)
	httpHandler := NewHTTPHandler(dbClient)

	// Setup HTTP router
	router := gin.Default()
	router.Use(corsMiddleware())

	// Routes - support both /api prefix and direct paths for gateway compatibility
	api := router.Group("/api")
	{
		// Follow/unfollow operations
		api.POST("/follow", httpHandler.FollowUser)
		
		// User followers and following lists
		api.GET("/:user_id/followers", httpHandler.GetFollowers)
		api.GET("/:user_id/following", httpHandler.GetFollowing)
		
		// Legacy routes
		api.GET("/health", httpHandler.Health)
		api.GET("/followers/:userId/count", httpHandler.GetFollowerCount)
		api.GET("/following/:userId/count", httpHandler.GetFollowingCount)
		api.GET("/relationship/check", httpHandler.CheckFollowRelationship)
	}

	// Direct routes (without /api prefix)
	router.POST("/follow", httpHandler.FollowUser)
	router.GET("/:user_id/followers", httpHandler.GetFollowers)
	router.GET("/:user_id/following", httpHandler.GetFollowing)
	router.GET("/health", httpHandler.Health)
	router.GET("/followers/:userId/count", httpHandler.GetFollowerCount)
	router.GET("/following/:userId/count", httpHandler.GetFollowingCount)
	router.GET("/relationship/check", httpHandler.CheckFollowRelationship)

	var wg sync.WaitGroup
	wg.Add(2)

	// Start gRPC server in goroutine
	go func() {
		defer wg.Done()
		lis, err := net.Listen("tcp", fmt.Sprintf(":%d", cfg.GRPCPort))
		if err != nil {
			log.Fatalf("Failed to listen on gRPC port %d: %v", cfg.GRPCPort, err)
		}

		grpcServer := grpc.NewServer()
		pb.RegisterSocialGraphServiceServer(grpcServer, grpcHandler)
		
		// Enable reflection for debugging with grpcurl
		reflection.Register(grpcServer)

		log.Printf("Social Graph Service gRPC server listening on port %d", cfg.GRPCPort)
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatalf("Failed to serve gRPC: %v", err)
		}
	}()

	// Start HTTP server in goroutine
	go func() {
		defer wg.Done()
		log.Printf("Social Graph Service HTTP server listening on port %d", cfg.HTTPPort)
		if err := router.Run(fmt.Sprintf(":%d", cfg.HTTPPort)); err != nil {
			log.Fatalf("Failed to start HTTP server: %v", err)
		}
	}()

	// Wait for both servers
	wg.Wait()
}