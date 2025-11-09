#!/usr/bin/env python3
"""
This script generates follow relationships among a set of users,
segmented into Small, Medium, Big, and Top categories.
It outputs the relationships into CSV files to run local tests.
"""

import json
import random
import csv
from typing import List, Dict, Tuple, Set
from collections import defaultdict
import argparse
import time

class UserSegmentation:
    """Handle user segmentation logic"""
    
    def __init__(self, total_users: int):
        self.total_users = total_users
        
        # Calculate segment sizes
        self.small_count = int(total_users * 0.80)
        self.medium_count = int(total_users * 0.15)
        self.big_count = int(total_users * 0.0499)
        self.top_count = max(1, total_users - self.small_count - self.medium_count - self.big_count)
        
        print(f"\n📊 User Segmentation for {total_users:,} users:")
        print(f"  Small (80%): {self.small_count:,} users")
        print(f"  Medium (15%): {self.medium_count:,} users")
        print(f"  Big (4.99%): {self.big_count:,} users")
        print(f"  Top (0.01%): {self.top_count:,} users")
    
    def segment_users(self, user_ids: List[int]) -> Dict[str, List[int]]:
        """Randomly assign users to segments"""
        shuffled = user_ids.copy()
        random.shuffle(shuffled)
        
        segments = {
            "small": shuffled[:self.small_count],
            "medium": shuffled[self.small_count:self.small_count + self.medium_count],
            "big": shuffled[self.small_count + self.medium_count:self.small_count + self.medium_count + self.big_count],
            "top": shuffled[self.small_count + self.medium_count + self.big_count:]
        }
        
        return segments
    
    def get_follower_range(self, user_type: str) -> Tuple[int, int]:
        """Get follower count range for user type"""
        total = self.total_users
        
        if total <= 5000:
            ranges = {
                "small": (1, 99),
                "medium": (100, 499),
                "big": (500, 1999),
                "top": (2000, 4999)
            }
        elif total <= 25000:
            ranges = {
                "small": (1, 499),
                "medium": (500, 2499),
                "big": (2500, 9999),
                "top": (10000, 24999)
            }
        else:  # 100,000
            ranges = {
                "small": (1, 1999),
                "medium": (2000, 9999),
                "big": (10000, 39999),
                "top": (40000, 99999)
            }
        
        return ranges[user_type]
    
    def get_following_range(self, user_type: str) -> Tuple[int, int]:
        """Get following count range for user type"""
        total = self.total_users
        
        if total <= 5000:
            ranges = {
                "small": (1, 49),
                "medium": (1, 49),
                "big": (0, 25),
                "top": (0, 25)
            }
        elif total <= 25000:
            ranges = {
                "small": (1, 299),
                "medium": (1, 299),
                "big": (0, 125),
                "top": (0, 125)
            }
        else:  # 100,000
            ranges = {
                "small": (1, 999),
                "medium": (1, 999),
                "big": (0, 500),
                "top": (0, 500)
            }
        
        return ranges[user_type]


def powerlaw_random(min_val: int, max_val: int, alpha: float = 2.0) -> int:
    """
    Generate a random number following power-law distribution.
    This creates more realistic social network distributions (Zipf's law).
    """
    if min_val >= max_val:
        return min_val
    
    r = random.random()
    range_pow = max_val ** (alpha + 1) - min_val ** (alpha + 1)
    result = int((range_pow * r + min_val ** (alpha + 1)) ** (1 / (alpha + 1)))
    
    # Ensure result is within bounds
    return max(min_val, min(max_val, result))


