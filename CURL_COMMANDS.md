# Social Graph API - curl Command Reference

## 🔍 Get Current ALB DNS

```bash
# Query ALB DNS
aws elbv2 describe-load-balancers \
  --region us-west-2 \
  --query "LoadBalancers[?contains(LoadBalancerName, 'cs6650')].DNSName" \
  --output text
```

```powershell
# PowerShell
$ALB_DNS = aws elbv2 describe-load-balancers `
  --region us-west-2 `
  --query "LoadBalancers[?contains(LoadBalancerName, 'cs6650')].DNSName" `
  --output text
Write-Host "ALB DNS: $ALB_DNS"
```

---

## 📊 Basic API Tests

### 1. Health Check
```bash
curl -X GET "http://${ALB_DNS}/api/social-graph/health"
```

**Expected Response:**
```json
{
  "status": "healthy",
  "service": "social-graph-service"
}
```

---

## 👥 Follower Operations

### 2. Get Follower Count
```bash
# Top user (User 913)
curl -X GET "http://${ALB_DNS}/api/social-graph/followers/913/count"

# Small users
curl -X GET "http://${ALB_DNS}/api/social-graph/followers/1/count"
curl -X GET "http://${ALB_DNS}/api/social-graph/followers/100/count"

# Medium user
curl -X GET "http://${ALB_DNS}/api/social-graph/followers/500/count"

# Big user
curl -X GET "http://${ALB_DNS}/api/social-graph/followers/4500/count"
```

**Expected Response:**
```json
{
  "userId": "913",
  "followerCount": 1500
}
```

### 3. Get Followers List (with pagination)
```bash
# Default (first 50 followers)
curl -X GET "http://${ALB_DNS}/api/social-graph/913/followers"

# With custom limit
curl -X GET "http://${ALB_DNS}/api/social-graph/913/followers?limit=10"

# With pagination cursor (use cursor from previous response)
curl -X GET "http://${ALB_DNS}/api/social-graph/913/followers?limit=50&cursor=eyJvZmZzZXQi..."
```

**Expected Response:**
```json
{
  "user_id": "913",
  "followers": [
    {"user_id": 123},
    {"user_id": 456}
  ],
  "total_count": 1500,
  "has_more": true,
  "next_cursor": "eyJvZmZzZXQiOjUwfQ=="
}
```

### 4. Get All Followers (loop through pages)
```bash
# Bash script to get all followers
USER_ID=913
ALB_DNS="your-alb-dns.elb.amazonaws.com"
CURSOR=""
PAGE=1

while true; do
  if [ -z "$CURSOR" ]; then
    RESPONSE=$(curl -s "http://${ALB_DNS}/api/social-graph/${USER_ID}/followers?limit=100")
  else
    RESPONSE=$(curl -s "http://${ALB_DNS}/api/social-graph/${USER_ID}/followers?limit=100&cursor=${CURSOR}")
  fi
  
  echo "Page $PAGE:"
  echo "$RESPONSE" | jq '.followers | length'
  
  HAS_MORE=$(echo "$RESPONSE" | jq -r '.has_more')
  if [ "$HAS_MORE" != "true" ]; then
    break
  fi
  
  CURSOR=$(echo "$RESPONSE" | jq -r '.next_cursor')
  PAGE=$((PAGE + 1))
done
```

---

## 🔗 Following Operations

### 5. Get Following Count
```bash
# Top user
curl -X GET "http://${ALB_DNS}/api/social-graph/following/913/count"

# Various users
curl -X GET "http://${ALB_DNS}/api/social-graph/following/1/count"
curl -X GET "http://${ALB_DNS}/api/social-graph/following/100/count"
curl -X GET "http://${ALB_DNS}/api/social-graph/following/500/count"
```

**Expected Response:**
```json
{
  "userId": "913",
  "followingCount": 25
}
```

### 6. Get Following List
```bash
# Default (all following)
curl -X GET "http://${ALB_DNS}/api/social-graph/913/following"

# With pagination
curl -X GET "http://${ALB_DNS}/api/social-graph/913/following?limit=20"
```

**Expected Response:**
```json
{
  "user_id": "913",
  "following": [
    {"user_id": 234},
    {"user_id": 567}
  ],
  "total_count": 25,
  "has_more": false,
  "next_cursor": ""
}
```

---

## 🔍 Relationship Checks

### 7. Check if User A Follows User B
```bash
# Check if User 1 follows User 913
curl -X GET "http://${ALB_DNS}/api/social-graph/relationship/check?followerId=1&targetId=913"

# Check if User 100 follows User 913
curl -X GET "http://${ALB_DNS}/api/social-graph/relationship/check?followerId=100&targetId=913"

