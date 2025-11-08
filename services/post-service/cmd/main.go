package main

import (
	"context"
	"log"
	"net"
	"os"
	"post-service/internal/client"
	"post-service/internal/handler"
	"post-service/internal/repository"
	"post-service/internal/service"
	pb "post-service/pkg/generated/post"
	"sync"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/gin-gonic/gin"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

func main() {
	// Load configuration
    cfg, err := config.LoadDefaultConfig(context.TODO())
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
	socialGraphClient, err := client.NewSocialGraphClient(socialGraphURL)
	if err != nil {
		log.Fatalf("failed to create social graph client: %v", err)
	}

	//Initialize services
	fanoutService := service.NewFanoutService(socialGraphClient, snsClient, snsTopicARN)
	postService := service.NewPostService(postRepository, fanoutService)

	//Initialize gRPC Handler
	grpcHandler := handler.NewGRPCHandler(postService)

	//Initialize Post Handler
	postHandler := handler.NewPostHandler(postService)

	// Setup HTTP router
	router := gin.Default()
	api := router.Group("/api")
	{
		api.POST("/posts", postHandler.ExecuteStrategy)
		api.POST("/posts/batch", postHandler.BatchGetPosts)
	}

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
		log.Println("Starting Post Service HTTP server on :8082")
		if err := router.Run(":8082"); err != nil {
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