class RelationshipGenerator:
    """Generate follow relationships with realistic power-law distribution"""
    
    def __init__(self, segments: Dict[str, List[int]], segmentation: UserSegmentation, verbose: bool = False):
        self.segments = segments
        self.segmentation = segmentation
        self.verbose = verbose
        self.all_user_ids = []
        for users in segments.values():
            self.all_user_ids.extend(users)
        
        # Use sets for faster lookups and automatic deduplication
        self.relationships: Set[Tuple[int, int]] = set()
        self.follower_map: Dict[int, Set[int]] = defaultdict(set)
        self.following_map: Dict[int, Set[int]] = defaultdict(set)
    
    def generate_followers_first(self) -> Set[Tuple[int, int]]:
        """
        Generate relationships by assigning followers first (more realistic).
        This ensures big users naturally get more followers.
        """
        print("\n📊 Generating followers (power-law distribution)...")
        
        for user_type, users in self.segments.items():
            follower_range = self.segmentation.get_follower_range(user_type)
            
            if self.verbose:
                print(f"  {user_type}: {len(users)} users, follower range {follower_range}")
            
            for i, user_id in enumerate(users):
                if self.verbose and (i + 1) % 1000 == 0:
                    print(f"    Processed {i + 1}/{len(users)} {user_type} users")
                
                # Use power-law distribution for more realistic follower counts
                num_followers = powerlaw_random(follower_range[0], follower_range[1], alpha=2.5)
                
                # Select random followers (excluding self)
                possible_followers = [uid for uid in self.all_user_ids if uid != user_id]
                
                if len(possible_followers) < num_followers:
                    num_followers = len(possible_followers)
                
                if num_followers > 0:
                    selected_followers = random.sample(possible_followers, num_followers)
                    
                    for follower_id in selected_followers:
                        if follower_id != user_id:
                            self.relationships.add((follower_id, user_id))
                            self.follower_map[user_id].add(follower_id)
                            self.following_map[follower_id].add(user_id)
        
        print(f"✅ Generated {len(self.relationships):,} follow relationships")
        return self.relationships
    
    def enforce_following_limits(self):
        """
        Enforce following limits for each user type.
        Trim followings to a random target within the allowed range.
        """
        print("\n🔧 Enforcing following limits...")
        
        removed_count = 0
        adjusted_count = 0
        
        for user_type, users in self.segments.items():
            following_range = self.segmentation.get_following_range(user_type)
            min_following = following_range[0]
            max_following = following_range[1]
            
            for user_id in users:
                current_following = len(self.following_map[user_id])
                
                if current_following > max_following:
                    # Set a random target within the allowed range
                    target_following = random.randint(min_following, max_following)
                    excess = current_following - target_following
                    
                    if excess > 0:
                        followings_list = list(self.following_map[user_id])
                        to_remove = random.sample(followings_list, excess)
                        
                        for followee_id in to_remove:
                            self.relationships.discard((user_id, followee_id))
                            self.following_map[user_id].discard(followee_id)
                            self.follower_map[followee_id].discard(user_id)
                            removed_count += 1
                        
                        adjusted_count += 1
        
        if removed_count > 0:
            print(f"  Adjusted {adjusted_count:,} users")
            print(f"  Removed {removed_count:,} relationships to enforce following limits")
        print(f"✅ Final relationship count: {len(self.relationships):,}")
    
    def ensure_minimum_followers(self):
        """
        ensure each user meets their minimum follower requirements.
        This may involve adding new relationships.
        """
        print(f"\n🔧 Ensuring minimum follower requirements...")
        
        added_count = 0
        
        for user_type, users in self.segments.items():
            min_followers = self.segmentation.get_follower_range(user_type)[0]
            
            for user_id in users:
                current_followers = len(self.follower_map[user_id])
                
                if current_followers < min_followers:
                    needed = min_followers - current_followers

                    # Collect all potential followers (by priority)
                    potential_followers = []

                    # For Big and Top users, we need a more lenient strategy
                    # Allow Small/Medium users to slightly exceed following limits
                    allow_overflow = user_type in ["big", "top"]

                    # Priority 1: Small users
                    for small_user_id in self.segments.get("small", []):
                        if small_user_id == user_id:
                            continue
                        if (small_user_id, user_id) in self.relationships:
                            continue
                        
                        current_following = len(self.following_map[small_user_id])
                        max_following = self.segmentation.get_following_range("small")[1]

                        # For Big/Top, allow Small users to exceed by 10 (to give more followers to Top users)
                        if allow_overflow:
                            if current_following < max_following + 10:
                                potential_followers.append(small_user_id)
                        else:
                            if current_following < max_following:
                                potential_followers.append(small_user_id)

                    # Priority 2: Medium users
                    if len(potential_followers) < needed:
                        for medium_user_id in self.segments.get("medium", []):
                            if medium_user_id == user_id:
                                continue
                            if (medium_user_id, user_id) in self.relationships:
                                continue
                            
                            current_following = len(self.following_map[medium_user_id])
                            max_following = self.segmentation.get_following_range("medium")[1]

                            # For Big/Top, allow Medium users to exceed by 10 (to give more followers to Top users)
                            if allow_overflow:
                                if current_following < max_following + 10:
                                    potential_followers.append(medium_user_id)
                            else:
                                if current_following < max_following:
                                    potential_followers.append(medium_user_id)

                    # Priority 3: Big users (for Top users)
                    if len(potential_followers) < needed and user_type == "top":
                        for big_user_id in self.segments.get("big", []):
                            if big_user_id == user_id:
                                continue
                            if (big_user_id, user_id) in self.relationships:
                                continue
                            
                            current_following = len(self.following_map[big_user_id])
                            max_following = self.segmentation.get_following_range("big")[1]
                            
                            if current_following < max_following:
                                potential_followers.append(big_user_id)
                    
                    # Randomly select the needed number
                    if potential_followers:
                        selected = random.sample(potential_followers, min(needed, len(potential_followers)))
                        
                        for follower_id in selected:
                            self.relationships.add((follower_id, user_id))
                            self.following_map[follower_id].add(user_id)
                            self.follower_map[user_id].add(follower_id)
                            added_count += 1
        
        if added_count > 0:
            print(f"  Added {added_count:,} relationships to meet minimum follower requirements")
        print(f"✅ Final relationship count: {len(self.relationships):,}")
    
    def get_statistics(self) -> Dict:
        """Get statistics about the generated relationships"""
        stats = {
            "total_relationships": len(self.relationships),
            "follower_stats": {},
            "following_stats": {}
        }
        
        for user_type, users in self.segments.items():
            follower_counts = [len(self.follower_map[uid]) for uid in users]
            following_counts = [len(self.following_map[uid]) for uid in users]
            
            stats["follower_stats"][user_type] = {
                "count": len(users),
                "min": min(follower_counts) if follower_counts else 0,
                "max": max(follower_counts) if follower_counts else 0,
                "avg": sum(follower_counts) / len(follower_counts) if follower_counts else 0
            }
            
            stats["following_stats"][user_type] = {
                "count": len(users),
                "min": min(following_counts) if following_counts else 0,
                "max": max(following_counts) if following_counts else 0,
                "avg": sum(following_counts) / len(following_counts) if following_counts else 0
            }
        
        return stats


