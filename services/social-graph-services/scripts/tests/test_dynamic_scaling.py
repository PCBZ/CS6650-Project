#!/usr/bin/env python3
"""
Test dynamic scaling of follower/following ranges across different user counts
"""

import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from core.segmenter import UserSegmentation


def test_scaling():
    """Test how ranges scale with different user counts"""
    
    user_counts = [100, 1000, 5000, 10000, 25000, 100000]
    
    print("=" * 100)
    print("Dynamic Scaling Test: Follower/Following Ranges")
    print("=" * 100)
    
    for total_users in user_counts:
        seg = UserSegmentation(total_users)
        
        print(f"\n📊 {total_users:,} Users:")
        print(f"{'':4}{'Tier':<10} {'Count':<10} {'Pct':<8} {'Followers Range':<25} {'Following Range':<25}")
        print(f"{'':4}{'-'*10} {'-'*10} {'-'*8} {'-'*25} {'-'*25}")
        
        for tier in ["small", "medium", "big", "top"]:
            info = seg.get_segment_info()[tier]
            follower_range = seg.get_follower_range(tier)
            following_range = seg.get_following_range(tier)
            
            print(f"{'':4}{tier:<10} {info['count']:<10,} {info['percentage']:<7.2f}% "
                  f"{follower_range[0]:>6,}-{follower_range[1]:<12,} "
                  f"{following_range[0]:>6,}-{following_range[1]:<12,}")
        
        # Calculate expected relationship count
        print(f"\n{'':4}Expected Relationships:")
        total_followers = 0
        for tier in ["small", "medium", "big", "top"]:
            info = seg.get_segment_info()[tier]
            follower_range = seg.get_follower_range(tier)
            # Use midpoint of range
            avg_followers = (follower_range[0] + follower_range[1]) / 2
            tier_followers = info['count'] * avg_followers
            total_followers += tier_followers
            print(f"{'':6}{tier.capitalize()}: {info['count']:,} users × {avg_followers:.0f} avg = {tier_followers:,.0f} relationships")
        
        print(f"{'':6}{'Total (est):':<10} {total_followers:,.0f} relationships")
        print(f"{'':6}{'Ratio:':<10} {total_followers/total_users:.1f} relationships per user")


if __name__ == "__main__":
    test_scaling()
