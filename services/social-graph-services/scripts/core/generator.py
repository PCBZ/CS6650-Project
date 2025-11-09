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
    """Generate follow relationships with power-law / weighted model.

    Enhancements vs original version:
      - Weighted generation (top > big > medium > small)
      - Deterministic target follower counts per tier (exact caps):
            small=1, medium=100, big=500, top=2000 (for <=5k users)
      - ensure_minimum_followers now also trims excess to reach exact targets
      - Avoids erasing follower assignments while enforcing following limits
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

        # Weights by *followee* tier (top users attract more followers)
        tier_weights = {"small": 1, "medium": 3, "big": 10, "top": 50}
        weights = [tier_weights.get(self.user_tier[u], 1) for u in all_users]

        # Per-tier following count ranges (looser than follower ranges)
        def following_target(user_id: int) -> int:
            tier = self.user_tier[user_id]
            if tier == "top":
                return random.randint(20, 80)
            if tier == "big":
                return random.randint(10, 50)
            # small / medium
            return random.randint(5, 30)

        for follower_id in all_users:
            k = following_target(follower_id)
            # Use random.choices (with replacement) then remove duplicates/self
            # Retry sampling if needed to fill diversity (cap attempts to avoid loops)
            attempts = 0
            selected: Set[int] = set()
            while len(selected) < k and attempts < 5:
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
        """Enforce *exact* follower targets per tier.

        For <=5k users we adopt fixed targets:
            small=1, medium=100, big=500, top=2000
        Steps per user:
          1. If current > target: randomly trim excess (remove relationships)
          2. If current < target: add missing by sampling from all other users
        This produces deterministic-looking distribution useful for predictable
        performance & downstream service tests.
        """
        print("\n🔧 Enforcing exact follower targets per tier...")

        if self.segmentation.total_users <= 5000:
            targets = {"small": 1, "medium": 100, "big": 500, "top": 2000}
        else:
            # Scaled-up scenario (simple proportional scaling)
            targets = {"small": 1, "medium": 1000, "big": 5000, "top": 20000}

        all_users: List[int] = [u for tier_list in self.segments.values() for u in tier_list]
        added = 0
        trimmed = 0

        for tier, users in self.segments.items():
            target = targets.get(tier, 0)
            if target == 0:
                continue
            for uid in users:
                current = len(self.follower_map[uid])
                # Trim if above target
                if current > target:
                    excess = current - target
                    to_remove = random.sample(list(self.follower_map[uid]), excess)
                    for follower_id in to_remove:
                        self.follower_map[uid].discard(follower_id)
                        self.following_map[follower_id].discard(uid)
                        self.relationships.discard((follower_id, uid))
                        trimmed += 1
                    current = target
                # Add if below target
                if current < target:
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

        print(f"  Added {added:,} follower links; trimmed {trimmed:,} excess links")
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
