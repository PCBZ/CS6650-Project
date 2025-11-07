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
		Port:                       getEnvInt("TIMELINE_SERVICE_PORT", 8084),
		Env:                        getEnv("ENVIRONMENT", "dev"),
		AWSRegion:                  getEnv("AWS_REGION", "us-east-1"),
		PostsTableName:             getEnv("DYNAMODB_POSTS_TABLE", "posts-dev"),
		SQSQueueURL:                getEnv("SQS_QUEUE_URL", "https://sqs.us-east-1.amazonaws.com/123456789012/timeline-feed-queue"),
		UserServiceEndpoint:        getEnv("USER_SERVICE_ENDPOINT", "mock"),
		PostServiceEndpoint:        getEnv("POST_SERVICE_ENDPOINT", "mock"),
		SocialGraphServiceEndpoint: getEnv("SOCIAL_GRAPH_SERVICE_ENDPOINT", "mock"),
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
