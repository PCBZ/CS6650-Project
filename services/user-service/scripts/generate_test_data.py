#!/usr/bin/env python3
"""
Test data generation script for User Service
Generates realistic usernames and creates users via API calls
"""

import asyncio
import aiohttp
import argparse
import random
import sys
import time
from typing import List, Tuple

# Lists for generating realistic usernames
ADJECTIVES = [
    "amazing", "brilliant", "creative", "dynamic", "elegant", "fantastic", "genius", "happy",
    "incredible", "joyful", "kind", "lovely", "magnificent", "noble", "outstanding", "perfect",
    "quick", "radiant", "super", "terrific", "unique", "vibrant", "wonderful", "excellent",
    "zealous", "awesome", "bright", "charming", "delightful", "energetic", "fabulous", "graceful",
]

NOUNS = [
    "artist", "builder", "coder", "designer", "engineer", "founder", "gamer", "hacker",
    "innovator", "jogger", "keeper", "learner", "maker", "ninja", "organizer", "programmer",
    "queen", "runner", "swimmer", "teacher", "user", "visitor", "writer", "explorer",
    "adventurer", "blogger", "creator", "developer", "enthusiast", "freelancer", "guru", "hero",
]


def generate_username() -> str:
    """Generate a realistic username using adjective + noun + number pattern"""
    adj = random.choice(ADJECTIVES)
    noun = random.choice(NOUNS)
    num = random.randint(1, 9999)
    return f"{adj}_{noun}_{num}"


async def create_user(session: aiohttp.ClientSession, base_url: str, username: str) -> Tuple[bool, str]:
    """
    Create a single user via API call
    Returns (success, error_message)
    """
    user_data = {"username": username}
    
    try:
        async with session.post(
            f"{base_url}/api/users",
            json=user_data,
            headers={"Content-Type": "application/json"}
        ) as response:
            if response.status == 201:
                return True, ""
            else:
                error_text = await response.text()
                return False, f"HTTP {response.status}: {error_text}"
    except Exception as e:
        return False, f"Request failed: {str(e)}"


async def create_users_batch(
    session: aiohttp.ClientSession, 
    base_url: str, 
    usernames: List[str]
) -> Tuple[int, List[str]]:
    """Create a batch of users concurrently"""
    tasks = [create_user(session, base_url, username) for username in usernames]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    success_count = 0
    errors = []
    
    for i, result in enumerate(results):
        if isinstance(result, Exception):
            errors.append(f"Exception for {usernames[i]}: {str(result)}")
        else:
            success, error_msg = result
            if success:
                success_count += 1
            else:
                errors.append(f"Failed {usernames[i]}: {error_msg}")
    
    return success_count, errors


async def generate_test_data(num_users: int, base_url: str, concurrency: int = 50):
    """Main function to generate test data"""
    print(f"Generating {num_users:,} test users...")
    print(f"Base URL: {base_url}")
    print(f"Concurrency: {concurrency}")
    print()
    
    start_time = time.time()
    total_success = 0
    total_errors = []
    
    # Create connector with connection limits
    connector = aiohttp.TCPConnector(limit=concurrency, limit_per_host=concurrency)
    timeout = aiohttp.ClientTimeout(total=30, connect=10)
    
    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        # Process users in batches
        batch_size = concurrency
        
        for i in range(0, num_users, batch_size):
            batch_end = min(i + batch_size, num_users)
            batch_usernames = [generate_username() for _ in range(i, batch_end)]
            
            # Create batch of users
            success_count, errors = await create_users_batch(session, base_url, batch_usernames)
            
            total_success += success_count
            total_errors.extend(errors)
            
            # Progress indicator
            progress = min(batch_end, num_users)
            if progress % 1000 == 0 or progress == num_users:
                elapsed = time.time() - start_time
                rate = total_success / elapsed if elapsed > 0 else 0
                print(f"Progress: {progress:,}/{num_users:,} users | "
                      f"Success: {total_success:,} | "
                      f"Rate: {rate:.1f}/sec")
    
    # Final results
    duration = time.time() - start_time
    failed_count = len(total_errors)
    
    print("\n=== Test Data Generation Complete ===")
    print(f"Total users requested: {num_users:,}")
    print(f"Successfully created: {total_success:,}")
    print(f"Failed: {failed_count:,}")
    print(f"Time taken: {duration:.2f} seconds")
    print(f"Rate: {total_success/duration:.2f} users/second")
    
    if total_errors:
        print(f"\nFirst 10 errors:")
        for i, error in enumerate(total_errors[:10]):
            print(f"  {i+1}. {error}")
        
        if len(total_errors) > 10:
            print(f"  ... and {len(total_errors) - 10} more errors")


def main():
    """Command line interface"""
    parser = argparse.ArgumentParser(
        description="Generate test user data for User Service",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python generate_test_data.py 5000
  python generate_test_data.py 25000 --url http://localhost:8080
  python generate_test_data.py 100000 --url http://alb-dns-name --concurrency 100
        """
    )
    
    parser.add_argument(
        "num_users",
        type=int,
        help="Number of users to create"
    )
    
    parser.add_argument(
        "--url",
        default="http://localhost:8080",
        help="Base URL for the User Service (default: http://localhost:8080)"
    )
    
    parser.add_argument(
        "--concurrency",
        type=int,
        default=50,
        help="Number of concurrent requests (default: 50)"
    )
    
    args = parser.parse_args()
    
    if args.num_users <= 0:
        print("Error: Number of users must be positive")
        sys.exit(1)
    
    if args.concurrency <= 0:
        print("Error: Concurrency must be positive")
        sys.exit(1)
    
    try:
        asyncio.run(generate_test_data(args.num_users, args.url, args.concurrency))
    except KeyboardInterrupt:
        print("\nOperation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()