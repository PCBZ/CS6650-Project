import os
import sys
import random
import statistics

# Ensure the scripts directory is importable
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from generate_test_local import (
    generate_test_users,
    UserSegmentation,
    RelationshipGenerator,
)


def run_generator(num_users: int, seed: int = 42, verbose: bool = False):
    """Helper to run the generation pipeline deterministically."""
    random.seed(seed)
    user_ids = generate_test_users(num_users)
    segmentation = UserSegmentation(len(user_ids))
    segments = segmentation.segment_users(user_ids)
    gen = RelationshipGenerator(segments, segmentation, verbose=verbose)
    gen.generate_followers_first()
    gen.enforce_following_limits()
    gen.ensure_minimum_followers()
    return segmentation, segments, gen


def test_segmentation_counts():
    """Check segment sizes add up and match the segmentation object."""
    num_users = 5000
    segmentation, segments, _ = run_generator(num_users, seed=42)

    assert sum(len(v) for v in segments.values()) == num_users
    assert len(segments["small"]) == segmentation.small_count
    assert len(segments["medium"]) == segmentation.medium_count
    assert len(segments["big"]) == segmentation.big_count
    assert len(segments["top"]) == segmentation.top_count


def test_no_self_follow_and_ranges():
    """Ensure no user follows themselves and follower counts are within effective ranges."""
    num_users = 1000
    segmentation, segments, gen = run_generator(num_users, seed=1)

    # No self-follow pairs
    assert all(follower != followee for (follower, followee) in gen.relationships)

    # For each user in each segment, follower count should be >= min and <= effective max
    for user_type, users in segments.items():
        fmin, fmax = segmentation.get_follower_range(user_type)
        effective_max = min(fmax, num_users - 1)

        for uid in users:
            count = len(gen.follower_map[uid])
            # Only enforce the theoretical minimum when it's feasible given total users
            if fmin <= num_users - 1:
                assert count >= fmin, f"User {uid} in {user_type} has {count} followers (<{fmin})"

            assert count <= effective_max, f"User {uid} in {user_type} has {count} followers (>{effective_max})"


def test_stddev_and_powerlaw():
    """Compute stddev of follower counts and a simple top-percentile power-law check."""
    num_users = 5000
    segmentation, segments, gen = run_generator(num_users, seed=42)

    all_user_ids = [uid for users in segments.values() for uid in users]
    follower_counts = [len(gen.follower_map[uid]) for uid in all_user_ids]

    # Standard deviation should be positive
    stddev = statistics.pstdev(follower_counts)
    assert stddev > 0

    # Simple power-law check: top 10% of users hold a significant fraction of followers
    total_followers = sum(follower_counts)
    sorted_counts = sorted(follower_counts, reverse=True)
    top_n = max(1, int(0.10 * len(sorted_counts)))
    fraction_top = sum(sorted_counts[:top_n]) / total_followers if total_followers > 0 else 0

    # Expectation: top 10% hold a substantial share; threshold chosen conservatively
    assert fraction_top >= 0.35, f"Top 10% hold only {fraction_top:.2f} of followers; expected >= 0.35"
