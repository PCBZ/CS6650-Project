package main

import (
	"context"
	"log"
	"net"
	"net/http"
	"os"
	"post-service/internal/client"
	"post-service/internal/handler"
	"post-service/internal/repository"
	"post-service/internal/service"
	"sync"
	"time"

	pb "github.com/cs6650/proto/post"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/sns"
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
	// Load configuration with optimized HTTP client and retry settings
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithHTTPClient(&http.Client{
			Transport: &http.Transport{
				MaxIdleConns:          1000,             // Total connection pool ✅
				MaxIdleConnsPerHost:   200,              // Per host connection number ✅
				MaxConnsPerHost:       300,              // Maximum connections per host ✅
				IdleConnTimeout:       30 * time.Second, // Reduced to 30s, avoid connection buildup
				DisableKeepAlives:     false,            // Keep connection reuse ✅
				TLSHandshakeTimeout:   5 * time.Second,  // Reduced to 5s, faster failure
				ExpectContinueTimeout: 1 * time.Second,  // Added this, reduce HTTP/1.1 delay
				ResponseHeaderTimeout: 10 * time.Second, // Added response header timeout
				DisableCompression:    false,            // Keep compression, reduce network transfer
				ForceAttemptHTTP2:     true,             // Force HTTP/2, more efficient
				WriteBufferSize:       32 * 1024,        // Increase write buffer
				ReadBufferSize:        32 * 1024,        // Increase read buffer
			},
			Timeout: 3 * time.Second, // Reduced to 3s, sufficient for 500 user queries
		}),
		config.WithRetryMaxAttempts(2),              // Add retry configuration
		config.WithRetryMode(aws.RetryModeAdaptive), // Adaptive retry
	)
	if err != nil {
		log.Fatal("Failed to load AWS config: %w", err)
	}

	// Initialize AWS client
	dynamoClient := dynamodb.NewFromConfig(cfg)
	snsClient := sns.NewFromConfig(cfg)

	// Configuration
	tableName := getEnv("DYNAMO_TABLE", "posts-table")
	snsTopicARN := getEnv("SNS_TOPIC_ARN", "")
	socialGraphURL := getEnv("SOCIAL_GRAPH_URL", "localhost:50052")

	//Initialize repository
	postRepository := repository.NewPostRepository(dynamoClient, tableName)

	//Initialize external service client
	log.Printf("Initializing Social Graph client with endpoint: %s", socialGraphURL)
	socialGraphClient, err := client.NewSocialGraphClient(socialGraphURL)
	if err != nil {
		log.Fatalf("failed to create social graph client: %v", err)
	}
	defer socialGraphClient.Close()

	//Initialize services
	fanoutService := service.NewFanoutService(socialGraphClient, snsClient, snsTopicARN)
	postService := service.NewPostService(postRepository, fanoutService)

	//Initialize gRPC Handler
	grpcHandler := handler.NewGRPCHandler(postService)

	//Initialize Post Handler
	postHandler := handler.NewPostHandler(postService)

	// Setup HTTP router
	router := gin.Default()

	router.Use(corsMiddleware())

	api := router.Group("/api")
	{
		api.POST("/posts", postHandler.ExecuteStrategy)
		api.GET("/health", postHandler.Health)
	}

	router.POST("/posts", postHandler.ExecuteStrategy)
	router.GET("/health", postHandler.Health)

	var wg sync.WaitGroup
	wg.Add(2)

	// Start gRPC server in goroutine concurrently
	go func() {
		defer wg.Done()
		lis, err := net.Listen("tcp", ":50053")
		if err != nil {
			log.Fatalf("failed to listen gRPC server: %v", err)
		}

		grpcServer := grpc.NewServer()
		pb.RegisterPostServiceServer(grpcServer, grpcHandler)

		// Enable gRPC reflection for tools like grpcurl
		reflection.Register(grpcServer)

		log.Println("Post Service gRPC server running on :50053")
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatalf("Failed to serve gRPC: %v", err)
		}
	}()

	// Start HTTP server in goroutine
	go func() {
		defer wg.Done()
		log.Println("Starting Post Service HTTP server on :8083")
		if err := router.Run(":8083"); err != nil {
			log.Fatalf("Failed to start HTTP server: %v", err)
		}
	}()

	// Wait for both servers
	wg.Wait()

}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
