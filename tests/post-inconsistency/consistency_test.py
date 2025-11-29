#!/usr/bin/env python3
"""
Simple Post Inconsistency Test
Uses HTTP requests (no gRPC needed in test)
"""

import argparse
import json
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Dict, List, Optional

import requests


class SimpleConsistencyTest:
    def __init__(self, post_service_url: str, timeline_service_url: str, timeline_limit: Optional[int] = None):
        """Initialize with HTTP endpoints"""
        self.post_url = post_service_url
        self.timeline_url = timeline_service_url
        self.timeline_limit = timeline_limit if timeline_limit and timeline_limit > 0 else None
    
    def run_test(
        self,
        author_id: int,
        follower_id: int,
        num_posts: int,
        strategy: str,
        output_file: Optional[str] = None,
        concurrency: int = 1,
    ):
        """
        Run the simple consistency test
        
        Args:
            author_id: User creating posts
            follower_id: User following the author (will check their timeline)
            num_posts: Number of posts to create (e.g., 10000)
            strategy: 'push' or 'pull'
        """
        print(f"\n{'='*60}")
        print(f"Simple Consistency Test - {strategy.upper()} Strategy")
        print(f"{'='*60}")
        print(f"Author: User {author_id}")
        print(f"Follower: User {follower_id}")
        print(f"Posts to create: {num_posts}")
        print()
        
        # Step 1: Create posts
        print(f"Step 1: Creating {num_posts} posts (concurrency={concurrency})...")
        created_posts = self.create_posts(author_id, num_posts, concurrency)
        created_post_ids = [p['post_id'] for p in created_posts if p.get('post_id')]
        print(f"✓ Created {len(created_post_ids)} posts")
        if created_post_ids:
            print(f"   Post IDs: {created_post_ids[0]} to {created_post_ids[-1]}")
        
        # Step 2: Immediately retrieve follower's timeline
        print(f"\nStep 2: Checking User {follower_id}'s timeline...")
        comparison_window = self._get_comparison_window(len(created_posts))
        if comparison_window is not None:
            print(f"   (Comparing against the most recent {comparison_window} created posts)")
        retrieved_posts = self.get_timeline_posts(follower_id, author_id, comparison_window)
        print(f"✓ Retrieved {len(retrieved_posts)} posts from timeline")
        
        # Step 3: Calculate inconsistency
        print(f"\nStep 3: Calculating inconsistency...")
        relevant_created = self._select_recent_posts(created_posts, comparison_window)
        missing_posts = self.find_missing_posts(relevant_created, retrieved_posts)
        
        total_created = len(created_post_ids)
        inconsistency_ratio = (len(missing_posts) / total_created * 100) if total_created else 0.0
        consistency_ratio = 100 - inconsistency_ratio
        
        # Print results
        print(f"\n{'='*60}")
        print(f"RESULTS")
        print(f"{'='*60}")
        print(f"Total posts created:     {len(created_post_ids)}")
        print(f"Posts in timeline:       {len(retrieved_posts)}")
        print(f"Missing posts (content match): {len(missing_posts)}")
        print(f"Consistency ratio:       {consistency_ratio:.2f}%")
        print(f"Inconsistency ratio:     {inconsistency_ratio:.2f}%")
        
        if missing_posts:
            print(f"\nMissing post IDs (first 10): {missing_posts[:10]}")
            if len(missing_posts) > 10:
                print(f"... and {len(missing_posts) - 10} more")
        else:
            print(f"\n✓ All posts present! 100% consistency achieved.")
        
        print(f"{'='*60}\n")
        
        result = {
            'strategy': strategy,
            'author_id': author_id,
            'follower_id': follower_id,
            'total_posts': len(created_post_ids),
            'retrieved_posts': len(retrieved_posts),
            'missing_posts': len(missing_posts),
            'consistency_ratio': consistency_ratio,
            'inconsistency_ratio': inconsistency_ratio,
            'missing_contents': missing_posts,
            'comparison_window': comparison_window or len(created_post_ids),
        }

        self.save_results(result, output_file)

        return result
    
    def create_posts(self, author_id: int, num_posts: int, concurrency: int) -> List[Dict[str, str]]:
        """
        Create posts via HTTP POST requests
        
        Returns list of created post IDs
        """
        results: List[Dict[str, str]] = []
        start_time = time.time()
        completed = 0
        concurrency = max(1, concurrency)
        
        def send_post(i: int):
            payload = {
                "user_id": author_id,
                "content": f"Test post #{2000+i}",
            }
            try:
                response = requests.post(
                    f"{self.post_url}/api/posts",
                    json=payload,
                    timeout=10
                )
                try:
                    data = response.json()
                except ValueError:
                    data = {}
                return i, response.status_code, data, payload["content"], None
            except requests.RequestException as exc:
                return i, None, None, payload["content"], str(exc)

        with ThreadPoolExecutor(max_workers=concurrency) as executor:
            for i, status, data, content, error in executor.map(send_post, range(1, num_posts + 1)):
                completed += 1

                if status == 200 and isinstance(data, dict):
                    post_id = self._extract_post_id(data)
                    if post_id:
                        results.append({"post_id": post_id, "content": content})
                    else:
                        print(f"   ✗ Response missing post_id for post {i}: {data}")
                elif status is not None:
                    print(f"   ✗ Error creating post {i}: Status {status}")
                else:
                    print(f"   ✗ Error creating post {i}: {error}")

                if completed % 1000 == 0:
                    elapsed = time.time() - start_time
                    rate = completed / elapsed if elapsed > 0 else 0
                    print(f"   Progress: {completed}/{num_posts} ({rate:.1f} posts/sec)")
        
        elapsed = time.time() - start_time
        rate = len(results) / elapsed if elapsed > 0 else 0
        print(f"   Total time: {elapsed:.2f} seconds ({rate:.1f} posts/sec)")
        
        return results
    
    def get_timeline_posts(self, follower_id: int, author_id: int, limit_hint: Optional[int]) -> List[Dict[str, str]]:
        """
        Get follower's timeline via HTTP GET and extract posts from the author
        
        Returns list of post IDs from author
        """
        try:
            # HTTP GET to retrieve timeline
            params = {}
            if self.timeline_limit:
                params["limit"] = self.timeline_limit
            elif limit_hint:
                params["limit"] = limit_hint
            response = requests.get(
                f"{self.timeline_url}/api/timeline/{follower_id}",
                params=params or {"limit": 15000},  # Ensure we ask for enough posts
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                posts = data.get('posts') or data.get('timeline') or []

                if not posts:
                    preview = json.dumps(data)[:300]
                    print("   ! Timeline returned 0 posts; raw response snippet:")
                    print(f"     {preview}")

                author_posts = [
                    {
                        'post_id': post.get('post_id'),
                        'content': post.get('content'),
                        'user_id': post.get('user_id'),
                        'author_id': post.get('author_id'),
                    }
                    for post in posts
                    if (
                        post.get('author_id') == author_id
                        or post.get('user_id') == author_id
                    )
                ]

                if not author_posts:
                    print("   ! No posts from author found in timeline response")

                return author_posts
            else:
                print(f"   ✗ Error getting timeline: Status {response.status_code}")
                print(f"     Response: {response.text[:200]}")
                return []
            
        except requests.RequestException as e:
            print(f"   ✗ Error getting timeline: {e}")
            return []
    
    def find_missing_posts(
        self,
        created: List[Dict[str, str]],
        retrieved: List[Dict[str, str]]
    ) -> List[str]:
        """
        Find missing posts using content as the identifier.
        """
        created_contents = {p['content'] for p in created if p.get('content')}
        retrieved_contents = {p['content'] for p in retrieved if p.get('content')}

        return sorted(created_contents - retrieved_contents)

    def _get_comparison_window(self, total_created: int) -> Optional[int]:
        """
        Determine how many of the newest posts can realistically show up in the timeline.
        """
        if not total_created:
            return None
        if self.timeline_limit:
            return min(total_created, self.timeline_limit)
        return total_created

    def _select_recent_posts(
        self,
        created: List[Dict[str, str]],
        window: Optional[int]
    ) -> List[Dict[str, str]]:
        if not window or window >= len(created):
            return created
        return created[-window:]

    @staticmethod
    def _extract_post_id(data: Dict) -> Optional[str]:
        """Handle multiple response shapes from post-service."""
        if not isinstance(data, dict):
            return None
        if 'post_id' in data:
            return data['post_id']
        post_obj = data.get('post')
        if isinstance(post_obj, dict):
            return post_obj.get('post_id')
        return None

    def save_results(self, result: dict, output_file: Optional[str]) -> None:
        """Persist results to disk for later inspection."""
        target = output_file or f"consistency_result_{result['strategy']}_{int(time.time())}.json"
        try:
            path = Path(target).expanduser().resolve()
            path.write_text(json.dumps(result, indent=2))
            print(f"\nResults written to {path}")
        except OSError as exc:
            print(f"\n✗ Failed to write results to {target}: {exc}")


def main():
    parser = argparse.ArgumentParser(description='Simple Post Inconsistency Test')
    parser.add_argument('--strategy', type=str, required=True, 
                        choices=['push', 'pull'],
                        help='Fan-out strategy to test')
    parser.add_argument('--author-id', type=int, default=1001,
                        help='Author user ID (who creates posts)')
    parser.add_argument('--follower-id', type=int, default=2001,
                        help='Follower user ID (who views timeline)')
    parser.add_argument('--posts', type=int, default=10000,
                        help='Number of posts to create')
    parser.add_argument('--post-service', type=str, default='http://localhost:8080',
                        help='Post service URL')
    parser.add_argument('--timeline-service', type=str, default='http://localhost:8081',
                        help='Timeline service URL')
    parser.add_argument('--output-file', type=str, default=None,
                        help='Optional path to save JSON results')
    parser.add_argument('--concurrency', type=int, default=1,
                        help='Number of concurrent post creations')
    parser.add_argument('--timeline-limit', type=int, default=50,
                        help='Timeline API limit (most deployments cap at 50)')
    
    args = parser.parse_args()
    
    print(f"\nNote: Make sure User {args.author_id} has correct follower count for {args.strategy} strategy:")
    print(f"  - Push strategy: User should have < 10,000 followers")
    print(f"  - Pull strategy: User should have >= 10,000 followers")
    print(f"  - User {args.follower_id} should be following User {args.author_id}")
    
    # Run test
    tester = SimpleConsistencyTest(
        args.post_service,
        args.timeline_service,
        timeline_limit=args.timeline_limit
    )
    
    result = tester.run_test(
        author_id=args.author_id,
        follower_id=args.follower_id,
        num_posts=args.posts,
        strategy=args.strategy,
        output_file=args.output_file,
        concurrency=args.concurrency,
    )
    
    # Return exit code based on consistency
    if result['consistency_ratio'] == 100.0:
        exit(0)  # Success
    else:
        exit(1)  # Some posts missing


if __name__ == '__main__':
    main()
