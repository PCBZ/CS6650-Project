#!/usr/bin/env python3
"""
User Segmentation Module

Handles the logic for segmenting users into different tiers based on configuration.
All ratios and thresholds are defined in config.py.
"""

import random
from typing import List, Dict
from . import config


class UserSegmentation:
    """Handle user segmentation logic"""
    
    def __init__(self, total_users: int):
        self.total_users = total_users
        
        # Calculate segment sizes from config
        self.small_count = int(total_users * config.USER_TIER_RATIOS["small"])
        self.medium_count = int(total_users * config.USER_TIER_RATIOS["medium"])
        self.big_count = int(total_users * config.USER_TIER_RATIOS["big"])
        self.top_count = max(1, total_users - self.small_count - self.medium_count - self.big_count)
    
    def segment_users(self, user_ids: List[int]) -> Dict[str, List[int]]:
        """
        Segment users into different tiers
        
        Args:
            user_ids: List of user IDs to segment
            
        Returns:
            Dictionary mapping segment names to lists of user IDs
        """
        shuffled_users = user_ids.copy()
        # Use fixed seed from config for consistent, reproducible segmentation across runs
        if config.SEGMENTATION_SEED is not None:
            random.seed(config.SEGMENTATION_SEED)
        random.shuffle(shuffled_users)
        if config.SEGMENTATION_SEED is not None:
            random.seed()  # Reset to random seed for subsequent operations
        
        segments = {
            "small": shuffled_users[:self.small_count],
            "medium": shuffled_users[self.small_count:self.small_count + self.medium_count],
            "big": shuffled_users[
                self.small_count + self.medium_count:
                self.small_count + self.medium_count + self.big_count
            ],
            "top": shuffled_users[
                self.small_count + self.medium_count + self.big_count:
            ]
        }
        
        return segments
    
    def get_follower_range(self, user_type: str) -> tuple:
        """
        Get expected follower count range for a user type (dynamically scaled from config)
        
        Ranges are calculated as percentages of total users defined in config.FOLLOWER_RATIOS
        with absolute minimums from config.FOLLOWER_ABSOLUTE_MINIMUMS
        
        Args:
            user_type: Type of user (small, medium, big, top)
            
        Returns:
            Tuple of (min_followers, max_followers)
        """
        if user_type not in config.FOLLOWER_RATIOS:
            return (0, 0)
        
        min_ratio, max_ratio = config.FOLLOWER_RATIOS[user_type]
        abs_min = config.FOLLOWER_ABSOLUTE_MINIMUMS[user_type]
        
        min_followers = max(abs_min, int(self.total_users * min_ratio))
        max_followers = max(min_followers + 1, int(self.total_users * max_ratio))
        
        return (min_followers, max_followers)
    
    def get_following_range(self, user_type: str) -> tuple:
        """
        Get expected following count range for a user type (dynamically scaled from config)
        
        Following counts are calculated from config.FOLLOWING_RATIOS with absolute
        minimums and maximums applied.
        
        Args:
            user_type: Type of user (small, medium, big, top)
            
        Returns:
            Tuple of (min_following, max_following)
        """
        if user_type not in config.FOLLOWING_RATIOS:
            return (0, 0)
        
        min_ratio, max_ratio = config.FOLLOWING_RATIOS[user_type]
        abs_min = config.FOLLOWING_ABSOLUTE_MINIMUMS[user_type]
        abs_max = config.FOLLOWING_ABSOLUTE_MAXIMUMS[user_type]
        
        min_following = max(abs_min, int(self.total_users * min_ratio))
        max_following = max(min_following + 1, int(self.total_users * max_ratio))
        
        # Apply absolute maximum cap
        max_following = min(max_following, abs_max)
        
        return (min_following, max_following)
    
    def get_segment_info(self) -> Dict:
        """
        Get segmentation information
        
        Returns:
            Dictionary with segment counts and percentages
        """
        return {
            "small": {
                "count": self.small_count,
                "percentage": (self.small_count / self.total_users * 100)
            },
            "medium": {
                "count": self.medium_count,
                "percentage": (self.medium_count / self.total_users * 100)
            },
            "big": {
                "count": self.big_count,
                "percentage": (self.big_count / self.total_users * 100)
            },
            "top": {
                "count": self.top_count,
                "percentage": (self.top_count / self.total_users * 100)
            }
        }
    
    def print_segmentation_info(self):
        """Print segmentation information"""
        print(f"\n📊 User Segmentation for {self.total_users:,} users:")
        print(f"  Small (80%): {self.small_count:,} users")
        print(f"  Medium (15%): {self.medium_count:,} users")
        print(f"  Big (4.99%): {self.big_count:,} users")
        print(f"  Top (0.01%): {self.top_count:,} users")
