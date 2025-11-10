#!/usr/bin/env python3
"""
Configuration for Social Graph Generation

This module contains all the tunable parameters for user segmentation,
follower/following distributions, and relationship generation.
"""

# =============================================================================
# USER SEGMENTATION RATIOS
# =============================================================================

# Percentage of users in each tier (must sum to ~100%)
USER_TIER_RATIOS = {
    "small": 0.80,      # 80% - Long tail users with few followers
    "medium": 0.15,     # 15% - Mid-tier users with moderate following
    "big": 0.0499,      # 4.99% - High-influence users
    "top": 0.0001       # 0.01% - Super influencers (calculated as remainder)
}

# =============================================================================
# FOLLOWER COUNT RANGES (as % of total users)
# =============================================================================

# Min and max followers for each tier, expressed as percentages of total user base
# Format: (min_percentage, max_percentage)
FOLLOWER_RATIOS = {
    "small": (0.0001, 0.01),    # 0.01% to 1% of total users
    "medium": (0.01, 0.03),      # 1% to 3% of total users
    "big": (0.06, 0.14),         # 6% to 14% of total users
    "top": (0.30, 0.50)          # 30% to 50% of total users
}

# Absolute minimum followers (applies when percentage calculation yields 0 or too small)
FOLLOWER_ABSOLUTE_MINIMUMS = {
    "small": 0,
    "medium": 1,
    "big": 10,
    "top": 100
}

# =============================================================================
# FOLLOWING COUNT RANGES (as % of total users)
# =============================================================================

# Following counts are typically lower and less variable than follower counts
# Format: (min_percentage, max_percentage)
FOLLOWING_RATIOS = {
    "small": (0.002, 0.01),     # 0.2% to 1% of total users
    "medium": (0.002, 0.01),    # 0.2% to 1% of total users
    "big": (0.001, 0.005),      # 0.1% to 0.5% of total users
    "top": (0.001, 0.005)       # 0.1% to 0.5% of total users
}

# Absolute minimum following counts
FOLLOWING_ABSOLUTE_MINIMUMS = {
    "small": 1,
    "medium": 1,
    "big": 0,
    "top": 0
}

# Absolute maximum following counts (upper bounds regardless of user count)
FOLLOWING_ABSOLUTE_MAXIMUMS = {
    "small": 1000,
    "medium": 1000,
    "big": 500,
    "top": 500
}

# =============================================================================
# RELATIONSHIP GENERATION WEIGHTS
# =============================================================================

# Weights for weighted random selection when generating followers
# Higher weight = more likely to be chosen as a followee (rich-get-richer effect)
TIER_WEIGHTS = {
    "small": 1,
    "medium": 3,
    "big": 10,
    "top": 50
}

# =============================================================================
# RANDOM SEED SETTINGS
# =============================================================================

# Fixed seed for user segmentation (ensures consistent tier assignments across runs)
# Set to None for truly random segmentation each time
SEGMENTATION_SEED = 42

# =============================================================================
# PERFORMANCE TUNING
# =============================================================================

# Maximum attempts when trying to find unique followees for a user
MAX_FOLLOWEE_SELECTION_ATTEMPTS = 5

# Maximum number of consecutive empty batches before stopping user scan (for gRPC validation)
MAX_CONSECUTIVE_EMPTY_BATCHES = 5

# Batch size for gRPC BatchGetUserInfo calls
GRPC_BATCH_SIZE = 100

# =============================================================================
# VALIDATION SETTINGS
# =============================================================================

# Whether to validate ranges at runtime
VALIDATE_RANGES = True

# Ensure all tier percentages sum to approximately 1.0
def validate_config():
    """Validate configuration values"""
    if VALIDATE_RANGES:
        total_ratio = sum(USER_TIER_RATIOS.values())
        if not (0.99 <= total_ratio <= 1.01):
            raise ValueError(f"USER_TIER_RATIOS must sum to ~1.0, got {total_ratio}")
        
        # Check all tiers are defined
        required_tiers = {"small", "medium", "big", "top"}
        for config_dict in [USER_TIER_RATIOS, FOLLOWER_RATIOS, FOLLOWING_RATIOS, 
                           TIER_WEIGHTS, FOLLOWER_ABSOLUTE_MINIMUMS, 
                           FOLLOWING_ABSOLUTE_MINIMUMS]:
            if set(config_dict.keys()) != required_tiers:
                raise ValueError(f"All configs must define all tiers: {required_tiers}")

# Validate on import
validate_config()

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def get_tier_names():
    """Get list of all tier names"""
    return list(USER_TIER_RATIOS.keys())

def print_config_summary():
    """Print a summary of current configuration"""
    print("\n" + "=" * 80)
    print("Social Graph Generation Configuration")
    print("=" * 80)
    
    print("\n📊 User Tier Ratios:")
    for tier, ratio in USER_TIER_RATIOS.items():
        print(f"  {tier.capitalize():<10} {ratio*100:>6.2f}%")
    
    print("\n👥 Follower Ratios (% of total users):")
    for tier in get_tier_names():
        min_pct, max_pct = FOLLOWER_RATIOS[tier]
        abs_min = FOLLOWER_ABSOLUTE_MINIMUMS[tier]
        print(f"  {tier.capitalize():<10} {min_pct*100:>6.2f}% - {max_pct*100:>6.2f}%  (min: {abs_min})")
    
    print("\n🔗 Following Ratios (% of total users):")
    for tier in get_tier_names():
        min_pct, max_pct = FOLLOWING_RATIOS[tier]
        abs_min = FOLLOWING_ABSOLUTE_MINIMUMS[tier]
        abs_max = FOLLOWING_ABSOLUTE_MAXIMUMS[tier]
        print(f"  {tier.capitalize():<10} {min_pct*100:>6.2f}% - {max_pct*100:>6.2f}%  (min: {abs_min}, max: {abs_max})")
    
    print("\n⚖️  Tier Weights (for follower selection):")
    for tier, weight in TIER_WEIGHTS.items():
        print(f"  {tier.capitalize():<10} {weight:>6}")
    
    print("\n🎲 Random Seed:")
    print(f"  Segmentation: {SEGMENTATION_SEED}")
    
    print("=" * 80 + "\n")


if __name__ == "__main__":
    # Print config when run directly
    print_config_summary()
