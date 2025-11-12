#!/usr/bin/env python3
"""
Locust Performance Test for Push Fan-out Model

Tests three user scales: 5K, 25K, 100K users
User Distribution:
- Regular Users (85%): 10-100 followers, 50-200 following
- Influencers (14%): 100-50,000 followers, 100-500 following
- Celebrities (1%): 50,000-500,000 followers, 50-200 following

Key Metrics:
- Write latency (post creation time)
- Read latency (timeline retrieval)
- Storage requirements
- System throughput
"""

import random
import time
import json
import os
import subprocess
from typing import Dict, List, Tuple, Optional
from locust import HttpUser, task, between, events
from locust.runners import MasterRunner, WorkerRunner
import logging
import boto3
from collections import defaultdict

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================================================
# Configuration
# ============================================================================

def get_alb_url_from_terraform():
    """
    Get ALB URL from Terraform output or environment variable
    
    Priority:
    1. Environment variable ALB_URL
    2. Terraform output (terraform output -raw alb_dns_name)
    3. Fallback to hardcoded URL
    """
    # Try environment variable first
    alb_url = os.environ.get('ALB_URL')
    if alb_url:
        logger.info(f"Using ALB URL from environment variable: {alb_url}")
        return alb_url
    
    # Try Terraform output
    try:
        # Get the project root (parent of tests directory)
        current_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(current_dir)
        terraform_dir = os.path.join(project_root, 'terraform')
        
        if os.path.exists(terraform_dir):
            logger.info("Reading ALB URL from Terraform output...")
            result = subprocess.run(
                ['terraform', 'output', '-raw', 'alb_dns_name'],
                cwd=terraform_dir,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0 and result.stdout.strip():
                alb_dns = result.stdout.strip()
                alb_url = f"http://{alb_dns}"
                logger.info(f"✅ ALB URL from Terraform: {alb_url}")
                return alb_url
            else:
                logger.warning(f"Failed to get Terraform output: {result.stderr}")
    except Exception as e:
        logger.warning(f"Failed to read Terraform output: {e}")
    
    # Fallback to hardcoded URL
    fallback_url = "http://cs6650-project-dev-alb-2009030594.us-west-2.elb.amazonaws.com"
    logger.warning(f"⚠️  Using fallback ALB URL: {fallback_url}")
    logger.warning("To use dynamic URL, set ALB_URL environment variable or ensure Terraform is configured")
    return fallback_url

class TestConfig:
    """Test configuration for different user scales"""
    
    # ALB endpoint (dynamically loaded from Terraform or environment)
    BASE_URL = get_alb_url_from_terraform()
    
    # AWS Configuration
    AWS_REGION = "us-west-2"
    FOLLOWERS_TABLE = "social-graph-followers"
    FOLLOWING_TABLE = "social-graph-following"
    
    # User scale configurations
    SCALES = {
        "5K": 5000,
        "25K": 25000,
        "100K": 100000
    }
    
    # Current test scale (change this to switch between scales)
    CURRENT_SCALE = "5K"  # Options: "5K", "25K", "100K"
    
    # Follower count thresholds for classification
    # These are flexible and will adapt to actual data
    REGULAR_FOLLOWER_THRESHOLD = 100      # < 100 followers = Regular
    INFLUENCER_FOLLOWER_THRESHOLD = 10000  # 100-10K followers = Influencer
    # >= 10K followers = Celebrity
    
    # Test behavior weights
    READ_WEIGHT = 9   # 90% reads
    WRITE_WEIGHT = 1  # 10% writes
    
    # Timeline retrieval limit
    TIMELINE_LIMIT = 20
    
    # Cache settings
    CACHE_USERS = True  # Cache user classification to avoid repeated DynamoDB scans
    
    @classmethod
    def get_total_users(cls) -> int:
        """Get total users for current scale"""
        return cls.SCALES.get(cls.CURRENT_SCALE, 5000)


# ============================================================================
# DynamoDB User Loader
# ============================================================================

class DynamoDBUserLoader:
    """Loads users from DynamoDB and classifies them by follower count"""
    
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb', region_name=TestConfig.AWS_REGION)
        self.followers_table = self.dynamodb.Table(TestConfig.FOLLOWERS_TABLE)
        
        # User classification storage
        self.users_by_type: Dict[str, List[int]] = {
            "regular": [],
            "influencer": [],
            "celebrity": []
        }
        self.user_follower_counts: Dict[int, int] = {}
        self.loaded = False
    
    def load_users(self):
        """Load all users from DynamoDB and classify them"""
        if self.loaded:
            logger.info("Users already loaded from cache")
            return
        
        logger.info("=" * 80)
        logger.info("Loading users from DynamoDB...")
        logger.info(f"Table: {TestConfig.FOLLOWERS_TABLE}")
        logger.info(f"Region: {TestConfig.AWS_REGION}")
        
        try:
            # Scan the followers table
            response = self.followers_table.scan()
            items = response.get('Items', [])
            
            # Handle pagination
            while 'LastEvaluatedKey' in response:
                response = self.followers_table.scan(
                    ExclusiveStartKey=response['LastEvaluatedKey']
                )
                items.extend(response.get('Items', []))
            
            logger.info(f"✅ Loaded {len(items):,} users from DynamoDB")
            
            # Classify users by follower count
            for item in items:
                user_id = int(item['user_id'])
                followers = item.get('followers', [])
                follower_count = len(followers)
                
                self.user_follower_counts[user_id] = follower_count
                
                # Classify user
                if follower_count < TestConfig.REGULAR_FOLLOWER_THRESHOLD:
                    user_type = "regular"
                elif follower_count < TestConfig.INFLUENCER_FOLLOWER_THRESHOLD:
                    user_type = "influencer"
                else:
                    user_type = "celebrity"
                
                self.users_by_type[user_type].append(user_id)
            
            self.loaded = True
            
            # Print classification summary
            total_users = len(self.user_follower_counts)
            logger.info("\n" + "=" * 80)
            logger.info("USER CLASSIFICATION SUMMARY")
            logger.info("=" * 80)
            
            for user_type in ["regular", "influencer", "celebrity"]:
                count = len(self.users_by_type[user_type])
                percentage = (count / total_users * 100) if total_users > 0 else 0
                
                if count > 0:
                    follower_counts = [
                        self.user_follower_counts[uid] 
                        for uid in self.users_by_type[user_type]
                    ]
                    min_followers = min(follower_counts)
                    max_followers = max(follower_counts)
                    avg_followers = sum(follower_counts) / len(follower_counts)
                    
                    logger.info(f"\n🏷️  {user_type.upper()}")
                    logger.info(f"   Count: {count:,} users ({percentage:.1f}%)")
                    logger.info(f"   Followers: min={min_followers:,}, max={max_followers:,}, avg={avg_followers:.1f}")
                    logger.info(f"   Sample IDs: {sorted(self.users_by_type[user_type])[:5]}")
            
            logger.info("\n" + "=" * 80)
            
        except Exception as e:
            logger.error(f"❌ Failed to load users from DynamoDB: {e}")
            logger.error("Falling back to ID-based selection (1 to expected user count)")
            
            # Fallback: generate user IDs based on expected distribution
            total = TestConfig.get_total_users()
            for user_id in range(1, total + 1):
                # Simple classification based on ID position
                if user_id <= int(total * 0.85):
                    self.users_by_type["regular"].append(user_id)
                    self.user_follower_counts[user_id] = 50
                elif user_id <= int(total * 0.99):
                    self.users_by_type["influencer"].append(user_id)
                    self.user_follower_counts[user_id] = 500
                else:
                    self.users_by_type["celebrity"].append(user_id)
                    self.user_follower_counts[user_id] = 5000
            
            self.loaded = True
    
    def get_random_user(self) -> Tuple[int, str]:
        """
        Get a random user ID and their type based on actual distribution
        
        Returns:
            (user_id, user_type)
        """
        if not self.loaded:
            self.load_users()
        
        # Randomly select a user type based on actual distribution
        total_users = sum(len(users) for users in self.users_by_type.values())
        
        if total_users == 0:
            logger.error("No users available!")
            return 1, "regular"
        
        # Calculate probabilities based on actual user counts
        probabilities = {
            user_type: len(users) / total_users
            for user_type, users in self.users_by_type.items()
            if len(users) > 0
        }
        
        # Random selection
        rand = random.random()
        cumulative = 0.0
        
        for user_type, prob in probabilities.items():
            cumulative += prob
            if rand < cumulative:
                if len(self.users_by_type[user_type]) > 0:
                    user_id = random.choice(self.users_by_type[user_type])
                    return user_id, user_type
        
        # Fallback to regular user
        if len(self.users_by_type["regular"]) > 0:
            return random.choice(self.users_by_type["regular"]), "regular"
        
        # Last resort
        return 1, "regular"
    
    def get_user_type(self, user_id: int) -> str:
        """Get user type for a specific user ID"""
        if not self.loaded:
            self.load_users()
        
        for user_type, users in self.users_by_type.items():
            if user_id in users:
                return user_type
        
        return "regular"  # Default
    
    def get_follower_count(self, user_id: int) -> int:
        """Get follower count for a user"""
        return self.user_follower_counts.get(user_id, 0)


# Global user loader (shared across all Locust users)
user_loader = DynamoDBUserLoader()


# ============================================================================
# Metrics Collector
# ============================================================================

class MetricsCollector:
    """Collects and aggregates performance metrics"""
    
    def __init__(self):
        self.write_latencies = []
        self.read_latencies = []
        self.write_count = 0
        self.read_count = 0
        self.error_count = 0
        
        # Timing for throughput calculation
        self.start_time = None
        self.end_time = None
        
        # Per user-type metrics
        self.user_type_metrics = {
            "regular": {"writes": [], "reads": []},
            "influencer": {"writes": [], "reads": []},
            "celebrity": {"writes": [], "reads": []}
        }
    
    def record_write(self, latency: float, user_type: str):
        """Record write operation latency"""
        self.write_latencies.append(latency)
        self.write_count += 1
        self.user_type_metrics[user_type]["writes"].append(latency)
    
    def record_read(self, latency: float, user_type: str):
        """Record read operation latency"""
        self.read_latencies.append(latency)
        self.read_count += 1
        self.user_type_metrics[user_type]["reads"].append(latency)
    
    def record_error(self):
        """Record error"""
        self.error_count += 1
    
    def get_summary(self) -> Dict:
        """Get metrics summary"""
        def percentile(data: List[float], p: float) -> float:
            if not data:
                return 0.0
            sorted_data = sorted(data)
            index = int(len(sorted_data) * p)
            return sorted_data[min(index, len(sorted_data) - 1)]
        
        # Calculate throughput (RPS)
        total_requests = self.write_count + self.read_count
        duration = 0
        rps = 0
        write_rps = 0
        read_rps = 0
        
        if self.start_time and self.end_time:
            duration = self.end_time - self.start_time
            if duration > 0:
                rps = total_requests / duration
                write_rps = self.write_count / duration
                read_rps = self.read_count / duration
        
        summary = {
            "scale": TestConfig.CURRENT_SCALE,
            "total_users": TestConfig.get_total_users(),
            "total_requests": total_requests,
            "write_count": self.write_count,
            "read_count": self.read_count,
            "error_count": self.error_count,
            "duration_seconds": duration,
            "throughput": {
                "total_rps": rps,
                "write_rps": write_rps,
                "read_rps": read_rps
            },
            "write_latency": {
                "avg": sum(self.write_latencies) / len(self.write_latencies) if self.write_latencies else 0,
                "p50": percentile(self.write_latencies, 0.5),
                "p95": percentile(self.write_latencies, 0.95),
                "p99": percentile(self.write_latencies, 0.99),
                "max": max(self.write_latencies) if self.write_latencies else 0
            },
            "read_latency": {
                "avg": sum(self.read_latencies) / len(self.read_latencies) if self.read_latencies else 0,
                "p50": percentile(self.read_latencies, 0.5),
                "p95": percentile(self.read_latencies, 0.95),
                "p99": percentile(self.read_latencies, 0.99),
                "max": max(self.read_latencies) if self.read_latencies else 0
            }
        }
        
        # Add per user-type metrics
        for user_type in ["regular", "influencer", "celebrity"]:
            writes = self.user_type_metrics[user_type]["writes"]
            reads = self.user_type_metrics[user_type]["reads"]
            
            summary[f"{user_type}_metrics"] = {
                "write_count": len(writes),
                "read_count": len(reads),
                "avg_write_latency": sum(writes) / len(writes) if writes else 0,
                "avg_read_latency": sum(reads) / len(reads) if reads else 0
            }
        
        return summary


# Global metrics collector
metrics_collector = MetricsCollector()


# ============================================================================
# Locust Events
# ============================================================================

@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when test starts"""
    logger.info("=" * 80)
    logger.info(f"Starting Push Fan-out Performance Test")
    logger.info(f"Scale: {TestConfig.CURRENT_SCALE} users ({TestConfig.get_total_users():,})")
    logger.info(f"Strategy: Push Fan-out Model")
    logger.info("=" * 80)
    
    # Record start time for throughput calculation
    metrics_collector.start_time = time.time()
    
    # Load users from DynamoDB
    logger.info("\nLoading users from DynamoDB...")
    user_loader.load_users()


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when test stops - print summary"""
    # Record end time for throughput calculation
    metrics_collector.end_time = time.time()
    
    logger.info("=" * 80)
    logger.info("Test Complete - Performance Summary")
    logger.info("=" * 80)
    
    summary = metrics_collector.get_summary()
    
    logger.info(f"\n📊 Overall Metrics:")
    logger.info(f"  Scale: {summary['scale']} ({summary['total_users']:,} users)")
    logger.info(f"  Duration: {summary['duration_seconds']:.2f} seconds")
    logger.info(f"  Total Requests: {summary['total_requests']:,}")
    logger.info(f"  Writes: {summary['write_count']:,}")
    logger.info(f"  Reads: {summary['read_count']:,}")
    logger.info(f"  Errors: {summary['error_count']:,}")
    
    logger.info(f"\n🚀 Throughput (RPS - Requests Per Second):")
    logger.info(f"  Total RPS: {summary['throughput']['total_rps']:.2f}")
    logger.info(f"  Write RPS: {summary['throughput']['write_rps']:.2f}")
    logger.info(f"  Read RPS: {summary['throughput']['read_rps']:.2f}")
    
    logger.info(f"\n✍️  Write Latency (Post Creation):")
    logger.info(f"  Average: {summary['write_latency']['avg']:.2f} ms")
    logger.info(f"  P50: {summary['write_latency']['p50']:.2f} ms")
    logger.info(f"  P95: {summary['write_latency']['p95']:.2f} ms")
    logger.info(f"  P99: {summary['write_latency']['p99']:.2f} ms")
    logger.info(f"  Max: {summary['write_latency']['max']:.2f} ms")
    
    logger.info(f"\n📖 Read Latency (Timeline Retrieval):")
    logger.info(f"  Average: {summary['read_latency']['avg']:.2f} ms")
    logger.info(f"  P50: {summary['read_latency']['p50']:.2f} ms")
    logger.info(f"  P95: {summary['read_latency']['p95']:.2f} ms")
    logger.info(f"  P99: {summary['read_latency']['p99']:.2f} ms")
    logger.info(f"  Max: {summary['read_latency']['max']:.2f} ms")
    
    logger.info(f"\n👥 Per User-Type Metrics:")
    for user_type in ["regular", "influencer", "celebrity"]:
        metrics = summary[f"{user_type}_metrics"]
        logger.info(f"  {user_type.capitalize()}:")
        logger.info(f"    Writes: {metrics['write_count']:,} (avg: {metrics['avg_write_latency']:.2f} ms)")
        logger.info(f"    Reads: {metrics['read_count']:,} (avg: {metrics['avg_read_latency']:.2f} ms)")
    
    # Save to JSON file
    output_file = f"push_fanout_results_{TestConfig.CURRENT_SCALE}.json"
    with open(output_file, 'w') as f:
        json.dump(summary, f, indent=2)
    logger.info(f"\n💾 Results saved to: {output_file}")
    logger.info("=" * 80)


# ============================================================================
# Locust User Class
# ============================================================================

class TimelineUser(HttpUser):
    """
    Simulates a user interacting with the timeline system
    
    Behavior:
    - 90% timeline reads (GET /api/timeline)
    - 10% post creation (POST /api/posts)
    """
    
    host = TestConfig.BASE_URL
    wait_time = between(1, 3)  # Wait 1-3 seconds between tasks
    
    def on_start(self):
        """Called when a simulated user starts"""
        # Get a random user from DynamoDB-loaded users
        self.user_id, self.user_type = user_loader.get_random_user()
        self.follower_count = user_loader.get_follower_count(self.user_id)
        logger.info(f"User {self.user_id} ({self.user_type}, {self.follower_count} followers) started")
    
    @task(TestConfig.READ_WEIGHT)
    def read_timeline(self):
        """
        Read timeline operation (90% of traffic)
        
        Metrics:
        - Read latency
        - Timeline retrieval time
        """
        start_time = time.time()
        
        with self.client.get(
            f"/api/timeline/{self.user_id}",
            params={"limit": TestConfig.TIMELINE_LIMIT},
            catch_response=True,
            name="GET /api/timeline"
        ) as response:
            latency = (time.time() - start_time) * 1000  # Convert to ms
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    timeline = data.get("timeline", [])
                    total_count = data.get("total_count", 0)
                    
                    # Record metrics
                    metrics_collector.record_read(latency, self.user_type)
                    
                    response.success()
                    logger.debug(f"User {self.user_id} ({self.user_type}) read timeline: "
                               f"{len(timeline)} posts, latency: {latency:.2f}ms")
                except json.JSONDecodeError:
                    metrics_collector.record_error()
                    response.failure("Invalid JSON response")
            else:
                metrics_collector.record_error()
                response.failure(f"Got status code {response.status_code}")
    
    @task(TestConfig.WRITE_WEIGHT)
    def create_post(self):
        """
        Create post operation (10% of traffic)
        
        Metrics:
        - Write latency
        - Post creation time (includes fan-out to all followers)
        """
        start_time = time.time()
        
        # Generate random post content
        post_content = f"Test post from user {self.user_id} at {int(time.time())}"
        
        payload = {
            "user_id": self.user_id,
            "content": post_content
        }
        
        with self.client.post(
            "/api/posts",
            json=payload,
            catch_response=True,
            name="POST /api/posts"
        ) as response:
            latency = (time.time() - start_time) * 1000  # Convert to ms
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    post = data.get("post", {})
                    post_id = post.get("post_id")
                    
                    # Record metrics
                    metrics_collector.record_write(latency, self.user_type)
                    
                    response.success()
                    logger.debug(f"User {self.user_id} ({self.user_type}) created post {post_id}: "
                               f"latency: {latency:.2f}ms")
                except json.JSONDecodeError:
                    metrics_collector.record_error()
                    response.failure("Invalid JSON response")
            else:
                metrics_collector.record_error()
                response.failure(f"Got status code {response.status_code}")


# ============================================================================
# Additional User Classes for Different Behaviors
# ============================================================================

class RegularUser(TimelineUser):
    """Regular user with typical behavior"""
    weight = 85  # 85% of users (approximate, will match actual distribution)
    
    def on_start(self):
        """Override to force selection of regular users only"""
        if len(user_loader.users_by_type["regular"]) > 0:
            self.user_id = random.choice(user_loader.users_by_type["regular"])
            self.user_type = "regular"
            self.follower_count = user_loader.get_follower_count(self.user_id)
            logger.info(f"Regular User {self.user_id} ({self.follower_count} followers) started")
        else:
            # Fallback to parent behavior
            super().on_start()


class InfluencerUser(TimelineUser):
    """Influencer with more followers"""
    weight = 14  # 14% of users (approximate, will match actual distribution)
    
    def on_start(self):
        """Override to force selection of influencer users only"""
        if len(user_loader.users_by_type["influencer"]) > 0:
            self.user_id = random.choice(user_loader.users_by_type["influencer"])
            self.user_type = "influencer"
            self.follower_count = user_loader.get_follower_count(self.user_id)
            logger.info(f"Influencer User {self.user_id} ({self.follower_count} followers) started")
        else:
            # Fallback to parent behavior
            super().on_start()


class CelebrityUser(TimelineUser):
    """Celebrity with many followers"""
    weight = 1  # 1% of users (approximate, will match actual distribution)
    
    def on_start(self):
        """Override to force selection of celebrity users only"""
        if len(user_loader.users_by_type["celebrity"]) > 0:
            self.user_id = random.choice(user_loader.users_by_type["celebrity"])
            self.user_type = "celebrity"
            self.follower_count = user_loader.get_follower_count(self.user_id)
            logger.info(f"Celebrity User {self.user_id} ({self.follower_count} followers) started")
        else:
            # Fallback to parent behavior
            super().on_start()


# ============================================================================
# Custom Shape for Ramping Load
# ============================================================================

from locust import LoadTestShape

# Commented out to use command-line parameters (--users, --spawn-rate, --run-time)
# Uncomment this class to use the custom staged load pattern
# class StagesShape(LoadTestShape):
#     """
#     Custom load shape with multiple stages
#     
#     Stage 1: Warm-up (0-60s) - Ramp up to 50 users
#     Stage 2: Normal load (60-180s) - Maintain 50 users
#     Stage 3: Peak load (180-300s) - Ramp up to 200 users
#     Stage 4: Sustained peak (300-420s) - Maintain 200 users
#     Stage 5: Cool-down (420-480s) - Ramp down to 50 users
#     """
#     
#     stages = [
#         {"duration": 60, "users": 50, "spawn_rate": 5},      # Warm-up
#         {"duration": 180, "users": 50, "spawn_rate": 5},     # Normal load
#         {"duration": 300, "users": 200, "spawn_rate": 10},   # Peak load
#         {"duration": 420, "users": 200, "spawn_rate": 10},   # Sustained peak
#         {"duration": 480, "users": 50, "spawn_rate": 5},     # Cool-down
#     ]
#     
#     def tick(self):
#         run_time = self.get_run_time()
#         
#         for stage in self.stages:
#             if run_time < stage["duration"]:
#                 return (stage["users"], stage["spawn_rate"])
#         
#         return None  # Test complete


# ============================================================================
# Main Entry Point
# ============================================================================

if __name__ == "__main__":
    """
    Run this test with:
    
    # Single machine
    locust -f locust_push_fanout_test.py --host http://your-alb-url.com
    
    # Distributed mode (master)
    locust -f locust_push_fanout_test.py --master --host http://your-alb-url.com
    
    # Distributed mode (worker)
    locust -f locust_push_fanout_test.py --worker --master-host=<master-ip>
    
    # Headless mode with custom parameters
    locust -f locust_push_fanout_test.py \
        --headless \
        --users 100 \
        --spawn-rate 10 \
        --run-time 5m \
        --host http://your-alb-url.com
    """
    print("=" * 80)
    print("Push Fan-out Performance Test")
    print("=" * 80)
    print(f"Scale: {TestConfig.CURRENT_SCALE} ({TestConfig.get_total_users():,} users)")
    print(f"Host: {TestConfig.BASE_URL}")
    print("")
    print("User Distribution:")
    ranges = TestConfig.get_user_ranges()
    print(f"  Regular Users (85%): IDs {ranges['regular'][0]}-{ranges['regular'][1]}")
    print(f"  Influencers (14%): IDs {ranges['influencer'][0]}-{ranges['influencer'][1]}")
    print(f"  Celebrities (1%): IDs {ranges['celebrity'][0]}-{ranges['celebrity'][1]}")
    print("")
    print("Run with: locust -f locust_push_fanout_test.py")
    print("=" * 80)

