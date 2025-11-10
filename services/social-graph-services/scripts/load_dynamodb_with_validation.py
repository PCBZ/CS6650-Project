#!/usr/bin/env python3
"""
Load test data into DynamoDB tables for social-graph-service
Validates users exist in user-service via gRPC BatchGetUserInfo before generating relationships
"""

import sys
import os
import json
import boto3
import grpc
from typing import Dict, Set, List
from collections import defaultdict

# Add parent directory to path to import core modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from core.segmenter import UserSegmentation
from core.generator import RelationshipGenerator

# Import generated gRPC code
# Assuming proto files are in the project root proto/ directory
PROTO_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), 'proto')
sys.path.insert(0, PROTO_PATH)

try:
    import user_service_pb2
    import user_service_pb2_grpc
except ImportError:
    print("❌ Error: Cannot import user_service proto files")
    print(f"   Make sure proto files are generated in: {PROTO_PATH}")
    print("   Run: cd proto && python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. user_service.proto")
    sys.exit(1)


def fetch_user_ids_from_service(grpc_endpoint: str, max_users: int = None) -> List[int]:
    """
    Fetch real user IDs from user-service via gRPC BatchGetUserInfo
    
    Args:
        grpc_endpoint: gRPC endpoint (e.g., "user-service-grpc:50051" or "localhost:50051")
        max_users: Maximum number of users to fetch (None = all available)
        
    Returns:
        List of valid user IDs
    """
    # Import config for constants
    from core import config
    
    print(f"\n🔍 Fetching users from user-service at {grpc_endpoint}...")
    
    # Scan users in batches using config values
    user_ids = []
    batch_size = config.GRPC_BATCH_SIZE
    current_batch_start = 1
    consecutive_empty_batches = 0
    max_empty_batches = config.MAX_CONSECUTIVE_EMPTY_BATCHES
    
    try:
        # Create gRPC channel
        channel = grpc.insecure_channel(grpc_endpoint)
        stub = user_service_pb2_grpc.UserServiceStub(channel)
        
        print("   Scanning for users in batches of 100...")
        
        while consecutive_empty_batches < max_empty_batches:
            # Build batch of user IDs to check
            batch_ids = list(range(current_batch_start, current_batch_start + batch_size))
            
            # Call BatchGetUserInfo
            request = user_service_pb2.BatchGetUserInfoRequest(user_ids=batch_ids)
            try:
                response = stub.BatchGetUserInfo(request, timeout=10)
                
                # Check for errors
                if response.error_code:
                    print(f"   ⚠️  Warning: {response.error_message}")
                    break
                
                # Collect found users
                found_in_batch = list(response.users.keys())
                if found_in_batch:
                    user_ids.extend(found_in_batch)
                    consecutive_empty_batches = 0
                    print(f"   Found {len(found_in_batch)} users in range {current_batch_start}-{current_batch_start + batch_size - 1}")
                else:
                    consecutive_empty_batches += 1
                
                # Check if we've reached max_users
                if max_users and len(user_ids) >= max_users:
                    user_ids = user_ids[:max_users]
                    print(f"   Reached max_users limit: {max_users}")
                    break
                
            except grpc.RpcError as e:
                print(f"   ⚠️  gRPC error: {e.code()} - {e.details()}")
                break
            
            current_batch_start += batch_size
        
        channel.close()
        
    except Exception as e:
        print(f"   ❌ Error connecting to user-service: {e}")
        print(f"   Falling back to sequential user IDs (1 to {max_users or 5000})")
        # Fallback: generate sequential IDs
        return list(range(1, (max_users or 5000) + 1))
    
    if not user_ids:
        print(f"   ⚠️  No users found in user-service")
        print(f"   Falling back to sequential user IDs (1 to {max_users or 5000})")
        return list(range(1, (max_users or 5000) + 1))
    
    user_ids.sort()
    print(f"   ✅ Found {len(user_ids)} valid users")
    print(f"   User ID range: {min(user_ids)} to {max(user_ids)}")
    
    return user_ids


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
    print(f"\n📦 Loading data to DynamoDB in region {region}...")
    print(f"   Followers table: {followers_table_name}")
    print(f"   Following table: {following_table_name}")
    
    # Initialize DynamoDB client
    dynamodb = boto3.resource('dynamodb', region_name=region)
    followers_table = dynamodb.Table(followers_table_name)
    following_table = dynamodb.Table(following_table_name)
    
    # Batch write to followers table
    print(f"\n   Writing to {followers_table_name}...")
    
    # Debug: Check sample users before writing
    if follower_map:
        max_followers_user = max(follower_map.items(), key=lambda x: len(x[1]))
        print(f"   Max followers: User {max_followers_user[0]} has {len(max_followers_user[1])} followers")
    
    with followers_table.batch_writer() as batch:
        for user_id, followers in follower_map.items():
            if followers:  # Only write if user has followers
                item = {
                    'user_id': str(user_id),
                    'follower_ids': list(map(str, sorted(followers)))
                }
                batch.put_item(Item=item)
    
    print(f"   ✅ Wrote {len(follower_map)} users to {followers_table_name}")
    
    # Batch write to following table
    print(f"\n   Writing to {following_table_name}...")
    with following_table.batch_writer() as batch:
        for user_id, following in following_map.items():
            if following:  # Only write if user is following someone
                item = {
                    'user_id': str(user_id),
                    'following_ids': list(map(str, sorted(following)))
                }
                batch.put_item(Item=item)

    print(f"   ✅ Wrote {len(following_map)} users to {following_table_name}")


