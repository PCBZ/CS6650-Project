#!/usr/bin/env python3
"""
Timeline Service End-to-End Test Suite

This script validates the complete timeline feature workflow:
    1. User creation and authentication
    2. Social graph relationship establishment
    3. Content publication
    4. Timeline aggregation and retrieval

Author: CS6650 Project Team
Version: 1.0.0
"""

import sys
import json
import time
import logging
import random
import string
import os
import subprocess
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, Any, Optional, Tuple
from enum import Enum

try:
    import requests
except ImportError:
    print("Error: requests library not found. Install it with: pip install requests")
    sys.exit(1)


# ============================================================================
# Configuration
# ============================================================================

def get_alb_url_from_terraform() -> str:
    """
    Get ALB URL from Terraform output or environment variable
    
    Priority:
    1. Environment variable ALB_URL
    2. Terraform output (terraform output -raw alb_dns_name)
    3. Fallback to hardcoded URL
    """
    # Try environment variable first
    alb_url = os.environ.get('ALB_URL')
    if alb_url:
        return alb_url
    
    # Try Terraform output
    try:
        # Get the project root (parent of scripts directory)
        current_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(current_dir)
        terraform_dir = os.path.join(project_root, 'terraform')
        
        if os.path.exists(terraform_dir):
            result = subprocess.run(
                ['terraform', 'output', '-raw', 'alb_dns_name'],
                cwd=terraform_dir,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0 and result.stdout.strip():
                alb_dns = result.stdout.strip()
                return f"http://{alb_dns}"
    except Exception:
        pass
    
    # Fallback to hardcoded URL
    return "http://cs6650-project-dev-alb-2009030594.us-west-2.elb.amazonaws.com"

@dataclass
class APIConfig:
    """API endpoint configuration"""
    base_url: str = get_alb_url_from_terraform()
    
    @property
    def users(self) -> str:
        return f"{self.base_url}/api/users"
    
    @property
    def follow(self) -> str:
        return f"{self.base_url}/api/social-graph/follow"
    
    @property
    def posts(self) -> str:
        return f"{self.base_url}/api/posts"
    
    @property
    def timeline(self) -> str:
        return f"{self.base_url}/api/timeline"


class TestResult(Enum):
    """Test execution result codes"""
    SUCCESS = 0
    WARNING = 2
    FAILURE = 1
    INTERRUPTED = 130


class Colors:
    """ANSI color codes for terminal output"""
    GREEN = '\033[0;32m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    BOLD = '\033[1m'
    NC = '\033[0m'


# ============================================================================
# Logging Setup
# ============================================================================

class ColoredFormatter(logging.Formatter):
    """Custom formatter with colored output"""
    
    FORMATS = {
        logging.DEBUG: Colors.CYAN + "%(message)s" + Colors.NC,
        logging.INFO: "%(message)s",
        logging.WARNING: Colors.YELLOW + "%(message)s" + Colors.NC,
        logging.ERROR: Colors.RED + "%(message)s" + Colors.NC,
    }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno, "%(message)s")
        formatter = logging.Formatter(log_fmt)
        return formatter.format(record)


def setup_logger() -> logging.Logger:
    """Configure and return logger instance"""
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)
    
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(ColoredFormatter())
    logger.addHandler(handler)
    
    return logger


logger = setup_logger()


# ============================================================================
# Output Utilities
# ============================================================================

def print_section(title: str, char: str = "=", width: int = 60) -> None:
    """Print a formatted section header"""
    print(f"\n{Colors.BLUE}{Colors.BOLD}{char * width}{Colors.NC}")
    print(f"{Colors.BLUE}{Colors.BOLD}{title.center(width)}{Colors.NC}")
    print(f"{Colors.BLUE}{Colors.BOLD}{char * width}{Colors.NC}\n")


def print_step(step_num: int, description: str) -> None:
    """Print a test step header"""
    print(f"\n{Colors.CYAN}{Colors.BOLD}[Step {step_num}]{Colors.NC} {description}")


