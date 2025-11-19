#!/usr/bin/env python3
"""
Seed posts script

This script performs the pre-test operation:
1. Scans the `following` DynamoDB table
2. Selects three users:
    - user with the max number of followings
    - a user with exactly 10 followings (or nearest to 10)
    - a medium-following user (100-500) or the median
3. For each selected user, fetches their `following` list and has each following user
    create 10 posts by calling POST {alb_url}/api/posts

Usage:
     python3 seed_followings_posts.py \
          --region us-west-2 \
          --following-table social-graph-following \
          [--limit-followings 1000] [--workers 20] [--force]

Notes:
- The script will try (in order) to obtain the ALB URL from:
  1) ALB_URL or BASE_URL environment variables
  2) Terraform output `alb_dns_name` (searches for a `terraform` dir up the tree)
- This can create many posts. Use --limit-followings to cap how many followings to process per target.
- Requires AWS credentials available to boto3 (env or IAM role).
"""

import logging
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Tuple, Optional

import boto3
import requests
import os
import subprocess
from typing import Optional
import matplotlib.pyplot as plt
import numpy as np


def plot_following_distribution(items: List[dict], out_path: str = "following_distribution.png") -> Optional[str]:
    """Create and save a histogram of following counts. Returns path on success or None."""
    counts = []
    for it in items:
        following = it.get("following_ids", []) or []
        if isinstance(following, dict):
            # unexpected structure
            continue
        counts.append(len(following))

    if not counts:
        logger.info("No following counts to plot")
        return None

    plt.figure(figsize=(10, 6))
    # Use log scale for y to show long tail
    plt.hist(counts, bins=50, log=True, color="#2c7fb8", edgecolor="black")
    plt.xlabel("Number of followings")
    plt.ylabel("Number of users (log scale)")
    plt.title("Distribution of following counts")
    plt.grid(axis='y', alpha=0.6)
    plt.tight_layout()
    try:
        plt.savefig(out_path)
        logger.info(f"Saved following distribution plot to: {out_path}")
        plt.close()
        return out_path
    except Exception as e:
        logger.warning(f"Failed to save plot: {e}")
        return None


