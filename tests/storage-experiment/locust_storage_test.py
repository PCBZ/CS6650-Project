#!/usr/bin/env python3
"""
Locust Test for Storage Experiment - Post Generation

Simple, focused test for generating posts to measure storage impact.
This test focuses on creating posts efficiently without complex metrics.

Usage:
    locust -f locust_storage_test.py --headless \
        --users 100 --spawn-rate 10 --run-time 10m \
        --host http://your-alb-url.com
"""

import random
import time
import os
from locust import HttpUser, task, between, events
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Read configuration from environment variables
NUM_USERS = int(os.getenv('NUM_USERS', '5000'))
WRITE_RATIO = int(os.getenv('WRITE_RATIO', '100'))

# Global counters
_post_count = 0
_timeline_count = 0


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Log test configuration at start"""
    logger.info("=" * 80)
    logger.info("Storage Experiment - Post Generation Test")
    logger.info("=" * 80)
    logger.info(f"Total users in system: {NUM_USERS:,}")
    logger.info(f"Write ratio: {WRITE_RATIO}%")
    logger.info(f"Read ratio: {100 - WRITE_RATIO}%")
    logger.info("=" * 80)


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Log final statistics"""
    logger.info("=" * 80)
    logger.info("Storage Test Complete")
    logger.info("=" * 80)
    logger.info(f"Posts created: {_post_count:,}")
    logger.info(f"Timeline reads: {_timeline_count:,}")
    logger.info("=" * 80)


class StorageTestUser(HttpUser):
    """
    User that generates posts (writes) and occasionally reads timelines.
    
    The task weights are dynamic based on WRITE_RATIO environment variable.
    """
    
    wait_time = between(0.5, 2)
    
    def on_start(self):
        """Initialize user - select a random user ID from the available range"""
        self.num_users = NUM_USERS
        self.write_ratio = WRITE_RATIO
        self.user_id = random.randint(1, self.num_users)
        logger.debug(f"Locust user started with user_id={self.user_id}")
    
    @task
    def weighted_action(self):
        """
        Perform either write or read based on configured ratio.
        This gives us dynamic task weighting without @task(N) decorators.
        """
        if random.randint(1, 100) <= self.write_ratio:
            self.create_post()
        else:
            self.read_timeline()
    
    def create_post(self):
        """Create a post - this generates storage data"""
        global _post_count
        
        post_content = f"Storage test post from user {self.user_id} at {int(time.time())}"
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
            if response.status_code == 200:
                _post_count += 1
                response.success()
            else:
                response.failure(f"Status {response.status_code}")
    
    def read_timeline(self):
        """Read timeline - minimal reads to verify system works"""
        global _timeline_count
        
        with self.client.get(
            f"/api/timeline/{self.user_id}",
            params={"limit": 10},
            catch_response=True,
            name="GET /api/timeline",
            timeout=10
        ) as response:
            if response.status_code in (200, 504):
                # 504 is expected for pull/hybrid with many followings
                _timeline_count += 1
                response.success()
            else:
                response.failure(f"Status {response.status_code}")


if __name__ == "__main__":
    print("Storage Experiment - Post Generation Test")
    print("")
    print("Configuration via environment variables:")
    print(f"  NUM_USERS={NUM_USERS}")
    print(f"  WRITE_RATIO={WRITE_RATIO}")
    print("")
    print("Run with:")
    print("  export NUM_USERS=5000 WRITE_RATIO=100")
    print("  locust -f locust_storage_test.py --headless \\")
    print("    --users 100 --spawn-rate 10 --run-time 10m \\")
    print("    --host http://your-alb.amazonaws.com")