def print_result(success: bool, message: str) -> None:
    """Print a result message with appropriate formatting"""
    icon = "✅" if success else "❌"
    color = Colors.GREEN if success else Colors.RED
    print(f"{color}{icon} {message}{Colors.NC}")


def print_warning(message: str) -> None:
    """Print a warning message"""
    print(f"{Colors.YELLOW}⚠️  {message}{Colors.NC}")


def print_detail(label: str, value: Any, indent: int = 3) -> None:
    """Print a detailed information line"""
    spacing = " " * indent
    print(f"{spacing}{Colors.CYAN}{label}:{Colors.NC} {value}")


def print_json_response(data: Dict[Any, Any], indent: int = 3) -> None:
    """Pretty print JSON response with indentation"""
    spacing = " " * indent
    json_str = json.dumps(data, indent=2)
    for line in json_str.split('\n'):
        print(f"{spacing}{line}")


# ============================================================================
# Utility Functions
# ============================================================================

def generate_random_username(prefix: str = "user", length: int = 8) -> str:
    """
    Generate a random username
    
    Args:
        prefix: Prefix for the username
        length: Length of random suffix
        
    Returns:
        Random username string
    """
    random_suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))
    return f"{prefix}_{random_suffix}"


# ============================================================================
# API Client
# ============================================================================

class TimelineAPIClient:
    """Client for interacting with timeline service APIs"""
    
    def __init__(self, config: APIConfig, timeout: int = 10):
        self.config = config
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({"Content-Type": "application/json"})
    
    def _make_request(
        self, 
        method: str, 
        url: str, 
        **kwargs
    ) -> Tuple[bool, Optional[Dict[Any, Any]], Optional[str]]:
        """
        Make HTTP request with error handling
        
        Returns:
            Tuple of (success, response_data, error_message)
        """
        try:
            response = self.session.request(
                method, 
                url, 
                timeout=self.timeout, 
                **kwargs
            )
            response.raise_for_status()
            return True, response.json(), None
        except requests.exceptions.Timeout:
            return False, None, "Request timed out"
        except requests.exceptions.ConnectionError:
            return False, None, "Connection failed"
        except requests.exceptions.HTTPError as e:
            error_msg = f"HTTP {e.response.status_code}: {e.response.text}"
            return False, None, error_msg
        except requests.exceptions.RequestException as e:
            return False, None, str(e)
        except json.JSONDecodeError:
            return False, None, "Invalid JSON response"
    
    def create_user(self, username: str) -> Tuple[bool, Optional[int], Optional[Dict]]:
        """Create a new user"""
        success, data, error = self._make_request(
            "POST",
            self.config.users,
            json={"username": username}
        )
        
        if success and data and 'user_id' in data:
            return True, data['user_id'], data
        return False, None, data or {"error": error}
    
    def create_follow(
        self, 
        follower_id: int, 
        target_id: int
    ) -> Tuple[bool, Optional[Dict]]:
        """Establish follow relationship"""
        success, data, error = self._make_request(
            "POST",
            self.config.follow,
            json={
                "follower_user_id": str(follower_id),
                "target_user_id": str(target_id),
                "action": "follow"
            }
        )
        
        if success and data and 'follower_id' in data:
            return True, data
        return False, data or {"error": error}
    
    def create_post(
        self, 
        user_id: int, 
        content: str
    ) -> Tuple[bool, Optional[Any], Optional[Dict]]:
        """Create a new post"""
        success, data, error = self._make_request(
            "POST",
            self.config.posts,
            json={"user_id": user_id, "content": content}
        )
        
        if success and data and 'post' in data:
            post_id = data['post'].get('post_id')
            return True, post_id, data
        return False, None, data or {"error": error}
    
    def get_timeline(self, user_id: int) -> Tuple[bool, Optional[Dict]]:
        """Fetch user timeline"""
        success, data, error = self._make_request(
            "GET",
            f"{self.config.timeline}/{user_id}"
        )
        
        if success and data:
            return True, data
        return False, data or {"error": error}
    
    def close(self):
        """Close the session"""
        self.session.close()