def generate_and_load(
    grpc_endpoint: str = None,
    max_users: int = None,
    followers_table_name: str = "social-graph-followers",
    following_table_name: str = "social-graph-following",
    region: str = "us-west-2",
    verbose: bool = True,
    skip_validation: bool = False
):
    """
    Generate relationships and load them into DynamoDB
    
    Args:
        grpc_endpoint: gRPC endpoint for user-service (e.g., "user-service-grpc:50051")
        max_users: Maximum number of users to process (None = all available)
        followers_table_name: Name of the followers DynamoDB table
        following_table_name: Name of the following DynamoDB table
        region: AWS region
        verbose: Print detailed progress
        skip_validation: Skip user validation and use sequential IDs (for testing)
    """
    print(f"\n🚀 Generating and loading social graph data")
    print(f"=" * 80)
    
    # Step 1: Fetch or generate user IDs
    if skip_validation:
        print("\n⚠️  Skipping user validation (using sequential IDs)")
        user_ids = list(range(1, (max_users or 5000) + 1))
        total_users = len(user_ids)
    else:
        if not grpc_endpoint:
            print("❌ Error: grpc_endpoint is required (e.g., 'user-service-grpc:50051')")
            print("   Or use --skip-validation to generate sequential IDs")
            sys.exit(1)
        
        user_ids = fetch_user_ids_from_service(grpc_endpoint, max_users)
        total_users = len(user_ids)
        
        if total_users == 0:
            print("❌ Error: No users found to generate relationships for")
            sys.exit(1)
    
    print(f"\n📊 Processing {total_users:,} users")
    
    # Step 2: Segment users
    print("\n   Step 1: Segmenting users...")
    segmentation = UserSegmentation(total_users)
    segments = segmentation.segment_users(user_ids)
    
    if verbose:
        for segment_name, users in segments.items():
            print(f"     {segment_name.capitalize()}: {len(users):,} users")
    
    # Step 3: Generate relationships
    print("\n   Step 2: Generating relationships...")
    generator = RelationshipGenerator(segments, segmentation, verbose=verbose)
    generator.generate_followers_first()
    generator.ensure_minimum_followers()
    
    # Step 4: Get statistics
    print("\n   Step 3: Relationship statistics...")
    stats = generator.get_statistics()
    print(f"     Total relationships: {stats['total_relationships']:,}")
    
    for user_type in ["small", "medium", "big", "top"]:
        follower_stats = stats["follower_stats"][user_type]
        following_stats = stats["following_stats"][user_type]
        print(f"\n     {user_type.capitalize()} users:")
        print(f"       Followers: min={follower_stats['min']}, max={follower_stats['max']}, avg={follower_stats['avg']:.1f}")
        print(f"       Following: min={following_stats['min']}, max={following_stats['max']}, avg={following_stats['avg']:.1f}")
    
    # Step 5: Load to DynamoDB
    print("\n   Step 4: Loading to DynamoDB...")
    follower_map = generator.get_follower_map()
    following_map = generator.get_following_map()
    
    load_to_dynamodb(
        follower_map=follower_map,
        following_map=following_map,
        followers_table_name=followers_table_name,
        following_table_name=following_table_name,
        region=region
    )

    print(f"\n✅ Successfully loaded {total_users:,} users to DynamoDB!")
    print(f"=" * 80)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Generate social graph relationships with user validation and load to DynamoDB"
    )
    parser.add_argument(
        "--grpc-endpoint",
        type=str,
        help="User service gRPC endpoint (e.g., 'user-service-grpc:50051' or 'localhost:50051')"
    )
    parser.add_argument(
        "--max-users",
        type=int,
        help="Maximum number of users to process (default: all found users)"
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
        "--skip-validation",
        action="store_true",
        help="Skip user validation and use sequential IDs 1 to max-users (default: 5000)"
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress detailed progress output"
    )
    
    args = parser.parse_args()
    
    try:
        generate_and_load(
            grpc_endpoint=args.grpc_endpoint,
            max_users=args.max_users,
            followers_table_name=args.followers_table,
            following_table_name=args.following_table,
            region=args.region,
            verbose=not args.quiet,
            skip_validation=args.skip_validation
        )
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
