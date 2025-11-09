# Social Graph Service - gRPC API Implementation

## Overview
This document describes the gRPC API implementation for the social-graph-service, matching the exact specifications provided.

## Implemented RPC Methods

### 1. GetFollowing()
**Endpoint**: `POST /social-graph/getFollowing`

**Purpose**: Retrieves the list of users that a specified user follows, with optional filtering by minimum follower count and result limiting.

**Request Schema**:
```protobuf
message GetFollowingRequest {
  int64 user_id = 1;           // Required: ID of the user whose following list to retrieve
  int32 min_followers = 2;     // Optional: Minimum follower count filter (default: 0)
  int32 limit = 3;             // Optional: Maximum number of users to return (default: 1000)
}
```

**Response Schema**:
```protobuf
message GetFollowingResponse {
  repeated int64 user_ids = 1;     // List of user IDs that the user follows
  int32 total_count = 2;           // Total count before limit applied
  bool has_more = 3;               // Whether there are more results available
  string error_message = 4;        // Error message if request failed
}
```

**Implementation Details**:
- Default limit: 1000
- Filters followed users by their follower count if `min_followers > 0`
- Returns total count before limit is applied
- Sets `has_more = true` if results were truncated by limit

**Example**:
```go
// Get users that user 123 follows, who have at least 100 followers, limit to 50
req := &pb.GetFollowingRequest{
    UserId:       123,
    MinFollowers: 100,
    Limit:        50,
}
resp, err := client.GetFollowing(ctx, req)
```

---

### 2. GetFollowers()
**Endpoint**: `POST /social-graph/getFollowers`

**Purpose**: Retrieves the list of users who follow a specified user, used for fan-out operations when a post is created.

**Request Schema**:
```protobuf
message GetFollowersRequest {
  int64 user_id = 1;           // Required: ID of the user whose followers to retrieve
  int32 limit = 2;             // Optional: Maximum number of followers to return (default: 1000)
  int32 offset = 3;            // Optional: Pagination offset (default: 0)
}
```

**Response Schema**:
```protobuf
message GetFollowersResponse {
  repeated int64 user_ids = 1;     // List of follower user IDs
  int32 total_count = 2;           // Total follower count before pagination
  bool has_more = 3;               // Whether there are more results available
  string error_message = 4;        // Error message if request failed
}
```

**Implementation Details**:
- Default limit: 1000
- Supports offset-based pagination for fan-out operations
- Returns total count of all followers
- Sets `has_more = true` if `(offset + limit) < total_count`

**Use Case - Fan-out**:
```go
// Get first batch of followers for post fan-out
req := &pb.GetFollowersRequest{
    UserId: 456,
    Limit:  1000,
    Offset: 0,
}
resp, err := client.GetFollowers(ctx, req)

// Process first batch...
// If resp.HasMore, fetch next batch with offset = 1000
```

---

### 3. GetFollowersCount()
**Endpoint**: `POST /social-graph/getFollowersCount`

**Purpose**: Retrieves the follower count for a specified user.

**Request Schema**:
```protobuf
message GetFollowersCountRequest {
  int64 user_id = 1;           // Required: ID of the user whose follower count to retrieve
}
```

**Response Schema**:
```protobuf
message GetFollowersCountResponse {
  int64 user_id = 1;           // User ID from the request
  int32 followers_count = 2;   // Number of followers this user has
  string error_message = 3;    // Error message if request failed
}
```

**Implementation Details**:
- Queries DynamoDB with `Select: types.SelectCount` for efficient counting
- Returns 0 if user has no followers
- Returns error message in response if query fails (does not throw exception)

**Example**:
```go
req := &pb.GetFollowersCountRequest{
    UserId: 789,
}
resp, err := client.GetFollowersCount(ctx, req)
// resp.FollowersCount contains the count
```

---

## Additional Implemented Methods

### 4. FollowUser()
Creates a follow relationship between two users.

**Validations**:
- Prevents self-follows (error code: `SELF_FOLLOW_NOT_ALLOWED`)
- Prevents duplicate follows (error code: `ALREADY_FOLLOWING`)

### 5. UnfollowUser()
Removes a follow relationship.

**Validations**:
- Returns error if relationship doesn't exist (error code: `NOT_FOLLOWING`)

### 6. GetFollowingCount()
Returns the count of users that a specified user follows.

### 7. CheckFollowRelationship()
Checks if a follow relationship exists between two users.

### 8. BatchCreateFollowRelationships()
Creates multiple follow relationships in batch (for data generation).

---

## Technical Implementation

### DynamoDB Schema
**FollowersTable** (tracks who follows whom):
- Hash Key: `user_id` (int64) - The user being followed
- Range Key: `follower_id` (int64) - The user who follows
- Attributes: `created_at` (timestamp)