# ============================================================================
# Test Validation
# ============================================================================

@dataclass
class ValidationResult:
    """Validation result container"""
    passed: bool
    warnings: list
    details: Dict[str, Any]


class TimelineValidator:
    """Validates timeline API responses"""
    
    @staticmethod
    def validate_timeline(
        timeline_data: Dict[Any, Any], 
        expected_author_id: int
    ) -> ValidationResult:
        """
        Validate timeline response structure and content
        
        Args:
            timeline_data: Timeline API response
            expected_author_id: Expected author ID for validation
            
        Returns:
            ValidationResult with pass/fail status and details
        """
        warnings = []
        details = {}
        
        total_count = timeline_data.get('total_count', 0)
        timeline = timeline_data.get('timeline', [])
        
        details['total_posts'] = total_count
        
        # Check if timeline has posts
        if total_count < 1:
            return ValidationResult(
                passed=False,
                warnings=["Timeline is empty (expected at least 1 post)"],
                details=details
            )
        
        # Validate first post
        if len(timeline) > 0:
            first_post = timeline[0]
            post_id = first_post.get('post_id')
            author_id = first_post.get('author_id')
            content = first_post.get('content', '')
            
            details['first_post'] = {
                'post_id': post_id,
                'author_id': author_id,
                'content': content[:50] + "..." if len(content) > 50 else content
            }
            
            # Validate post_id
            if post_id in [0, "0", None, "null"]:
                warnings.append("post_id is 0 or null (data mapping issue)")
            
            # Validate author_id
            if author_id == expected_author_id:
                details['author_id_valid'] = True
            elif author_id in [0, None]:
                warnings.append("author_id is 0 or null (data mapping issue)")
                details['author_id_valid'] = False
            else:
                warnings.append(
                    f"author_id mismatch (expected: {expected_author_id}, got: {author_id})"
                )
                details['author_id_valid'] = False
        
        passed = len(warnings) == 0
        return ValidationResult(passed=passed, warnings=warnings, details=details)


# ============================================================================
# Test Orchestration
# ============================================================================

