#!/usr/bin/env python3
"""
Relationship Generator Module

Generates follow relationships using power-law distribution to simulate
realistic social network patterns.
"""

import random
from typing import List, Dict, Set, Tuple
from collections import defaultdict


class RelationshipGenerator:
    """Generate follow relationships with power-law distribution"""
    
    def __init__(self, segments: Dict[str, List[int]], segmentation, verbose: bool = False):
        """
        Initialize the relationship generator
        
        Args:
            segments: Dictionary mapping segment names to user ID lists
            segmentation: UserSegmentation instance for range information
            verbose: Whether to print detailed progress
        """
        self.segments = segments
        self.segmentation = segmentation
        self.verbose = verbose
        
        # Data structures
        self.relationships: Set[Tuple[int, int]] = set()
        self.follower_map: Dict[int, Set[int]] = defaultdict(set)
        self.following_map: Dict[int, Set[int]] = defaultdict(set)
    
    def powerlaw_random(self, n: int, alpha: float = 2.5) -> int:
        """
        Generate a random number following power-law distribution
        
        Args:
            n: Maximum value
            alpha: Power-law exponent (default: 2.5 for social networks)
            
        Returns:
            Random integer following power-law distribution
        """
        return int(n * (1 - random.random()) ** (1 / (1 - alpha)))
    
    def generate_followers_first(self):
        """
        Generate followers using power-law distribution
        Strategy: Assign followers to users based on their segment
        """
        if self.verbose:
            print("\n📊 Generating followers (power-law distribution)...")
        
        all_users = []
        for users in self.segments.values():
            all_users.extend(users)
        
        # Generate followers for each user
        for user_id in all_users:
            # Determine how many followers to select
            num_potential_followers = max(1, len(all_users) // 10)
            
            for _ in range(num_potential_followers):
                # Use power-law distribution to select follower
                follower_idx = self.powerlaw_random(len(all_users))
                follower_id = all_users[follower_idx]
                
                # Avoid self-follow and duplicates
                if follower_id != user_id:
                    relationship = (follower_id, user_id)
                    if relationship not in self.relationships:
                        self.relationships.add(relationship)
                        self.follower_map[user_id].add(follower_id)
                        self.following_map[follower_id].add(user_id)
        
        print(f"✅ Generated {len(self.relationships):,} follow relationships")
    
    def enforce_following_limits(self):
        """
        Enforce following limits for each user type
        Trim followings to a random target within the allowed range
        """
        if self.verbose:
            print(f"\n🔧 Enforcing following limits...")
        
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
        Ensure each user has at least the minimum required followers
        """
        print(f"\n🔧 Ensuring minimum follower requirements...")
        
        added_count = 0
        
        for user_type, users in self.segments.items():
            min_followers = self.segmentation.get_follower_range(user_type)[0]
            
            for user_id in users:
                current_followers = len(self.follower_map[user_id])
                
                if current_followers < min_followers:
                    needed = min_followers - current_followers
                    
                    # Allow overflow for Big and Top users
                    allow_overflow = user_type in ["big", "top"]
                    
                    potential_followers = []
                    
                    # Priority 1: Small users
                    for small_user_id in self.segments.get("small", []):
                        if small_user_id == user_id:
                            continue
                        if (small_user_id, user_id) in self.relationships:
                            continue
                        
                        current_following = len(self.following_map[small_user_id])
                        max_following = self.segmentation.get_following_range("small")[1]
                        
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
                            
                            if allow_overflow:
                                if current_following < max_following + 10:
                                    potential_followers.append(medium_user_id)
                            else:
                                if current_following < max_following:
                                    potential_followers.append(medium_user_id)
                    
                    # Priority 3: Big users (for Top users only)
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
                    
                    # Add relationships
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
    
    def get_relationships(self) -> Set[Tuple[int, int]]:
        """Get all generated relationships"""
        return self.relationships
    
    def get_follower_map(self) -> Dict[int, Set[int]]:
        """Get follower mapping"""
        return dict(self.follower_map)
    
    def get_following_map(self) -> Dict[int, Set[int]]:
        """Get following mapping"""
        return dict(self.following_map)
