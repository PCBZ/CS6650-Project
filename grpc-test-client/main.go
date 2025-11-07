package main

import (
	"context"
	"flag"
	"log"
	"time"

	pb "github.com/cs6650/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	// Command line flags
	serverAddr := flag.String("server", "localhost:50051", "gRPC server address")
	userIDs := flag.String("users", "1,2,3", "Comma-separated list of user IDs to query")
	flag.Parse()

	// Connect to the gRPC server
	log.Printf("Connecting to gRPC server at %s...", *serverAddr)
	conn, err := grpc.Dial(*serverAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	log.Println("✓ Successfully connected to gRPC server")

	// Create the client
	client := pb.NewUserServiceClient(conn)

	// Parse user IDs from the flag
	var userIDList []int64
	if *userIDs != "" {
		// Simple parsing - you can enhance this
		var id int64
		for i := 0; i < len(*userIDs); i++ {
			if (*userIDs)[i] >= '0' && (*userIDs)[i] <= '9' {
				id = id*10 + int64((*userIDs)[i]-'0')
			} else if (*userIDs)[i] == ',' {
				if id > 0 {
					userIDList = append(userIDList, id)
					id = 0
				}
			}
		}
		if id > 0 {
			userIDList = append(userIDList, id)
		}
	}

	// If no valid IDs parsed, use defaults
	if len(userIDList) == 0 {
		userIDList = []int64{1, 2, 3}
	}

	// Test the BatchGetUserInfo RPC
	log.Printf("\nTesting BatchGetUserInfo with user IDs: %v", userIDList)
	testBatchGetUserInfo(client, userIDList)

	log.Println("\n✓ gRPC test completed successfully!")
}

func testBatchGetUserInfo(client pb.UserServiceClient, userIDs []int64) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	req := &pb.BatchGetUserInfoRequest{
		UserIds: userIDs,
	}

	log.Println("\nSending BatchGetUserInfo request...")
	resp, err := client.BatchGetUserInfo(ctx, req)
	if err != nil {
		log.Fatalf("BatchGetUserInfo failed: %v", err)
	}

	// Display results
	log.Println("\n--- Response ---")
	if resp.ErrorCode != "" {
		log.Printf("Error Code: %s", resp.ErrorCode)
		log.Printf("Error Message: %s", resp.ErrorMessage)
		return
	}

	log.Printf("Found %d users:", len(resp.Users))
	for userID, userInfo := range resp.Users {
		log.Printf("  - User ID %d: %s", userID, userInfo.Username)
	}

	if len(resp.NotFound) > 0 {
		log.Printf("\nNot found: %v", resp.NotFound)
	}

	log.Println("----------------")
}
