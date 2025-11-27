#!/usr/bin/env python3
"""
Compare storage metrics across different fan-out strategies.

Usage:
    python3 compare_strategies.py \
        --push results/storage_metrics_5K_push.json \
        --pull results/storage_metrics_5K_pull.json \
        --hybrid results/storage_metrics_5K_hybrid.json \
        --output results/comparison_5K.txt
"""

import json
import argparse
from typing import Dict, Optional


def load_metrics(filepath: str) -> Optional[Dict]:
    """Load storage metrics from JSON file"""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Warning: Could not load {filepath}: {e}")
        return None


def format_bytes(bytes_val: float) -> str:
    """Format bytes into human-readable string"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_val < 1024.0:
            return f"{bytes_val:.2f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.2f} PB"


def print_comparison(push_data: Dict, pull_data: Dict, hybrid_data: Dict):
    """Print formatted comparison of storage metrics"""
    
    print("=" * 100)
    print("STORAGE COMPARISON: Push vs Pull vs Hybrid Fan-out")
    print("=" * 100)
    print()
    
    strategies = {
        'Push': push_data,
        'Pull': pull_data,
        'Hybrid': hybrid_data
    }
    
    # Filter out None values
    strategies = {k: v for k, v in strategies.items() if v is not None}
    
    if not strategies:
        print("❌ No valid metrics data found")
        return
    
    # Extract comparison data
    print("📊 TIMELINE SERVICE STORAGE")
    print("-" * 100)
    print(f"{'Strategy':<15} {'Timeline Items':<20} {'Timeline Size':<20} {'Replication Factor':<20}")
    print("-" * 100)
    
    for name, data in strategies.items():
        comp = data.get('comparison', {})
        timeline_items = comp.get('timeline_item_count', 0)
        timeline_mb = comp.get('timeline_storage_mb', 0)
        replication = comp.get('replication_factor', 0)
        
        print(f"{name:<15} {timeline_items:<20,} {timeline_mb:<18.2f} MB {replication:<20.2f}x")
    
    print()
    print("💰 STORAGE COSTS (Monthly)")
    print("-" * 100)
    print(f"{'Strategy':<15} {'Post Cost':<20} {'Timeline Cost':<20} {'Total Cost':<20} {'Overhead':<20}")
    print("-" * 100)
    
    for name, data in strategies.items():
        tables = data.get('tables', {})
        post_cost = 0
        timeline_cost = 0
        
        for table_name, table_data in tables.items():
            service_type = table_data.get('service_type', '')
            monthly_cost = table_data.get('costs', {}).get('monthly_storage_cost_usd', 0)
            
            if service_type == 'post-service':
                post_cost = monthly_cost
            elif service_type == 'timeline-service':
                timeline_cost = monthly_cost
        
        total_cost = post_cost + timeline_cost
        overhead = timeline_cost
        
        print(f"{name:<15} ${post_cost:<19.4f} ${timeline_cost:<19.4f} ${total_cost:<19.4f} ${overhead:<19.4f}")
    
    print()
    print("📈 STORAGE AMPLIFICATION")
    print("-" * 100)
    print(f"{'Strategy':<15} {'Post Storage':<20} {'Timeline Storage':<20} {'Amplification':<20} {'Difference':<20}")
    print("-" * 100)
    
    for name, data in strategies.items():
        comp = data.get('comparison', {})
        post_mb = comp.get('post_storage_mb', 0)
        timeline_mb = comp.get('timeline_storage_mb', 0)
        amplification = comp.get('amplification_factor', 0)
        difference_mb = comp.get('storage_difference_mb', 0)
        
        print(f"{name:<15} {post_mb:<18.2f} MB {timeline_mb:<18.2f} MB {amplification:<18.2f}x +{difference_mb:<17.2f} MB")
    
    print()
    print("=" * 100)
    print()
    
    # Find most efficient strategy
    costs = []
    for name, data in strategies.items():
        tables = data.get('tables', {})
        total_cost = sum(
            t.get('costs', {}).get('monthly_storage_cost_usd', 0) 
            for t in tables.values()
        )
        costs.append((name, total_cost))
    
    if costs:
        most_efficient = min(costs, key=lambda x: x[1])
        print(f"🏆 Most Cost-Efficient Strategy: {most_efficient[0]} (${most_efficient[1]:.4f}/month)")
        print()


def save_comparison_report(output_file: str, push_data: Dict, pull_data: Dict, hybrid_data: Dict):
    """Save comparison to text file"""
    import sys
    from io import StringIO
    
    # Capture print output
    old_stdout = sys.stdout
    sys.stdout = StringIO()
    
    print_comparison(push_data, pull_data, hybrid_data)
    
    output = sys.stdout.getvalue()
    sys.stdout = old_stdout
    
    with open(output_file, 'w') as f:
        f.write(output)
    
    print(output)
    print(f"✅ Comparison report saved to: {output_file}")


def main():
    parser = argparse.ArgumentParser(description='Compare storage across fan-out strategies')
    parser.add_argument('--push', help='Path to push strategy metrics JSON')
    parser.add_argument('--pull', help='Path to pull strategy metrics JSON')
    parser.add_argument('--hybrid', help='Path to hybrid strategy metrics JSON')
    parser.add_argument('--output', help='Output file for comparison report')
    
    args = parser.parse_args()
    
    # Load metrics
    push_data = load_metrics(args.push) if args.push else None
    pull_data = load_metrics(args.pull) if args.pull else None
    hybrid_data = load_metrics(args.hybrid) if args.hybrid else None
    
    if args.output:
        save_comparison_report(args.output, push_data, pull_data, hybrid_data)
    else:
        print_comparison(push_data, pull_data, hybrid_data)


if __name__ == '__main__':
    main()
