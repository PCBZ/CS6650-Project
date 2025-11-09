package config

import (
	"os"
	"strconv"
)

type Config struct {
	// Server
	HTTPPort int
	GRPCPort int
	Env      string

	// AWS
	AWSRegion string

	// DynamoDB
	FollowersTableName string
	FollowingTableName string

	// External Services
	UserServiceEndpoint string

	// Data Generation (for testing)
	DefaultNumUsers      int
	DefaultNumFollowers  int
	PowerLawExponent     float64
	CelebrityThreshold   int

	// Logging
	LogLevel string
}

func Load() *Config {
	return &Config{
		HTTPPort:            getEnvInt("HTTP_PORT", 8085),
		GRPCPort:            getEnvInt("GRPC_PORT", 50052),
		Env:                 getEnv("ENVIRONMENT", "dev"),
		AWSRegion:           getEnv("AWS_REGION", "us-west-2"),
		FollowersTableName:  getEnv("FOLLOWERS_TABLE", "social-graph-followers"),
		FollowingTableName:  getEnv("FOLLOWING_TABLE", "social-graph-following"),
		UserServiceEndpoint: getEnv("USER_SERVICE_URL", "user-service-grpc:50051"),
		DefaultNumUsers:     getEnvInt("DEFAULT_NUM_USERS", 10000),
		DefaultNumFollowers: getEnvInt("DEFAULT_NUM_FOLLOWERS", 100),
		PowerLawExponent:    getEnvFloat("POWER_LAW_EXPONENT", 2.0),
		CelebrityThreshold:  getEnvInt("CELEBRITY_THRESHOLD", 50000),
		LogLevel:            getEnv("LOG_LEVEL", "info"),
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

func getEnvFloat(key string, defaultValue float64) float64 {
	if value := os.Getenv(key); value != "" {
		if floatVal, err := strconv.ParseFloat(value, 64); err == nil {
			return floatVal
		}
	}
	return defaultValue
}