class TimelineTestSuite:
    """End-to-end test suite for timeline service"""
    
    def __init__(self, config: APIConfig):
        self.config = config
        self.client = TimelineAPIClient(config)
        self.validator = TimelineValidator()
    
    def run(self) -> TestResult:
        """Execute the complete test suite"""
        print_section("Timeline Service E2E Test Suite")
        
        try:
            # Step 1: Create users
            user_a_id, user_b_id = self._test_user_creation()
            
            # Step 2: Establish follow relationship
            self._test_follow_relationship(user_a_id, user_b_id)
            
            # Step 3: Create post
            post_id = self._test_post_creation(user_b_id)
            
            # Step 4: Fetch and validate timeline
            result = self._test_timeline_retrieval(user_a_id, user_b_id)
            
            # Print summary
            self._print_summary(user_a_id, user_b_id, post_id, result)
            
            return TestResult.SUCCESS if result.passed else TestResult.WARNING
            
        except KeyboardInterrupt:
            print(f"\n{Colors.YELLOW}Test interrupted by user{Colors.NC}")
            return TestResult.INTERRUPTED
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            import traceback
            traceback.print_exc()
            return TestResult.FAILURE
        finally:
            self.client.close()
    
    def _test_user_creation(self) -> Tuple[int, int]:
        """Test user creation"""
        print_step(1, "Creating test users...")
        
        # Generate random usernames
        username_a = generate_random_username("test_user_a")
        username_b = generate_random_username("test_user_b")
        
        # Create User A
        success, user_a_id, data = self.client.create_user(username_a)
        if not success:
            print_result(False, f"Failed to create User A: {data}")
            sys.exit(TestResult.FAILURE.value)
        
        print_result(True, f"User A created (ID: {user_a_id}, username: {username_a})")
        print_json_response(data)
        
        # Create User B
        success, user_b_id, data = self.client.create_user(username_b)
        if not success:
            print_result(False, f"Failed to create User B: {data}")
            sys.exit(TestResult.FAILURE.value)
        
        print_result(True, f"User B created (ID: {user_b_id}, username: {username_b})")
        print_json_response(data)
        
        return user_a_id, user_b_id
    
    def _test_follow_relationship(self, follower_id: int, target_id: int) -> None:
        """Test follow relationship creation"""
        print_step(2, f"Establishing follow relationship (A→B)...")
        
        success, data = self.client.create_follow(follower_id, target_id)
        if not success:
            print_result(False, f"Failed to create follow: {data}")
            sys.exit(TestResult.FAILURE.value)
        
        print_result(True, f"User A now follows User B")
        print_json_response(data)
    
    def _test_post_creation(self, author_id: int) -> Any:
        """Test post creation"""
        print_step(3, f"Creating post by User B...")
        
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        content = f"Hello from User B! Test post created at {timestamp}"
        
        success, post_id, data = self.client.create_post(author_id, content)
        if not success:
            print_result(False, f"Failed to create post: {data}")
            sys.exit(TestResult.FAILURE.value)
        
        print_result(True, f"Post created (ID: {post_id})")
        print_json_response(data)
        
        # Wait for indexing
        print(f"\n{Colors.CYAN}⏳ Waiting 2s for post indexing...{Colors.NC}")
        time.sleep(2)
        
        return post_id
    
    def _test_timeline_retrieval(
        self, 
        user_id: int, 
        expected_author_id: int
    ) -> ValidationResult:
        """Test timeline retrieval and validation"""
        print_step(4, f"Fetching timeline for User A...")
        
        success, data = self.client.get_timeline(user_id)
        if not success:
            print_result(False, f"Failed to fetch timeline: {data}")
            sys.exit(TestResult.FAILURE.value)
        
        total = data.get('total_count', 0)
        print_result(True, f"Timeline retrieved ({total} post(s))")
        print_json_response(data)
        
        # Validate
        print_section("Validation Results", "─", 60)
        result = self.validator.validate_timeline(data, expected_author_id)
        
        if result.passed:
            print_result(True, "All validations passed")
        else:
            print_warning("Validation completed with warnings:")
            for warning in result.warnings:
                print(f"   • {warning}")
        
        print("\n" + Colors.CYAN + "Details:" + Colors.NC)
        for key, value in result.details.items():
            if isinstance(value, dict):
                print_detail(key, "")
                for k, v in value.items():
                    print_detail(f"  {k}", v, indent=5)
            else:
                print_detail(key, value)
        
        return result
    
    def _print_summary(
        self, 
        user_a_id: int, 
        user_b_id: int, 
        post_id: Any,
        result: ValidationResult
    ) -> None:
        """Print test summary"""
        print_section("Test Summary", "=", 60)
        
        if result.passed:
            print(f"{Colors.GREEN}{Colors.BOLD}✅ All Tests Passed{Colors.NC}\n")
        else:
            print(f"{Colors.YELLOW}{Colors.BOLD}⚠️  Tests Completed with Warnings{Colors.NC}\n")
        
        print_detail("User A ID", user_a_id, indent=0)
        print_detail("User B ID", user_b_id, indent=0)
        print_detail("Post ID", post_id, indent=0)
        print_detail("Timeline Posts", result.details.get('total_posts', 0), indent=0)
        print_detail("Validation Status", "PASS" if result.passed else "WARNING", indent=0)
        print()


# ============================================================================
# Main Entry Point
# ============================================================================

def main():
    """Main entry point"""
    config = APIConfig()
    suite = TimelineTestSuite(config)
    result = suite.run()
    sys.exit(result.value)


if __name__ == "__main__":
    main()
