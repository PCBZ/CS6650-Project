package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"time"

	pb "github.com/cs6650/proto"

	"github.com/gorilla/mux"
	"github.com/lib/pq"
	"google.golang.org/grpc"
)

// User represents a user in the system
type User struct {
	UserID    int       `json:"user_id"`
	Username  string    `json:"username"`
	CreatedAt time.Time `json:"created_at"`
}

// CreateUserRequest represents the request body for creating a user
type CreateUserRequest struct {
	Username string `json:"username"`
}

// CreateUserResponse represents the response for creating a user
type CreateUserResponse struct {
	UserID    int       `json:"user_id"`
	Username  string    `json:"username"`
	CreatedAt time.Time `json:"created_at"`
}

// GetUsersResponse represents the response for getting all users
type GetUsersResponse struct {
	Users      []User `json:"users"`
	TotalCount int    `json:"total_count"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error string `json:"error"`
}

type Server struct {
	db *sql.DB
	pb.UnimplementedUserServiceServer
}

func main() {
	// Database connection parameters
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbName := getEnv("DB_NAME", "userservice")
	dbUser := getEnv("DB_USER", "postgres")
	dbPassword := getEnv("DB_PASSWORD", "123456")
	sslMode := getEnv("DB_SSLMODE", "require")

	// First, connect to the default 'postgres' database to create our service database
	if err := initializeServiceDatabase(dbHost, dbPort, dbUser, dbPassword, sslMode, dbName); err != nil {
		log.Fatal("Failed to initialize service database:", err)
	}

	// Now connect to our service database
	dsn := fmt.Sprintf("host=%s port=%s dbname=%s user=%s password=%s sslmode=%s",
		dbHost, dbPort, dbName, dbUser, dbPassword, sslMode)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	// Test database connection
	if err := db.Ping(); err != nil {
		log.Fatal("Failed to ping database:", err)
	}

	// Initialize database schema
	if err := initializeSchema(db); err != nil {
		log.Fatal("Failed to initialize database schema:", err)
	}

	server := &Server{db: db}

	// Setup HTTP routes
	router := mux.NewRouter()
	router.HandleFunc("/health", healthHandler).Methods("GET")
	router.HandleFunc("/api/users", server.createUserHandler).Methods("POST")
	router.HandleFunc("/api/users", server.getUsersHandler).Methods("GET")

	// Enable CORS
	router.Use(corsMiddleware)

	// Start HTTP server
	go func() {
		port := getEnv("PORT", "8081")
		log.Printf("User Service HTTP server starting on port %s", port)
		log.Fatal(http.ListenAndServe(":"+port, router))
	}()

	// Start gRPC server
	grpcPort := getEnv("GRPC_PORT", "50051")
	lis, err := net.Listen("tcp", ":"+grpcPort)
	if err != nil {
		log.Fatalf("Failed to listen on port %s: %v", grpcPort, err)
	}

	grpcServer := grpc.NewServer()
	pb.RegisterUserServiceServer(grpcServer, server)

	log.Printf("User Service gRPC server starting on port %s", grpcPort)
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve gRPC server: %v", err)
	}
}

// initializeServiceDatabase creates the service database and user if they don't exist
func initializeServiceDatabase(host, port, masterUser, masterPassword, sslMode, dbName string) error {
	// Validate database name to prevent SQL injection (alphanumeric and underscores only)
	dbNamePattern := regexp.MustCompile(`^[a-zA-Z_][a-zA-Z0-9_]*$`)
	if !dbNamePattern.MatchString(dbName) {
		return fmt.Errorf("invalid database name: must contain only alphanumeric characters and underscores, and start with a letter or underscore")
	}

	// Connect to the default postgres database as master user
	masterDSN := fmt.Sprintf("host=%s port=%s dbname=postgres user=%s password=%s sslmode=%s",
		host, port, masterUser, masterPassword, sslMode)

	masterDB, err := sql.Open("postgres", masterDSN)
	if err != nil {
		return fmt.Errorf("failed to connect to master database: %w", err)
	}
	defer masterDB.Close()

	if err := masterDB.Ping(); err != nil {
		return fmt.Errorf("failed to ping master database: %w", err)
	}

	log.Printf("Connected to PostgreSQL server successfully")

	// Create service database if it doesn't exist
	var exists bool
	checkDBQuery := "SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = $1)"
	err = masterDB.QueryRow(checkDBQuery, dbName).Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if database exists: %w", err)
	}

	if !exists {
		createDBQuery := fmt.Sprintf("CREATE DATABASE %s", pq.QuoteIdentifier(dbName))
		_, err = masterDB.Exec(createDBQuery)
		if err != nil {
			return fmt.Errorf("failed to create database %s: %w", dbName, err)
		}
		log.Printf("Created database: %s", dbName)
	} else {
		log.Printf("Database %s already exists", dbName)
	}

	// Create service user if it doesn't exist (optional - for future use)
	serviceUser := fmt.Sprintf("%s_user", dbName)
	// Validate service user name
	if !dbNamePattern.MatchString(serviceUser) {
		return fmt.Errorf("invalid service user name: must contain only alphanumeric characters and underscores")
	}

	var userExists bool
	checkUserQuery := "SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = $1)"
	err = masterDB.QueryRow(checkUserQuery, serviceUser).Scan(&userExists)
	if err != nil {
		return fmt.Errorf("failed to check if user exists: %w", err)
	}

	if !userExists {
		// Use a more secure approach: create user with a placeholder password, then alter it
		// This prevents password exposure in query logs
		createUserQuery := fmt.Sprintf("CREATE USER %s", pq.QuoteIdentifier(serviceUser))
		_, err = masterDB.Exec(createUserQuery)
		if err != nil {
			return fmt.Errorf("failed to create user %s: %w", serviceUser, err)
		}

		// Set password in a separate statement to minimize exposure
		setPasswordQuery := fmt.Sprintf("ALTER USER %s WITH PASSWORD $1", pq.QuoteIdentifier(serviceUser))
		_, err = masterDB.Exec(setPasswordQuery, masterPassword)
		if err != nil {
			return fmt.Errorf("failed to set password for user %s: %w", serviceUser, err)
		}

		// Grant privileges to the service user
		grantQuery := fmt.Sprintf("GRANT ALL PRIVILEGES ON DATABASE %s TO %s", pq.QuoteIdentifier(dbName), pq.QuoteIdentifier(serviceUser))
		_, err = masterDB.Exec(grantQuery)
		if err != nil {
			return fmt.Errorf("failed to grant privileges to user %s: %w", serviceUser, err)
		}
		log.Printf("Created user: %s and granted privileges", serviceUser)
	} else {
		log.Printf("User %s already exists", serviceUser)
	}

	return nil
}

// initializeSchema creates the required tables and indexes (renamed from initializeDatabase)
func initializeSchema(db *sql.DB) error {
	createTableQuery := `
	CREATE TABLE IF NOT EXISTS users (
		user_id SERIAL PRIMARY KEY,
		username VARCHAR(30) UNIQUE NOT NULL,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
	);

	CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
	CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
	`

	_, err := db.Exec(createTableQuery)
	if err != nil {
		return fmt.Errorf("failed to create tables: %w", err)
	}

	log.Printf("Database schema initialized successfully")
	return nil
}

func (s *Server) createUserHandler(w http.ResponseWriter, r *http.Request) {
	var req CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErrorResponse(w, "Invalid JSON payload", http.StatusBadRequest)
		return
	}

	// Validate username
	if len(req.Username) < 3 || len(req.Username) > 30 {
		writeErrorResponse(w, "Username must be between 3 and 30 characters", http.StatusBadRequest)
		return
	}

	// Insert user into database
	var user CreateUserResponse
	query := `
		INSERT INTO users (username) 
		VALUES ($1) 
		RETURNING user_id, username, created_at
	`

	err := s.db.QueryRow(query, req.Username).Scan(&user.UserID, &user.Username, &user.CreatedAt)
	if err != nil {
		if err.Error() == `pq: duplicate key value violates unique constraint "users_username_key"` {
			writeErrorResponse(w, "Username already exists", http.StatusBadRequest)
			return
		}
		log.Printf("Database error: %v", err)
		writeErrorResponse(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(user)
}

func (s *Server) getUsersHandler(w http.ResponseWriter, r *http.Request) {
	// Parse pagination parameters
	page := 1
	limit := 50

	if pageStr := r.URL.Query().Get("page"); pageStr != "" {
		if p, err := strconv.Atoi(pageStr); err == nil && p > 0 {
			page = p
		}
	}

	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
			limit = l
		}
	}

	offset := (page - 1) * limit

	// Get total count
	var totalCount int
	countQuery := "SELECT COUNT(*) FROM users"
	if err := s.db.QueryRow(countQuery).Scan(&totalCount); err != nil {
		log.Printf("Database error getting count: %v", err)
		writeErrorResponse(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Get users with pagination (without follower/following counts)
	query := `
		SELECT user_id, username, created_at 
		FROM users 
		ORDER BY created_at DESC 
		LIMIT $1 OFFSET $2
	`

	rows, err := s.db.Query(query, limit, offset)
	if err != nil {
		log.Printf("Database error: %v", err)
		writeErrorResponse(w, "Internal server error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var user User
		if err := rows.Scan(&user.UserID, &user.Username, &user.CreatedAt); err != nil {
			log.Printf("Row scan error: %v", err)
			writeErrorResponse(w, "Internal server error", http.StatusInternalServerError)
			return
		}
		users = append(users, user)
	}

	if err := rows.Err(); err != nil {
		log.Printf("Rows iteration error: %v", err)
		writeErrorResponse(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	response := GetUsersResponse{
		Users:      users,
		TotalCount: totalCount,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (s *Server) BatchGetUserInfo(ctx context.Context, req *pb.BatchGetUserInfoRequest) (*pb.BatchGetUserInfoResponse, error) {
	if len(req.UserIds) == 0 {
		return &pb.BatchGetUserInfoResponse{
			ErrorCode:    "INVALID_ARGUMENT",
			ErrorMessage: "UserIds cannot be empty",
		}, nil
	}

	// Convert int64 slice to interface slice for pq.Array
	userIDs := make([]interface{}, len(req.UserIds))
	for i, id := range req.UserIds {
		userIDs[i] = id
	}

	query := `
		SELECT user_id, username 
		FROM users 
		WHERE user_id = ANY($1)
	`

	rows, err := s.db.Query(query, pq.Array(userIDs))
	if err != nil {
		log.Printf("Database error: %v", err)
		return &pb.BatchGetUserInfoResponse{
			ErrorCode:    "INTERNAL",
			ErrorMessage: "Internal server error",
		}, nil
	}
	defer rows.Close()

	users := make(map[int64]*pb.UserInfo)
	notFound := []int64{}

	for rows.Next() {
		var userID int64
		var username string
		if err := rows.Scan(&userID, &username); err != nil {
			log.Printf("Row scan error: %v", err)
			return &pb.BatchGetUserInfoResponse{
				ErrorCode:    "INTERNAL",
				ErrorMessage: "Internal server error",
			}, nil
		}
		users[userID] = &pb.UserInfo{
			UserId:   userID,
			Username: username,
		}
	}

	// Check for not found user IDs
	for _, id := range req.UserIds {
		if _, found := users[id]; !found {
			notFound = append(notFound, id)
		}
	}

	if err := rows.Err(); err != nil {
		log.Printf("Rows iteration error: %v", err)
		return &pb.BatchGetUserInfoResponse{
			ErrorCode:    "INTERNAL",
			ErrorMessage: "Internal server error",
		}, nil
	}

	return &pb.BatchGetUserInfoResponse{
		Users:    users,
		NotFound: notFound,
	}, nil
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":    "healthy",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

func writeErrorResponse(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(ErrorResponse{Error: message})
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