**FollowingTable** (tracks whom a user follows):
- Hash Key: `user_id` (int64) - The user who follows
- Range Key: `followee_id` (int64) - The user being followed
- Attributes: `created_at` (timestamp)

### Offset-based Pagination (GetFollowers)
Since DynamoDB doesn't natively support offset-based pagination, the implementation:
1. Fetches `offset + limit` records from DynamoDB
2. Slices the result array to apply the offset: `followers[offset:offset+limit]`
3. Calculates `has_more` based on total count

**Performance Note**: For large offsets, this approach fetches more data than needed. For production at scale, consider:
- Using cursor-based pagination internally
- Caching results
- Using a secondary index optimized for pagination

### Min Followers Filtering (GetFollowing)
The `min_followers` filter is applied post-query:
1. Fetch following list from DynamoDB
2. For each followed user, query their follower count
3. Filter out users with fewer than `min_followers`
4. Apply limit to filtered results

**Performance Note**: This requires N+1 queries (1 for following list + 1 per followed user). For better performance:
- Consider maintaining a denormalized `follower_count` field in user records
- Use batch GetItem operations
- Implement caching for follower counts

---

## Error Handling

All methods follow a consistent error handling pattern:
- Errors are logged via `log.Printf`
- Response includes `error_message` field (never returns gRPC error)
- Original request continues with partial data when possible
- Validation errors return immediately with descriptive messages

---

## Testing

### Using grpcurl

**GetFollowing with min_followers filter**:
```bash
grpcurl -plaintext -d '{
  "user_id": 123,
  "min_followers": 100,
  "limit": 50
}' localhost:50052 socialgraph.SocialGraphService/GetFollowing
```

**GetFollowers with offset pagination**:
```bash
grpcurl -plaintext -d '{
  "user_id": 456,
  "limit": 1000,
  "offset": 0
}' localhost:50052 socialgraph.SocialGraphService/GetFollowers
```

**GetFollowersCount**:
```bash
grpcurl -plaintext -d '{
  "user_id": 789
}' localhost:50052 socialgraph.SocialGraphService/GetFollowersCount
```

---

## Service Configuration

- **gRPC Port**: 50052
- **HTTP Port**: 8085 (for REST API)
- **Protocol**: gRPC with Protocol Buffers (proto3)
- **Package**: `socialgraph`
- **Service Connect**: Enabled for ECS service discovery

---

## Comparison: REST vs gRPC

| Feature | REST API | gRPC API |
|---------|----------|----------|
| Pagination | Cursor-based (base64) | Offset-based |
| Following Filter | None | min_followers support |
| Default Limit | 50 | 1000 |
| Error Handling | HTTP status codes | Error message in response |
| Use Case | Web/mobile clients | Service-to-service (timeline, post) |

---

## Integration with Other Services

### Timeline Service Integration
```go
// When creating a post, get followers for fan-out
followersResp, err := socialGraphClient.GetFollowers(ctx, &pb.GetFollowersRequest{
    UserId: authorID,
    Limit:  1000,
    Offset: 0,
})

// Fan-out post to each follower's timeline
for _, followerID := range followersResp.UserIds {
    // Insert into timeline...
}

// If more followers exist, continue with next batch
if followersResp.HasMore {
    // Process offset = 1000, 2000, etc.
}
```

### Post Service Integration
```go
// When building a feed, get users with high engagement
followingResp, err := socialGraphClient.GetFollowing(ctx, &pb.GetFollowingRequest{
    UserId:       currentUserID,
    MinFollowers: 1000,  // Only get following who are "popular"
    Limit:        100,
}]

// Fetch recent posts from these high-engagement users
```

---

## Performance Considerations

1. **GetFollowing with min_followers**:
   - Requires N+1 queries (can be slow for large following lists)
   - Consider denormalizing follower counts or caching

2. **GetFollowers with large offsets**:
   - Fetches more data than needed from DynamoDB
   - Consider implementing cursor-based pagination for production

3. **DynamoDB Query Limits**:
   - DynamoDB has 1MB result size limit per query
   - Large following/follower lists may require multiple queries
   - Current implementation handles this transparently

4. **Recommended Optimizations**:
   - Add caching layer (Redis/ElastiCache) for frequently accessed data
   - Implement batch operations for count queries
   - Use DynamoDB Streams to maintain materialized views
   - Add circuit breakers for service-to-service calls

---

## Status
✅ **All three required RPC methods are fully implemented and match the exact specifications provided.**

- ✅ GetFollowing() - with min_followers filter and limit
- ✅ GetFollowers() - with offset-based pagination and limit  
- ✅ GetFollowersCount() - returns follower count

The implementation is ready for deployment and integration testing.
