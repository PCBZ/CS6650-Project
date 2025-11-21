#!/usr/bin/env python3
"""Locust task set that repeatedly fetches /api/timeline for a single user.

This version expects the target user ID (and optional label) to be supplied
via command-line arguments passed to Locust after `--`, e.g.

    locust ... -- --target-user-id 12345 --target-user eq10
"""

import logging
from locust import HttpUser, task, between, events
import sys

LOG = logging.getLogger("locust_one_user")


def _register_parser_args(parser):
    parser.add_argument(
        "--target-user-id",
        type=int,
        required=True,
        help="User ID whose timeline will be fetched by each Locust user",
    )


if not getattr(sys.modules[__name__], "_timeline_parser_registered", False):
    events.init_command_line_parser.add_listener(_register_parser_args)
    sys.modules[__name__]._timeline_parser_registered = True


class TimelineUser(HttpUser):
    """Locust user that repeatedly requests the timeline for a single user.

    on_start: selects target user, seeds posts for that user's followings
    using `sfs.seed_for_target`, then the Locust task repeatedly calls the
    timeline endpoint for that user.
    """

    wait_time = between(1, 3)

    def on_start(self):
        opts = self.environment.parsed_options
        self.target_uid = opts.target_user_id
        LOG.info("Timeline user targeting user_id=%s", self.target_uid)

    @task
    def get_timeline(self):
        # Use path parameter - route is /api/timeline/:user_id
        url = f"/api/timeline/{self.target_uid}"
        with self.client.get(url, name="/api/timeline", timeout=30, catch_response=True) as r:
            # Check for 200; mark failures for Locust reporting
            if r.status_code != 200:
                error_body = r.text
                error_msg = error_body.strip() or f"HTTP {r.status_code}"
                try:
                    error_data = r.json()
                    if isinstance(error_data, dict) and "error" in error_data:
                        error_msg = error_data["error"]
                except Exception:
                    # response is not JSON; keep raw body
                    pass
                final_msg = f"Timeline error (status {r.status_code}): {error_msg}"
                r.failure(final_msg)
                LOG.error(f"Timeline request failed for user {self.target_uid}: {final_msg}")
            else:
                r.success()
