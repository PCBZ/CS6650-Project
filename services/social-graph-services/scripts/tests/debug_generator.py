import sys
import os

# Add parent directory (scripts) to path so we can import core modules
script_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(script_dir)
sys.path.insert(0, parent_dir)

from core.segmenter import UserSegmentation
from core.generator import RelationshipGenerator

# Create segmentation
seg = UserSegmentation(5000)
ids = list(range(1, 5001))
segments = seg.segment_users(ids)

print("Segment distribution:")
for tier, users in segments.items():
    print(f"  {tier}: {len(users)} users")
    if tier == "top":
        print(f"    Top user ID: {users}")

# Generate relationships
gen = RelationshipGenerator(segments, seg, verbose=True)
gen.generate_followers_first()

# Check top user before ensure_minimum_followers
top_user = segments["top"][0]
print(f"\n🔍 Before ensure_minimum_followers:")
print(f"  Top user {top_user} has {len(gen.follower_map[top_user])} followers")

# Run ensure_minimum_followers
gen.ensure_minimum_followers()

# Check top user after
print(f"\n🔍 After ensure_minimum_followers:")
print(f"  Top user {top_user} has {len(gen.follower_map[top_user])} followers")
print(f"  Sample followers: {list(gen.follower_map[top_user])[:10]}")

# Check user_tier mapping
print(f"\n🔍 User tier mapping:")
print(f"  gen.user_tier[{top_user}] = {gen.user_tier.get(top_user, 'NOT FOUND')}")

# Check targets
targets = {"small": 1, "medium": 100, "big": 500, "top": 2000}
print(f"\n🔍 Expected targets:")
for tier, target in targets.items():
    sample_user = segments[tier][0] if segments[tier] else None
    if sample_user:
        actual = len(gen.follower_map[sample_user])
        print(f"  {tier}: expected={target}, actual={actual}, match={'✅' if actual == target else '❌'}")
