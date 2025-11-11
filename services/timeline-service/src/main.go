package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/config"
	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/db"
	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/fanout"
	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/grpc"
	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/handlers"
	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/processor"
	sqsClient "github.com/PCBZ/CS6650-Project/services/timeline-service/src/sqs"
	"github.com/gin-gonic/gin"
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
	cfg := config.Load()
	log.Printf("Loaded config: %+v", cfg)

	log.Printf("Timeline Service starting - Environment: %s, Strategy: %s, Port: %d",
		cfg.Env, cfg.FanoutStrategy, cfg.Port)

	// Setup context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Connect to DynamoDB
	dynamoClient, err := db.NewDynamoDBClient(ctx, cfg.AWSRegion)
	if err != nil {
		log.Fatalf("Failed to create DynamoDB client: %v", err)
	}
	log.Println("Connected to DynamoDB")

	// Connect to SQS
	sqsClientWrapper, err := sqsClient.NewSQSClient(ctx, cfg.AWSRegion)
	if err != nil {
		log.Fatalf("Failed to create SQS client: %v", err)
	}
	log.Println("Connected to SQS")

	// Initialize service clients
	// Try to create user service client, but don't fail if it's not available yet
	// Service Connect may take time to register the service
	userServiceClient, err := grpc.NewUserServiceClient(cfg.UserServiceEndpoint)
	if err != nil {
		log.Printf("Warning: Failed to create User Service client: %v. Will retry on first use.", err)
		userServiceClient = nil // Set to nil so we can check and retry later
	}

	postServiceClient := grpc.NewPostServiceClient(cfg.PostServiceEndpoint)
	socialGraphServiceClient := grpc.NewSocialGraphServiceClient(cfg.SocialGraphServiceEndpoint)

	// Initialize strategies
	strategies := map[string]fanout.Strategy{
		"push":   fanout.NewPushStrategy(dynamoClient.GetClient(), cfg.PostsTableName),
		"pull":   fanout.NewPullStrategy(postServiceClient, socialGraphServiceClient),
		"hybrid": fanout.NewHybridStrategy(dynamoClient.GetClient(), cfg.PostsTableName, postServiceClient, socialGraphServiceClient),
	}

	// Initialize SQS processor for handling feed write messages
	pushStrategy := strategies["push"]
	sqsProcessor := processor.NewSQSProcessor(
		sqsClientWrapper.GetClient(),
		cfg.SQSQueueURL,
		pushStrategy,
		userServiceClient,
	)

	// Setup handlers
	timelineHandler := handlers.NewTimelineHandler(strategies, cfg)

	// Setup Gin router
	router := gin.Default()

	// Enable CORS for gateway requests
	router.Use(corsMiddleware())

	// Routes - support both /api/timeline and /timeline paths for gateway compatibility
	api := router.Group("/api")
	{
		// Timeline endpoints
		api.GET("/timeline/:user_id", timelineHandler.GetTimeline)

		// Health check
		api.GET("/health", timelineHandler.Health)
	}

	// Alternative routes without /api prefix (for direct access or different gateway routing)
	router.GET("/timeline/:user_id", timelineHandler.GetTimeline)
	router.GET("/health", timelineHandler.Health)

	// Server configuration
	server := &http.Server{
		Addr:           fmt.Sprintf(":%d", cfg.Port),
		Handler:        router,
		ReadTimeout:    15 * time.Second,
		WriteTimeout:   15 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}

	// Start SQS processor in a goroutine
	go func() {
		if err := sqsProcessor.ProcessMessages(context.Background()); err != nil {
			log.Printf("SQS processor failed: %v", err)
		}
	}()

	// Start server in a goroutine
	go func() {
		log.Printf("Server starting on %s", server.Addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v", err)
		}
	}()

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutdown signal received")

	// Graceful shutdown with timeout
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("Server shutdown failed: %v", err)
	}

	log.Println("Server gracefully stopped")
}