def get_alb_url_from_terraform() -> Optional[str]:
    """Search up the directory tree for a `terraform` directory and run
    `terraform output -raw alb_dns_name`. Returns full http:// URL or None.
    """
    cur = os.path.dirname(os.path.abspath(__file__))
    for _ in range(6):
        terraform_dir = os.path.join(cur, 'terraform')
        if os.path.isdir(terraform_dir):
            try:
                result = subprocess.run(
                    ['terraform', 'output', '-raw', 'alb_dns_name'],
                    cwd=terraform_dir,
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                if result.returncode == 0 and result.stdout.strip():
                    alb_dns = result.stdout.strip()
                    return f"http://{alb_dns}"
            except Exception:
                return None
        parent = os.path.dirname(cur)
        if parent == cur:
            break
        cur = parent
    return None


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("seed_followings_posts")

# Configuration - hardcoded in source as requested
# (LIMIT_FOLLOWINGS, WORKERS and FORCE were removed per request)


def scan_table(table) -> List[dict]:
    items = []
    resp = table.scan()
    items.extend(resp.get("Items", []))
    while "LastEvaluatedKey" in resp:
        resp = table.scan(ExclusiveStartKey=resp["LastEvaluatedKey"])
        items.extend(resp.get("Items", []))
    return items


def select_target_users() -> Tuple[int, int, int]:
    """Scan the following table and select three target users.

    This function now performs its own DynamoDB scan (no arguments required)
    and returns (max_user, user_eq_10, user_medium, items).
    """
    # Ensure ALB / base url is present (keeps behavior consistent with main)
    base_url = get_alb_url_from_terraform()
    if not base_url:
        raise RuntimeError("ALB URL could not be found from Terraform output or ALB_URL env var")

    dynamodb = boto3.resource("dynamodb", region_name="us-west-2")
    table = dynamodb.Table("social-graph-following")

    items = scan_table(table)

    user_following_counts = []  # (user_id, following_count)
    for it in items:
        uid_raw = it.get("user_id")
        try:
            uid = int(uid_raw)
        except Exception:
            # try stringified digits
            try:
                uid = int(str(uid_raw))
            except Exception:
                continue
        following = it.get("following_ids", []) or []
        # ensure list-like
        if isinstance(following, dict):
            following = []
        user_following_counts.append((uid, len(following)))

    if not user_following_counts:
        raise RuntimeError("No items found in following table")

    user_following_counts.sort(key=lambda x: x[1], reverse=True)

    max_user, max_count = user_following_counts[0]

    # find eq10
    user_eq_10 = None
    for uid, cnt in reversed(user_following_counts):
        if cnt == 10:
            user_eq_10 = uid
            user_eq_10_count = cnt
            break
    if user_eq_10 is None:
        user_eq_10 = min(user_following_counts, key=lambda x: abs(x[1] - 10))[0]
        user_eq_10_count = next(cnt for uid, cnt in user_following_counts if uid == user_eq_10)

    # find medium 100-500
    user_medium = None
    for uid, cnt in user_following_counts:
        if 100 <= cnt <= 500:
            user_medium = uid
            user_medium_count = cnt
            break
    if user_medium is None:
        mid_idx = len(user_following_counts) // 2
        user_medium = user_following_counts[mid_idx][0]
        user_medium_count = user_following_counts[mid_idx][1]

    print(f"Selected users: max_user={max_user} ({max_count} followings), user_eq_10={user_eq_10} ({user_eq_10_count} followings), user_medium={user_medium} ({user_medium_count} followings)")
    return max_user, user_eq_10, user_medium


def fetch_following_ids(table, user_id: int) -> List[int]:
    # DynamoDB key may be stored as string; try both
    for key in (str(user_id), user_id):
        try:
            resp = table.get_item(Key={"user_id": key})
            item = resp.get("Item")
            if not item:
                continue
            following = item.get("following_ids", []) or []
            res = []
            for fid in following:
                try:
                    res.append(int(fid))
                except Exception:
                    # skip unparsable
                    continue
            return res
        except Exception:
            continue
    return []


def trim_following_to_limit(table, user_id: int, limit: int = 10) -> Tuple[bool, int]:
    """If the user's following list has more than `limit` entries, truncate it to `limit` and write back to DynamoDB.

    Returns (changed, new_length)
    """
    # Try to fetch item with string key then numeric key
    for key in (str(user_id), user_id):
        try:
            resp = table.get_item(Key={"user_id": key})
            item = resp.get("Item")
            if not item:
                continue

            # Determine attribute name used for followings
            if 'following' in item and isinstance(item['following'], list):
                attr = 'following'
            elif 'following_ids' in item and isinstance(item['following_ids'], list):
                attr = 'following_ids'
            else:
                # nothing to trim
                return False, 0

            current = item.get(attr, []) or []
            if len(current) <= limit:
                return False, len(current)

            new_list = current[:limit]
            # Write back using UpdateExpression
            table.update_item(
                Key={"user_id": key},
                UpdateExpression=f"SET {attr} = :vals",
                ExpressionAttributeValues={':vals': new_list}
            )
            logger.info(f"Trimmed user {user_id} {attr} from {len(current)} -> {len(new_list)}")
            return True, len(new_list)
        except Exception as e:
            logger.debug(f"trim_following_to_limit: get/update attempt for key={key} failed: {e}")
            continue

    return False, 0


def prepare_three_targets(region: str = "us-west-2", following_table_name: str = "social-graph-following") -> Tuple[int, int, int]:
    """Scan following table, plot distribution, select three target users and trim them.

    Returns (table, base_url, max_user, user_eq_10, user_medium)
    """
    base_url = get_alb_url_from_terraform()
    if not base_url:
        raise RuntimeError("ALB URL could not be found from Terraform output or ALB_URL env var")

    dynamodb = boto3.resource("dynamodb", region_name=region)
    table = dynamodb.Table(following_table_name)

    logger.info("Scanning following table (this may take a while)...")
    # select_target_users will perform its own scan and return items
    max_user, user_eq_10, user_medium, items = select_target_users(region, following_table_name)
    logger.info(f"Selected users: max={max_user}, eq10={user_eq_10}, medium={user_medium}")

    # Trim eq10 to 10 and medium to 100
    changed, new_len = trim_following_to_limit(table, user_eq_10, limit=10)
    if changed:
        logger.info(f"Trimmed user_eq_10 ({user_eq_10}) followings down to {new_len}")
        time.sleep(0.5)

    changed_mid, new_len_mid = trim_following_to_limit(table, user_medium, limit=100)
    if changed_mid:
        logger.info(f"Trimmed user_medium ({user_medium}) followings down to {new_len_mid}")
        time.sleep(0.5)

    return max_user, user_eq_10, user_medium


def post_for_user(session: requests.Session, base_url: str, user_id: int, posts_per_user: int = 10) -> int:
    """Create posts_per_user posts for user_id. Returns number of successful posts."""
    success = 0
    for i in range(posts_per_user):
        payload = {"user_id": user_id, "content": f"Auto-seed post {i+1} from user {user_id}"}
        try:
            r = session.post(f"{base_url.rstrip('/')}/api/posts", json=payload, timeout=10)
            if r.status_code == 200:
                success += 1
            else:
                logger.debug(f"Post by {user_id} returned {r.status_code}")
        except Exception as e:
            logger.debug(f"HTTP error posting for {user_id}: {e}")
    return success


def seed_for_target(table, base_url: str, target_uid: int, workers: int) -> Tuple[int, int, int]:
    """For a given target user, fetch followings and have each following create posts.
    Returns (target_uid, total_followings_processed, total_successful_posts)
    """
    following_ids = fetch_following_ids(table, target_uid)
    total_followings = len(following_ids)

    logger.info(f"Target {target_uid}: processing {len(following_ids)} followings (total in table: {total_followings})")

    session = requests.Session()
    total_success = 0

    # Use threadpool to parallelize per-following posting jobs
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futures = {ex.submit(post_for_user, session, base_url, fid, 10): fid for fid in following_ids}
        for fut in as_completed(futures):
            fid = futures[fut]
            try:
                ok = fut.result()
                total_success += ok
            except Exception as e:
                logger.debug(f"Error seeding for following {fid}: {e}")

    return target_uid, len(following_ids), total_success


def main():
    # Configuration comes from module-level constants
    # Always read ALB URL from Terraform output
    base_url = get_alb_url_from_terraform()
    if not base_url:
        logger.error("ALB URL could not be found from Terraform output (alb_dns_name). Ensure Terraform output exists or run terraform in a parent directory.")
        return 2

    region = "us-west-2"
    following_table_name = "social-graph-following"

    logger.info(f"Using ALB URL: {base_url}")
    logger.info(f"Region: {region}")
    logger.info(f"Following table: {following_table_name}")

    dynamodb = boto3.resource("dynamodb", region_name=region)
    table = dynamodb.Table(following_table_name)

    logger.info("Scanning following table (this may take a while)...")
    # select_target_users will perform its own scan and return items
    max_user, user_eq_10, user_medium, items = select_target_users(region, following_table_name)
    logger.info(f"Selected users: max={max_user}, eq10={user_eq_10}, medium={user_medium}")

    # Draw and save following distribution plot (items returned from select_target_users)
    try:
        plot_path = plot_following_distribution(items)
        if plot_path:
            logger.info(f"Distribution plot created: {plot_path}")
    except Exception as e:
        logger.debug(f"Plotting failed: {e}")

    # Safety check
    # Ensure user_eq_10 has at most 10 followings in the DB; if not, trim it.
    try:
        changed, new_len = trim_following_to_limit(table, user_eq_10, limit=10)
        if changed:
            logger.info(f"Trimmed user_eq_10 ({user_eq_10}) followings down to {new_len}")
            # allow small pause for DynamoDB eventual consistency
            time.sleep(0.5)
    except Exception as e:
        logger.warning(f"Failed to trim followings for {user_eq_10}: {e}")

    # Ensure user_medium has at most 100 followings; trim if necessary
    try:
        changed_mid, new_len_mid = trim_following_to_limit(table, user_medium, limit=100)
        if changed_mid:
            logger.info(f"Trimmed user_medium ({user_medium}) followings down to {new_len_mid}")
            time.sleep(0.5)
    except Exception as e:
        logger.warning(f"Failed to trim followings for medium user {user_medium}: {e}")

    total_followings = 0
    for uid in (max_user, user_eq_10, user_medium):
        fids = fetch_following_ids(table, uid)
        total_followings += len(fids)

    estimated_posts = total_followings * 10
    logger.info(f"Estimated total posts to create (all followings x10): {estimated_posts}")
    # Default behavior: do not proceed automatically for very large jobs
    if estimated_posts > 100000:
        logger.warning("This job would create more than 10k posts. Edit the script to change the limit or scope if you really want to proceed.")
        return 3

    # Seed for each target
    results = []
    start = time.time()
    for uid in (max_user, user_eq_10, user_medium):
        # Inline defaults: no cap on followings, 20 workers
        res = seed_for_target(table, base_url, uid, 20)
        results.append(res)

    duration = time.time() - start

    logger.info("Seeding summary:")
    for target_uid, processed, successes in results:
        logger.info(f"Target {target_uid}: processed followings={processed}, successful_posts={successes}")

    logger.info(f"Total time: {duration:.1f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
