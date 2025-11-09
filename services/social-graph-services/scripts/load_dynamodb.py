#!/usr/bin/env python3
"""
Load test data into DynamoDB tables for social-graph-service
Generates relationships using the core generator and uploads to AWS DynamoDB
"""

import sys
import os
import json
import boto3
from typing import Dict, Set
from collections import defaultdict

# Add parent directory to path to import core modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from core.segmenter import UserSegmentation
from core.generator import RelationshipGenerator


def load_to_dynamodb(
    follower_map: Dict[int, Set[int]],
    following_map: Dict[int, Set[int]],
    followers_table_name: str,
    following_table_name: str,
    region: str = "us-west-2"
):
    """
    Load relationship data into DynamoDB tables
    
    Args:
        follower_map: Mapping of user_id -> set of follower IDs
        following_map: Mapping of user_id -> set of following IDs
        followers_table_name: Name of the followers table
        following_table_name: Name of the following table
        region: AWS region
    """
    print(f"\n Loading data to DynamoDB in region {region}...")
    print(f"   Followers table: {followers_table_name}")
    print(f"   Following table: {following_table_name}")
    
    # Initialize DynamoDB client
    dynamodb = boto3.resource('dynamodb', region_name=region)
    followers_table = dynamodb.Table(followers_table_name)
    following_table = dynamodb.Table(following_table_name)
    
    # Batch write to followers table
    print(f"\n Writing to {followers_table_name}...")
    with followers_table.batch_writer() as batch:
        for user_id, followers in follower_map.items():
            if followers:  # Only write if user has followers
                item = {
                    'user_id': str(user_id),
                    'follower_ids': list(map(str, sorted(followers)))
                }
                batch.put_item(Item=item)
    
    print(f" Wrote {len(follower_map)} users to {followers_table_name}")
    
    # Batch write to following table
    print(f"\n Writing to {following_table_name}...")
    with following_table.batch_writer() as batch:
        for user_id, following in following_map.items():
            if following:  # Only write if user is following someone
                item = {
                    'user_id': str(user_id),
                    'following_ids': list(map(str, sorted(following)))
                }
                batch.put_item(Item=item)

    print(f" Wrote {len(following_map)} users to {following_table_name}")


def generate_and_load(
    total_users: int,
    followers_table_name: str = "social-graph-followers",
    following_table_name: str = "social-graph-following",
    region: str = "us-west-2",
    verbose: bool = True
):
    """
    Generate relationships and load them into DynamoDB
    
    Args:
        total_users: Total number of users to generate relationships for
        followers_table_name: Name of the followers DynamoDB table
        following_table_name: Name of the following DynamoDB table
        region: AWS region
        verbose: Print detailed progress
    """
    print(f"\n Generating and loading social graph data for {total_users:,} users")
    print(f"=" * 80)
    
    # Step 1: Segment users
    print("\n Step 1: Segmenting users...")
    user_ids = list(range(1, total_users + 1))
    segmentation = UserSegmentation(total_users)
    segments = segmentation.segment_users(user_ids)
    
    if verbose:
        for segment_name, users in segments.items():
            print(f"  {segment_name.capitalize()}: {len(users):,} users")
    
    # Step 2: Generate relationships
    print("\n Step 2: Generating relationships...")
    generator = RelationshipGenerator(segments, segmentation, verbose=verbose)
    generator.generate_followers_first()
    generator.enforce_following_limits()
    generator.enforce_follower_limits()
    
    # Step 3: Get statistics
    print("\n Step 3: Relationship statistics...")
    stats = generator.get_statistics()
    print(f"  Total relationships: {stats['total_relationships']:,}")
    
    for user_type in ["small", "medium", "big", "top"]:
        follower_stats = stats["follower_stats"][user_type]
        following_stats = stats["following_stats"][user_type]
        print(f"\n  {user_type.capitalize()} users:")
        print(f"    Followers: min={follower_stats['min']}, max={follower_stats['max']}, avg={follower_stats['avg']:.1f}")
        print(f"    Following: min={following_stats['min']}, max={following_stats['max']}, avg={following_stats['avg']:.1f}")
    
    # Step 4: Load to DynamoDB
    print("\n Step 4: Loading to DynamoDB...")
    follower_map = generator.get_follower_map()
    following_map = generator.get_following_map()
    
    load_to_dynamodb(
        follower_map=follower_map,
        following_map=following_map,
        followers_table_name=followers_table_name,
        following_table_name=following_table_name,
        region=region
    )

    print(f"\n Successfully loaded {total_users:,} users to DynamoDB!")
    print(f"=" * 80)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Generate social graph relationships and load to DynamoDB"
    )
    parser.add_argument(
        "--users",
        type=int,
        default=5000,
        help="Total number of users (default: 5000)"
    )
    parser.add_argument(
        "--followers-table",
        type=str,
        default="social-graph-followers",
        help="Followers table name (default: social-graph-followers)"
    )
    parser.add_argument(
        "--following-table",
        type=str,
        default="social-graph-following",
        help="Following table name (default: social-graph-following)"
    )
    parser.add_argument(
        "--region",
        type=str,
        default="us-west-2",
        help="AWS region (default: us-west-2)"
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress detailed progress output"
    )
    
    args = parser.parse_args()
    
    try:
        generate_and_load(
            total_users=args.users,
            followers_table_name=args.followers_table,
            following_table_name=args.following_table,
            region=args.region,
            verbose=not args.quiet
        )
    except Exception as e:
        print(f"\n Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