# Check mutual follows
curl -X GET "http://${ALB_DNS}/api/social-graph/relationship/check?followerId=500&targetId=600"
curl -X GET "http://${ALB_DNS}/api/social-graph/relationship/check?followerId=600&targetId=500"
```

**Expected Response:**
```json
{
  "followerId": "1",
  "targetId": "913",
  "isFollowing": false
}
```

---

## 📈 Data Validation Tests

### 8. Verify Tier Distribution
```bash
# Check Small tier (expected: 0-50 followers)
for i in 1 10 100 500; do
  echo "User $i:"
  curl -s "http://${ALB_DNS}/api/social-graph/followers/$i/count" | jq '.followerCount'
done

# Check Medium tier (expected: 50-150 followers)
for i in 4001 4100 4200 4500; do
  echo "User $i:"
  curl -s "http://${ALB_DNS}/api/social-graph/followers/$i/count" | jq '.followerCount'
done

# Check Big tier (expected: 300-700 followers)
for i in 4751 4800 4900 4990; do
  echo "User $i:"
  curl -s "http://${ALB_DNS}/api/social-graph/followers/$i/count" | jq '.followerCount'
done

# Check Top tier (expected: 1500-2500 followers)
echo "User 913 (Top tier):"
curl -s "http://${ALB_DNS}/api/social-graph/followers/913/count" | jq '.followerCount'
```

### 9. Verify Following Counts
```bash
# Check various users' following counts
for user in 1 100 500 913 1000 2000 3000 4000; do
  echo "User $user following:"
  curl -s "http://${ALB_DNS}/api/social-graph/following/$user/count" | jq '.followingCount'
done
```

### 10. Sample Random Users
```bash
# Test 10 random users
for i in $(seq 1 10); do
  USER_ID=$((RANDOM % 5000 + 1))
  echo "User $USER_ID:"
  curl -s "http://${ALB_DNS}/api/social-graph/followers/$USER_ID/count" | jq '.followerCount'
  curl -s "http://${ALB_DNS}/api/social-graph/following/$USER_ID/count" | jq '.followingCount'
  echo ""
done
```

---

## 🧪 Edge Cases & Error Handling

### 11. Non-existent User
```bash
# User ID that doesn't exist
curl -X GET "http://${ALB_DNS}/api/social-graph/followers/999999/count"
```

**Expected Response:**
```json
{
  "userId": "999999",
  "followerCount": 0
}
```

### 12. Invalid Parameters
```bash
# Invalid user ID format
curl -X GET "http://${ALB_DNS}/api/social-graph/followers/abc/count"

# Missing query parameters
curl -X GET "http://${ALB_DNS}/api/social-graph/relationship/check"

# Invalid cursor
curl -X GET "http://${ALB_DNS}/api/social-graph/913/followers?cursor=invalid"
```

### 13. Large Pagination
```bash
# Request large page size
curl -X GET "http://${ALB_DNS}/api/social-graph/913/followers?limit=1000"

# Request very small page size
curl -X GET "http://${ALB_DNS}/api/social-graph/913/followers?limit=1"
```

---

## 📊 Performance Tests

### 14. Concurrent Requests
```bash
# Test with parallel requests (requires GNU parallel)
seq 1 100 | parallel -j 10 \
  'curl -s "http://${ALB_DNS}/api/social-graph/followers/{}/count"' | \
  jq -s 'length'

# Or with xargs
seq 1 100 | xargs -I {} -P 10 \
  curl -s "http://${ALB_DNS}/api/social-graph/followers/{}/count"
```

### 15. Response Time Test
```bash
# Measure response time
time curl -X GET "http://${ALB_DNS}/api/social-graph/followers/913/count"

# Detailed timing with curl
curl -w "\nTime: %{time_total}s\n" \
  -o /dev/null -s \
  "http://${ALB_DNS}/api/social-graph/followers/913/count"

# Test multiple endpoints
for endpoint in health followers/913/count following/913/count 913/followers; do
  echo "Testing $endpoint:"
  curl -w "Time: %{time_total}s\n" \
    -o /dev/null -s \
    "http://${ALB_DNS}/api/social-graph/$endpoint"
done
```

---

## 💾 DynamoDB Direct Verification

### 16. Compare API vs DynamoDB
```bash
# Get from API
API_COUNT=$(curl -s "http://${ALB_DNS}/api/social-graph/followers/913/count" | jq '.followerCount')

# Get from DynamoDB
DDB_COUNT=$(aws dynamodb get-item \
  --table-name social-graph-followers \
  --key '{"user_id": {"N": "913"}}' \
  --region us-west-2 \
  --query 'Item.follower_ids.L | length(@)' \
  --output text)

echo "API Count: $API_COUNT"
echo "DynamoDB Count: $DDB_COUNT"
[ "$API_COUNT" -eq "$DDB_COUNT" ] && echo "✅ Match!" || echo "❌ Mismatch!"
```

### 17. Verify Relationship Consistency
```bash
# Get User 1's following list from API
FOLLOWING=$(curl -s "http://${ALB_DNS}/api/social-graph/1/following" | jq -r '.following[].user_id')

