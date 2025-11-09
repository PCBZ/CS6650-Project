package config

import (
	"os"
	"strconv"
)

type Config struct {
	// Server
	Port int
	Env  string

	// AWS
	AWSRegion string

	// DynamoDB
	PostsTableName string

	// SQS
	SQSQueueURL string

	// Service Endpoints
	UserServiceEndpoint        string
	PostServiceEndpoint        string
	SocialGraphServiceEndpoint string

	// Fan-out Strategy
	FanoutStrategy     string
	CelebrityThreshold int

	// Logging
	LogLevel string
}

func Load() *Config {
	return &Config{
		Port:                       getEnvInt("PORT", 8084),
		Env:                        getEnv("ENVIRONMENT", "dev"),
		AWSRegion:                  getEnv("AWS_REGION", "us-west-2"),
		PostsTableName:             getEnv("DYNAMODB_TABLE_NAME", "posts-timeline_service"),
		SQSQueueURL:                getEnv("SQS_QUEUE_URL", ""),
		UserServiceEndpoint:        getEnv("USER_SERVICE_URL", "user-service-grpc:50051"),
		PostServiceEndpoint:        getEnv("POST_SERVICE_URL", "post-service-grpc:50051"),
		SocialGraphServiceEndpoint: getEnv("SOCIAL_GRAPH_SERVICE_URL", "social-graph-service-grpc:50051"),
		FanoutStrategy:             getEnv("FANOUT_STRATEGY", "push"),
		CelebrityThreshold:         getEnvInt("CELEBRITY_THRESHOLD", 50000),
		LogLevel:                   getEnv("LOG_LEVEL", "info"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
	}
	return defaultValue
}
