#!/usr/bin/env python3
"""
Locust test that seeds posts for a single selected user (using
functions from `seed_followings_posts.py`) and then only runs timeline
retrieval for that user.

Run with:
  locust -f tests/timeline_retrieval/locust_one_user.py

By default this will pick the user nearest to 10 followings (the "eq10"
target). Override the target via the environment variable
`TARGET_USER` with values `eq10`, `medium`, or `max`.
"""

import os
import logging
from locust import HttpUser, task, between

# Import helper functions from the seeding script
# Use relative import when running from the same directory
try:
    from . import seed_followings_posts as sfs
except ImportError:
    # Fallback for when running as a script
    import sys
    import os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))
    from tests.timeline_retrieval import seed_followings_posts as sfs

LOG = logging.getLogger("locust_one_user")


class TimelineUser(HttpUser):
    """Locust user that repeatedly requests the timeline for a single user.

    on_start: selects target user, seeds posts for that user's followings
    using `sfs.seed_for_target`, then the Locust task repeatedly calls the
    timeline endpoint for that user.
    """

    wait_time = between(1, 3)

    def on_start(self):
        max_user, user_eq_10, user_medium = sfs.select_target_users()
        
        # Select target user based on TARGET_USER environment variable
        target = os.environ.get("TARGET_USER", "eq10").lower()
        if target == "max":
            self.target_uid = max_user
            LOG.info(f"Selected target user: {max_user} (max followings)")
        elif target == "medium":
            self.target_uid = user_medium
            LOG.info(f"Selected target user: {user_medium} (medium followings)")
        else:  # default to eq10
            self.target_uid = user_eq_10
            LOG.info(f"Selected target user: {user_eq_10} (eq10 followings)")

    @task
    def get_timeline(self):
        # Use path parameter - route is /api/timeline/:user_id
        url = f"/api/timeline/{self.target_uid}"
        with self.client.get(url, name="/api/timeline", timeout=10, catch_response=True) as r:
            # Check for 200; mark failures for Locust reporting
            if r.status_code != 200:
                error_msg = f"Status {r.status_code}"
                try:
                    error_data = r.json()
                    if "error" in error_data:
                        error_msg = f"Status {r.status_code}: {error_data['error']}"
                except:
                    pass
                r.failure(error_msg)
                LOG.error(f"Timeline request failed for user {self.target_uid}: {error_msg}")
            else:
                r.success()
