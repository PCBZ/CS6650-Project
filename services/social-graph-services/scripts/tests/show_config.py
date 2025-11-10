#!/usr/bin/env python3
"""
Display current social graph generation configuration
"""

import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from core import config

if __name__ == "__main__":
    config.print_config_summary()
