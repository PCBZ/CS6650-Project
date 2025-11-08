package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	pb "github.com/cs6650/proto"
	"github.com/gorilla/mux"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type Gateway struct {
	userServiceURL      string
	userServiceGRPCHost string
	timelineServiceURL  string
	grpcClient          pb.UserServiceClient
	grpcConn            *grpc.ClientConn
}

func main() {
	userServiceURL := getEnv("USER_SERVICE_URL", "http://localhost:8081")
	userServiceGRPCHost := getEnv("USER_SERVICE_GRPC_HOST", "localhost:50051")
	timelineServiceURL := getEnv("TIMELINE_SERVICE_URL", "http://localhost:8084")

	gateway := &Gateway{
		userServiceURL:      userServiceURL,
		userServiceGRPCHost: userServiceGRPCHost,
		timelineServiceURL:  timelineServiceURL,
	}

	// Initialize gRPC connection if gRPC host is provided
	if userServiceGRPCHost != "" {
		if err := gateway.initGRPCClient(); err != nil {
			log.Printf("Warning: Failed to initialize gRPC client: %v. Falling back to HTTP.", err)
		} else {
			log.Printf("gRPC client initialized successfully for %s", userServiceGRPCHost)
			defer gateway.grpcConn.Close()
		}
	}

	router := mux.NewRouter()

	// Health check endpoint
	router.HandleFunc("/health", healthHandler).Methods("GET")

	// User service routes - support both /users and /api/users paths
	router.HandleFunc("/users", gateway.createUserHandler).Methods("POST")
	router.HandleFunc("/users", gateway.getUsersHandler).Methods("GET")
	router.HandleFunc("/api/users", gateway.createUserHandler).Methods("POST")
	router.HandleFunc("/api/users", gateway.getUsersHandler).Methods("GET")

	// Timeline service routes - support both /timeline and /api/timeline paths
	router.PathPrefix("/api/timeline").HandlerFunc(gateway.forwardToTimelineService)
	router.PathPrefix("/timeline").HandlerFunc(gateway.forwardToTimelineService)

	// Enable CORS
	router.Use(corsMiddleware)

	port := getEnv("PORT", "3000")
	log.Printf("Web Service (API Gateway) starting on port %s", port)
	log.Printf("User Service URL: %s", userServiceURL)
	log.Printf("User Service gRPC Host: %s", userServiceGRPCHost)
	log.Printf("Timeline Service URL: %s", timelineServiceURL)
	log.Fatal(http.ListenAndServe(":"+port, router))
}

// initGRPCClient establishes a connection to the user-service gRPC endpoint
func (g *Gateway) initGRPCClient() error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Create gRPC connection with retry and keepalive
	conn, err := grpc.DialContext(ctx, g.userServiceGRPCHost,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to gRPC server: %w", err)
	}

	g.grpcConn = conn
	g.grpcClient = pb.NewUserServiceClient(conn)
	return nil
}

// createUserHandler proxies POST /users requests to the user-service
func (g *Gateway) createUserHandler(w http.ResponseWriter, r *http.Request) {
	// Read the request body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeErrorResponse(w, "Failed to read request body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// Create endpoint URL
	userServiceEndpoint := fmt.Sprintf("%s/api/users", g.userServiceURL)

	// Make the request to user-service
	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequest("POST", userServiceEndpoint, bytes.NewReader(body))
	if err != nil {
		log.Printf("Failed to create request to user-service: %v", err)
		writeErrorResponse(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Failed to forward request to user-service: %v", err)
		writeErrorResponse(w, "Failed to communicate with user service", http.StatusServiceUnavailable)
		return
	}
	defer resp.Body.Close()

	// Copy response back to client
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

// getUsersHandler proxies GET /users requests to the user-service
func (g *Gateway) getUsersHandler(w http.ResponseWriter, r *http.Request) {
	// Construct the full URL with query parameters
	userServiceEndpoint := fmt.Sprintf("%s/api/users", g.userServiceURL)
	if r.URL.RawQuery != "" {
		userServiceEndpoint = fmt.Sprintf("%s/api/users?%s", g.userServiceURL, r.URL.RawQuery)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequest("GET", userServiceEndpoint, nil)
	if err != nil {
		log.Printf("Failed to create request to user-service: %v", err)
		writeErrorResponse(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Failed to forward request to user-service: %v", err)
		writeErrorResponse(w, "Failed to communicate with user service", http.StatusServiceUnavailable)
		return
	}
	defer resp.Body.Close()

	// Copy response back to client
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

// BatchGetUserInfo demonstrates using gRPC to call user-service
// This can be used by other handlers that need to enrich data with user information
func (g *Gateway) BatchGetUserInfo(ctx context.Context, userIDs []int64) (map[int64]*pb.UserInfo, error) {
	if g.grpcClient == nil {
		return nil, fmt.Errorf("gRPC client not initialized")
	}

	req := &pb.BatchGetUserInfoRequest{
		UserIds: userIDs,
	}

	resp, err := g.grpcClient.BatchGetUserInfo(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("gRPC call failed: %w", err)
	}

	if resp.ErrorCode != "" {
		return nil, fmt.Errorf("user service error: %s - %s", resp.ErrorCode, resp.ErrorMessage)
	}

	return resp.Users, nil
}

// forwardToTimelineService forwards all timeline-related requests to the timeline service
func (g *Gateway) forwardToTimelineService(w http.ResponseWriter, r *http.Request) {
	// Construct the target URL - keep the same path
	targetURL := fmt.Sprintf("%s%s", g.timelineServiceURL, r.URL.Path)
	if r.URL.RawQuery != "" {
		targetURL = fmt.Sprintf("%s?%s", targetURL, r.URL.RawQuery)
	}

	// Read request body if present
	var body io.Reader
	if r.Body != nil {
		bodyBytes, err := io.ReadAll(r.Body)
		if err != nil {
			writeErrorResponse(w, "Failed to read request body", http.StatusBadRequest)
			return
		}
		defer r.Body.Close()
		body = bytes.NewReader(bodyBytes)
	}

	// Create the forwarding request
	client := &http.Client{Timeout: 30 * time.Second}
	req, err := http.NewRequest(r.Method, targetURL, body)
	if err != nil {
		log.Printf("Failed to create request to timeline service: %v", err)
		writeErrorResponse(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Copy request headers
	for name, headers := range r.Header {
		for _, h := range headers {
			req.Header.Add(name, h)
		}
	}

	// Forward the request
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Failed to forward request to timeline service: %v", err)
		writeErrorResponse(w, "Failed to communicate with timeline service", http.StatusServiceUnavailable)
		return
	}
	defer resp.Body.Close()

	// Copy response headers
	for name, headers := range resp.Header {
		for _, h := range headers {
			w.Header().Add(name, h)
		}
	}

	// Copy response status and body
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":    "healthy",
		"service":   "web-service",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

func writeErrorResponse(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(map[string]string{"error": message})
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
