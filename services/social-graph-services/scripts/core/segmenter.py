#!/usr/bin/env python3
"""
User Segmentation Module

Handles the logic for segmenting users into different tiers:
- Small users: 80% of total (1-99 followers)
- Medium users: 15% of total (100-499 followers)
- Big users: 4.99% of total (500-1999 followers)
- Top users: 0.01% of total (2000-4999 followers)
"""

import random
from typing import List, Dict


class UserSegmentation:
    """Handle user segmentation logic"""
    
    def __init__(self, total_users: int):
        self.total_users = total_users
        
        # Calculate segment sizes
        self.small_count = int(total_users * 0.80)
        self.medium_count = int(total_users * 0.15)
        self.big_count = int(total_users * 0.0499)
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
        # Use fixed seed for consistent, reproducible segmentation across runs
        random.seed(42)
        random.shuffle(shuffled_users)
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
        Get expected follower count range for a user type
        
        Args:
            user_type: Type of user (small, medium, big, top)
            
        Returns:
            Tuple of (min_followers, max_followers)
        """
        if self.total_users <= 5000:
            ranges = {
                "small": (1, 99),
                "medium": (100, 499),
                "big": (500, 1999),
                "top": (2000, 4999)
            }
        else:
            ranges = {
                "small": (1, 999),
                "medium": (1000, 4999),
                "big": (5000, 19999),
                "top": (20000, 49999)
            }
        
        return ranges.get(user_type, (0, 0))
    
    def get_following_range(self, user_type: str) -> tuple:
        """
        Get expected following count range for a user type
        
        Args:
            user_type: Type of user (small, medium, big, top)
            
        Returns:
            Tuple of (min_following, max_following)
        """
        if self.total_users <= 5000:
            ranges = {
                "small": (1, 49),
                "medium": (1, 49),
                "big": (0, 25),
                "top": (0, 25)
            }
        else:
            ranges = {
                "small": (1, 999),
                "medium": (1, 999),
                "big": (0, 500),
                "top": (0, 500)
            }
        
        return ranges.get(user_type, (0, 0))
    
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
