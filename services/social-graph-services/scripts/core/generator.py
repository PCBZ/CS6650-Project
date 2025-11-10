#!/usr/bin/env python3
"""
Relationship Generator Module

Generates follow relationships using power-law distribution to simulate
realistic social network patterns. All parameters are configured in config.py.
"""

import random
from typing import List, Dict, Set, Tuple
from collections import defaultdict
from . import config


class RelationshipGenerator:
    """Generate follow relationships with power-law / weighted model.

    Features:
      - Weighted generation (top > big > medium > small) for rich-get-richer effect
      - Power-law distribution for natural social network patterns
      - Follower count ranges per tier (not exact targets) to preserve variance:
            small: 0-5, medium: 50-150, big: 300-700, top: 1500-2500 (for ≤5k users)
      - ensure_minimum_followers enforces min/max bounds while keeping natural distribution
      - Following limits enforced per tier without destroying follower patterns
    """

    def __init__(self, segments: Dict[str, List[int]], segmentation, verbose: bool = False):
        self.segments = segments
        self.segmentation = segmentation
        self.verbose = verbose

        # Data structures
        self.relationships: Set[Tuple[int, int]] = set()
        self.follower_map: Dict[int, Set[int]] = defaultdict(set)
        self.following_map: Dict[int, Set[int]] = defaultdict(set)

        # Pre-compute user -> tier mapping for O(1) lookups
        self.user_tier: Dict[int, str] = {}
        for tier, users in segments.items():
            for uid in users:
                self.user_tier[uid] = tier
    
    def powerlaw_random(self, n: int, alpha: float = 2.5) -> int:
        """
        Generate a random number following power-law distribution
        
        Args:
            n: Maximum value (exclusive - will return 0 to n-1)
            alpha: Power-law exponent (default: 2.5 for social networks)
            
        Returns:
            Random integer following power-law distribution (0 to n-1)
        """
        # Ensure result is within valid array index range [0, n-1]
        result = int(n * (1 - random.random()) ** (1 / (1 - alpha)))
        return min(result, n - 1)
    
    def generate_followers_first(self):
        """Weighted initial relationship seeding.

        We generate an initial organic graph by letting each user choose a
        following list whose size depends on its own tier; the probability of
        picking a followee is weighted by the followee's tier (rich-get-richer).
        This produces a skew before we enforce *exact* follower targets.
        """
        if self.verbose:
            print("\n📊 Generating followers (weighted by tier)...")

        # Flatten all users
        all_users: List[int] = [u for tier_list in self.segments.values() for u in tier_list]

        # Weights by *followee* tier (top users attract more followers) - from config
        weights = [config.TIER_WEIGHTS.get(self.user_tier[u], 1) for u in all_users]

        # Per-tier following count ranges (dynamically from segmentation)
        def following_target(user_id: int) -> int:
            tier = self.user_tier[user_id]
            min_following, max_following = self.segmentation.get_following_range(tier)
            return random.randint(min_following, max_following)

        for follower_id in all_users:
            k = following_target(follower_id)
            # Use random.choices (with replacement) then remove duplicates/self
            # Retry sampling if needed to fill diversity (cap attempts from config)
            attempts = 0
            selected: Set[int] = set()
            while len(selected) < k and attempts < config.MAX_FOLLOWEE_SELECTION_ATTEMPTS:
                batch = random.choices(all_users, weights=weights, k=k)
                for cand in batch:
                    if cand == follower_id:
                        continue
                    selected.add(cand)
                    if len(selected) >= k:
                        break
                attempts += 1

            for followee_id in selected:
                rel = (follower_id, followee_id)
                if rel not in self.relationships:
                    self.relationships.add(rel)
                    self.follower_map[followee_id].add(follower_id)
                    self.following_map[follower_id].add(followee_id)

        print(f"✅ Seeded {len(self.relationships):,} preliminary relationships")
    
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
        """Enforce follower count ranges per tier with random individual targets.

        Each user gets a random target within their tier's range, creating natural variance:
            small: 0-5, medium: 50-150, big: 300-700, top: 1500-2500
        
        For each user:
          1. Assign random target = randint(min, max) for their tier
          2. If current > target: trim to target
          3. If current < target: pad to target
        
        This creates realistic distributions with natural variance, e.g.:
            Medium avg: 93 ± 30
            Big avg: 480 ± 100
            Top avg: 2000 ± 300
        """
        print("\n🔧 Enforcing follower count ranges with random targets per user...")

        # Use segmentation's dynamic follower ranges (based on % of total users)
        # No more hardcoded values!
        
        all_users: List[int] = [u for tier_list in self.segments.values() for u in tier_list]
        added = 0
        trimmed = 0
        adjusted_users = 0

        for tier, users in self.segments.items():
            # Get dynamic range from segmentation
            target_range = self.segmentation.get_follower_range(tier)
            if target_range == (0, 0):
                continue
            
            min_followers, max_followers = target_range
            
            for uid in users:
                current = len(self.follower_map[uid])
                
                # Assign random target within tier range for this specific user
                target = random.randint(min_followers, max_followers)
                
                # Trim if above target
                if current > target:
                    excess = current - target
                    to_remove = random.sample(list(self.follower_map[uid]), excess)
                    for follower_id in to_remove:
                        self.follower_map[uid].discard(follower_id)
                        self.following_map[follower_id].discard(uid)
                        self.relationships.discard((follower_id, uid))
                        trimmed += 1
                    adjusted_users += 1
                
                # Pad if below target
                elif current < target:
                    needed = target - current
                    # Candidate pool: all users except self and existing followers
                    candidates = [c for c in all_users if c != uid and c not in self.follower_map[uid]]
                    if not candidates:
                        continue
                    k = min(needed, len(candidates))
                    new_followers = random.sample(candidates, k)
                    for fid in new_followers:
                        if (fid, uid) in self.relationships:
                            continue
                        self.relationships.add((fid, uid))
                        self.follower_map[uid].add(fid)
                        self.following_map[fid].add(uid)
                        added += 1
                    adjusted_users += 1

        print(f"  Adjusted {adjusted_users:,} users (added {added:,} links, trimmed {trimmed:,} links)")
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