def print_statistics(stats: Dict):
    """Print detailed statistics about generated relationships"""
    print("\n" + "="*60)
    print("📊 RELATIONSHIP STATISTICS")
    print("="*60)
    print(f"\nTotal Relationships: {stats['total_relationships']:,}")
    
    print("\n👥 Follower Distribution:")
    for user_type, data in stats["follower_stats"].items():
        print(f"  {user_type.capitalize():8} ({data['count']:6,} users): "
              f"min={data['min']:6,}, max={data['max']:6,}, avg={data['avg']:8.1f}")
    
    print("\n➡️  Following Distribution:")
    for user_type, data in stats["following_stats"].items():
        print(f"  {user_type.capitalize():8} ({data['count']:6,} users): "
              f"min={data['min']:6,}, max={data['max']:6,}, avg={data['avg']:8.1f}")
    
    print("="*60)


def save_to_csv(
    follower_map: Dict[int, Set[int]],
    following_map: Dict[int, Set[int]],
    segments: Dict[str, List[int]],
    output_dir: str = "."
):
    """
    Save to two CSV files for DynamoDB tables:
    1. FollowersTable.csv
    2. FollowingTable.csv
    3. UserSegments.csv (for validation)
    """
    import os
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Save FollowersTable
    followers_file = os.path.join(output_dir, "FollowersTable.csv")
    print(f"\n💾 Saving FollowersTable to {followers_file}...")
    
    with open(followers_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        # Header
        writer.writerow(['user_id', 'follower_id', 'timestamp'])
        
        # Data
        timestamp = int(time.time())
        row_count = 0
        for user_id, followers in sorted(follower_map.items()):
            for follower_id in sorted(followers):
                writer.writerow([user_id, follower_id, timestamp])
                row_count += 1
        
        print(f"  ✅ Saved {row_count:,} rows to FollowersTable.csv")
    
    # Save FollowingTable
    following_file = os.path.join(output_dir, "FollowingTable.csv")
    print(f"💾 Saving FollowingTable to {following_file}...")
    
    with open(following_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        # Header
        writer.writerow(['user_id', 'followee_id', 'timestamp'])
        
        # Data
        row_count = 0
        for user_id, followings in sorted(following_map.items()):
            for followee_id in sorted(followings):
                writer.writerow([user_id, followee_id, timestamp])
                row_count += 1
        
        print(f"  ✅ Saved {row_count:,} rows to FollowingTable.csv")
    
    # Save UserSegments.csv
    segments_file = os.path.join(output_dir, "UserSegments.csv")
    print(f"💾 Saving UserSegments to {segments_file}...")
    
    with open(segments_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        # Header
        writer.writerow(['user_id', 'segment'])
        
        # Data
        row_count = 0
        for segment, user_ids in sorted(segments.items()):
            for user_id in sorted(user_ids):
                writer.writerow([user_id, segment])
                row_count += 1
        
        print(f"  ✅ Saved {row_count:,} rows to UserSegments.csv")


def generate_test_users(num_users: int) -> List[int]:
    """Generate test user IDs (1 to num_users)"""
    return list(range(1, num_users + 1))


def main():
    parser = argparse.ArgumentParser(
        description="本地测试：生成关注关系并输出CSV文件",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument("--num-users", type=int, default=5000, help="Total number of users")
    parser.add_argument("--output-dir", default=".", help="Output directory for CSV files")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for reproducibility")
    parser.add_argument("--verbose", action="store_true", help="Print detailed progress")
    
    args = parser.parse_args()
    
    # Set random seed
    random.seed(args.seed)
    print(f"🎲 Random seed: {args.seed}")
    
    # Generate test users
    print(f"\n📂 Generating {args.num_users:,} test users...")
    user_ids = generate_test_users(args.num_users)
    print(f"  ✅ Generated user IDs: 1 to {args.num_users:,}")
    
    # Segment users
    segmentation = UserSegmentation(len(user_ids))
    segments = segmentation.segment_users(user_ids)
    
    # Generate relationships using improved algorithm
    generator = RelationshipGenerator(segments, segmentation, verbose=args.verbose)
    
    # Step 1: Generate followers first (power-law distribution)
    generator.generate_followers_first()
    
    # Step 2: Enforce following limits per user type
    generator.enforce_following_limits()
    
    # Step 3: Ensure minimum follower requirements
    generator.ensure_minimum_followers()
    
    # Get statistics
    stats = generator.get_statistics()
    print_statistics(stats)
    
    # Save to CSV files
    save_to_csv(
        generator.follower_map,
        generator.following_map,
        generator.segments,
        args.output_dir
    )
    
    # Print summary
    print("\n" + "="*60)
    print("✅ SUCCESS!")
    print("="*60)
    print(f"Generated files in '{args.output_dir}':")
    print(f"  1. FollowersTable.csv - {len(generator.relationships):,} rows")
    print(f"  2. FollowingTable.csv - {len(generator.relationships):,} rows")
    print(f"  3. UserSegments.csv - {args.num_users:,} rows")
    print(f"\nTotal users: {args.num_users:,}")
    print(f"Total relationships: {len(generator.relationships):,}")
    print(f"Avg relationships per user: {len(generator.relationships) / args.num_users:.1f}")
    print("="*60)


if __name__ == "__main__":
    main()