# For each followee, verify User 1 appears in their followers
for followee in $FOLLOWING; do
  IS_FOLLOWER=$(curl -s "http://${ALB_DNS}/api/social-graph/$followee/followers" | \
    jq --arg uid "1" '.followers[] | select(.user_id == ($uid | tonumber)) | .user_id')
  
  if [ -n "$IS_FOLLOWER" ]; then
    echo "✅ User 1 is in User $followee's followers"
  else
    echo "❌ Inconsistency: User 1 follows $followee but not in followers list"
  fi
done
```

---

## 🔄 Complete Data Validation Script

### 18. Full Test Suite
```bash
#!/bin/bash
# Complete API validation script

ALB_DNS="${1:-your-alb-dns.elb.amazonaws.com}"
REGION="us-west-2"

echo "========================================="
echo "Social Graph API Validation"
echo "========================================="
echo "ALB DNS: $ALB_DNS"
echo ""

# Test 1: Health Check
echo "1. Health Check..."
HEALTH=$(curl -s "http://${ALB_DNS}/api/social-graph/health")
echo "$HEALTH" | jq '.'
echo ""

# Test 2: Verify Top User (913)
echo "2. Verify Top User (913)..."
FOLLOWER_COUNT=$(curl -s "http://${ALB_DNS}/api/social-graph/followers/913/count" | jq '.followerCount')
FOLLOWING_COUNT=$(curl -s "http://${ALB_DNS}/api/social-graph/following/913/count" | jq '.followingCount')
echo "  Followers: $FOLLOWER_COUNT (expected: 1500-2500)"
echo "  Following: $FOLLOWING_COUNT"
echo ""

# Test 3: Sample Small Users
echo "3. Sample Small Users..."
for user in 1 10 100; do
  COUNT=$(curl -s "http://${ALB_DNS}/api/social-graph/followers/$user/count" | jq '.followerCount')
  echo "  User $user: $COUNT followers (expected: 0-50)"
done
echo ""

# Test 4: Test Pagination
echo "4. Test Pagination..."
PAGE1=$(curl -s "http://${ALB_DNS}/api/social-graph/913/followers?limit=10")
CURSOR=$(echo "$PAGE1" | jq -r '.next_cursor')
PAGE1_COUNT=$(echo "$PAGE1" | jq '.followers | length')
HAS_MORE=$(echo "$PAGE1" | jq '.has_more')
echo "  Page 1: $PAGE1_COUNT items"
echo "  Has more: $HAS_MORE"
echo "  Cursor: ${CURSOR:0:30}..."
echo ""

# Test 5: Relationship Check
echo "5. Relationship Checks..."
RESULT=$(curl -s "http://${ALB_DNS}/api/social-graph/relationship/check?followerId=1&targetId=913" | jq '.isFollowing')
echo "  User 1 follows 913: $RESULT"
echo ""

# Test 6: Response Times
echo "6. Response Time Tests..."
for endpoint in "health" "followers/913/count" "913/followers"; do
  TIME=$(curl -w "%{time_total}" -o /dev/null -s "http://${ALB_DNS}/api/social-graph/$endpoint")
  echo "  $endpoint: ${TIME}s"
done
echo ""

echo "========================================="
echo "Validation Complete!"
echo "========================================="
```

---

## 🚀 Quick Commands

```bash
# Set ALB DNS (replace with actual DNS)
export ALB_DNS="cs6650-project-dev-alb-315577819.us-west-2.elb.amazonaws.com"

# Quick health check
curl http://$ALB_DNS/api/social-graph/health | jq

# Get top user stats
curl http://$ALB_DNS/api/social-graph/followers/913/count | jq

# Get first page of followers
curl http://$ALB_DNS/api/social-graph/913/followers | jq

# Check random relationships
curl "http://$ALB_DNS/api/social-graph/relationship/check?followerId=1&targetId=913" | jq
```

## 📝 PowerShell Equivalents

```powershell
# Set ALB DNS
$ALB_DNS = "cs6650-project-dev-alb-315577819.us-west-2.elb.amazonaws.com"

# Health check
Invoke-RestMethod "http://$ALB_DNS/api/social-graph/health"

# Get follower count
(Invoke-RestMethod "http://$ALB_DNS/api/social-graph/followers/913/count").followerCount

# Get followers list
$followers = Invoke-RestMethod "http://$ALB_DNS/api/social-graph/913/followers"
$followers.followers.Count

# Check relationship
$check = Invoke-RestMethod "http://$ALB_DNS/api/social-graph/relationship/check?followerId=1&targetId=913"
$check.isFollowing
```
