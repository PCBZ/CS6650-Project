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
# Aligned with Locust test expectations: Regular (85%), Influencer (14%), Celebrity (1%)
USER_TIER_RATIOS = {
    "small": 0.85,      # 85% - Regular users (10-100 followers)
    "medium": 0.14,     # 14% - Influencers (100-50,000 followers)
    "big": 0.01,        # 1% - Celebrities (50,000+ followers)
    "top": 0.0          # 0% - Not used (merged into big tier)
}

# =============================================================================
# FOLLOWER COUNT RANGES (as % of total users)
# =============================================================================

# Min and max followers for each tier, expressed as percentages of total user base
# Format: (min_percentage, max_percentage)
# Aligned with Locust expectations:
#   - Regular: 10-100 followers
#   - Influencer: 100-50,000 followers  
#   - Celebrity: 50,000-500,000 followers
FOLLOWER_RATIOS = {
    "small": (0.0002, 0.02),    # 0.02% to 2% of total users (10-100 for 5K, 20-200 for 10K, 200-2000 for 100K)
    "medium": (0.02, 0.50),     # 2% to 50% of total users (100-2500 for 5K, 200-5000 for 10K, 2K-50K for 100K)
    "big": (0.50, 5.0),         # 50% to 500% of total users (2.5K-25K for 5K, 5K-50K for 10K, 50K-500K for 100K)
    "top": (0.0, 0.0)           # Not used
}

# Absolute minimum followers (applies when percentage calculation yields 0 or too small)
FOLLOWER_ABSOLUTE_MINIMUMS = {
    "small": 10,        # Regular users: at least 10 followers
    "medium": 100,      # Influencers: at least 100 followers
    "big": 50000,       # Celebrities: at least 50,000 followers
    "top": 0            # Not used
}

# =============================================================================
# FOLLOWING COUNT RANGES (as % of total users)
# =============================================================================

# Following counts are typically lower and less variable than follower counts
# Format: (min_percentage, max_percentage)
# Aligned with Locust expectations:
#   - Regular: 50-200 following
#   - Influencer: 100-500 following
#   - Celebrity: 50-200 following
FOLLOWING_RATIOS = {
    "small": (0.01, 0.04),      # 1% to 4% of total users (50-200 for 5K, 100-400 for 10K, 1K-4K for 100K)
    "medium": (0.02, 0.10),     # 2% to 10% of total users (100-500 for 5K, 200-1000 for 10K, 2K-10K for 100K)
    "big": (0.001, 0.004),      # 0.1% to 0.4% of total users (50-200 for 5K, 100-400 for 10K, 1K-4K for 100K)
    "top": (0.0, 0.0)           # Not used
}

# Absolute minimum following counts
FOLLOWING_ABSOLUTE_MINIMUMS = {
    "small": 50,        # Regular users: at least 50 following
    "medium": 100,      # Influencers: at least 100 following
    "big": 50,          # Celebrities: at least 50 following
    "top": 0            # Not used
}

# Absolute maximum following counts (upper bounds regardless of user count)
FOLLOWING_ABSOLUTE_MAXIMUMS = {
    "small": 200,       # Regular users: at most 200 following
    "medium": 500,      # Influencers: at most 500 following
    "big": 200,         # Celebrities: at most 200 following
    "top": 0            # Not used
}

# =============================================================================
# RELATIONSHIP GENERATION WEIGHTS
# =============================================================================

# Weights for weighted random selection when generating followers
# Higher weight = more likely to be chosen as a followee (rich-get-richer effect)
TIER_WEIGHTS = {
    "small": 1,         # Regular users: low weight
    "medium": 5,        # Influencers: medium weight
    "big": 50,          # Celebrities: very high weight (rich-get-richer)
    "top": 0            # Not used
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
