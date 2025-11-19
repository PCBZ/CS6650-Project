
#!/usr/bin/env python3
"""
Simple background traffic for the social graph services.

Behavior:
- Each simulated user picks a random user id (from DynamoDB if available,
  else from a numeric range) and repeatedly performs POST /api/posts and
  GET /api/timeline for that user.
- This test is intended as low-cost background traffic. It does not collect
  or persist any custom metrics beyond what Locust itself reports.

Run:
  locust -f tests/timeline_retrieval/locust_background_traffic.py --host http://your-alb
"""

import os
import random
import time
import logging
from typing import List

from locust import HttpUser, task, between

import boto3

logger = logging.getLogger("locust_background_traffic")
logging.basicConfig(level=logging.INFO)


def get_users_from_dynamodb(region: str = "us-west-2", followers_table: str = "social-graph-followers", sample_limit: int = 1000) -> List[int]:
	"""Try to scan the followers table and return a list of user_ids.
	Falls back to an empty list on any failure.
	"""
	try:
		ddb = boto3.resource("dynamodb", region_name=region)
		table = ddb.Table(followers_table)
		users = []
		resp = table.scan(Limit=sample_limit)
		items = resp.get("Items", [])
		users.extend([int(it["user_id"]) for it in items if "user_id" in it])
		return users
	except Exception as e:
		logger.debug(f"DynamoDB scan failed: {e}")
		return []


class BackgroundUser(HttpUser):
	"""Locust user that generates background post + timeline traffic."""

	wait_time = between(0.5, 2)

	def on_start(self):
		# Try to get candidate user ids from DynamoDB, else use numeric range.
		region = os.environ.get("AWS_REGION", "us-west-2")
		followers_table = os.environ.get("FOLLOWERS_TABLE", "social-graph-followers")
		users = get_users_from_dynamodb(region=region, followers_table=followers_table, sample_limit=2000)
		
		if users:
			self.user_pool = users
		else:
			# Fallback range; configurable via env TOTAL_USERS
			total = int(os.environ.get("TOTAL_USERS", "10000"))
			# sample a subset for better randomness without huge range operations
			self.user_pool = list(range(1, min(total, 100000) + 1))

		# pick current user id for this simulated user
		self.user_id = random.choice(self.user_pool)
		logger.debug(f"BackgroundUser started with user_id={self.user_id}")

	@task(8)
	def read_timeline(self):
		try:
			# GET /api/timeline/:user_id is used elsewhere; include query fallback
			path = f"/api/timeline/{self.user_id}"
			with self.client.get(path, name="GET /api/timeline", timeout=5, catch_response=True) as r:
				# do not process response; let Locust record default metrics
				if r.status_code >= 400:
					r.failure(f"status {r.status_code}")
		except Exception:
			# swallow errors to keep background traffic running
			logger.debug("Exception during read_timeline", exc_info=True)

	@task(2)
	def create_post(self):
		try:
			payload = {"user_id": self.user_id, "content": f"bg post {int(time.time())} from {self.user_id}"}
			with self.client.post("/api/posts", json=payload, name="POST /api/posts", timeout=5, catch_response=True) as r:
				if r.status_code >= 400:
					r.failure(f"status {r.status_code}")
		except Exception:
			logger.debug("Exception during create_post", exc_info=True)

