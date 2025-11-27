#!/usr/bin/env python3
"""
Compare Storage Across Different Scales

Compares storage metrics across 5K, 25K, and 100K user scales.
Analyzes growth patterns and cost projections.
"""

import json
import argparse
from typing import Dict, List
import matplotlib.pyplot as plt
import pandas as pd
from datetime import datetime


class StorageComparison:
    """Compare storage metrics across different scales"""
    
    def __init__(self):
        self.scales = {}
    
    def load_metrics(self, scale: str, filepath: str):
        """Load metrics from JSON file"""
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)
                self.scales[scale] = data
                print(f"✅ Loaded metrics for {scale} scale from {filepath}")
        except Exception as e:
            print(f"❌ Error loading {filepath}: {e}")
    
    def compare_scales(self) -> Dict:
        """Compare metrics across all loaded scales"""
        comparison = {
            'timestamp': datetime.now().isoformat(),
            'scales_compared': list(self.scales.keys()),
            'metrics_by_scale': {},
            'growth_analysis': {}
        }
        
        # Extract metrics for each scale
        for scale, data in self.scales.items():
            scale_metrics = {
                'scale': scale,
                'timestamp': data.get('timestamp', 'unknown')
            }
            
            # Post-service metrics
            post_table = self._find_table_by_type(data, 'post-service')
            if post_table:
                scale_metrics['post_service'] = {
                    'item_count': post_table['item_count'],
                    'storage_mb': post_table['total_size_with_indexes_mb'],
                    'storage_gb': post_table['total_size_with_indexes_gb'],
                    'avg_item_size_bytes': post_table['avg_item_size_bytes'],
                    'monthly_cost_usd': post_table['costs']['monthly_storage_cost_usd']
                }
            
            # Timeline-service metrics
            timeline_table = self._find_table_by_type(data, 'timeline-service')
            if timeline_table:
                scale_metrics['timeline_service'] = {
                    'item_count': timeline_table['item_count'],
                    'storage_mb': timeline_table['total_size_with_indexes_mb'],
                    'storage_gb': timeline_table['total_size_with_indexes_gb'],
                    'avg_item_size_bytes': timeline_table['avg_item_size_bytes'],
                    'monthly_cost_usd': timeline_table['costs']['monthly_storage_cost_usd']
                }
            
            # Comparison metrics
            if 'comparison' in data and data['comparison']:
                scale_metrics['comparison'] = data['comparison']
            
            comparison['metrics_by_scale'][scale] = scale_metrics
        
        # Calculate growth rates
        comparison['growth_analysis'] = self._analyze_growth()
        
        return comparison
    
    def _find_table_by_type(self, data: Dict, service_type: str) -> Dict:
        """Find table metrics by service type"""
        if 'tables' in data:
            for table_name, metrics in data['tables'].items():
                if metrics.get('service_type') == service_type:
                    return metrics
        return None
    
    def _analyze_growth(self) -> Dict:
        """Analyze storage growth patterns"""
        growth = {}
        
        # Sort scales (5K, 25K, 100K)
        scale_order = ['5K', '25K', '100K']
        available_scales = [s for s in scale_order if s in self.scales]
        
        if len(available_scales) < 2:
            return growth
        
        # Calculate growth rates between consecutive scales
        for i in range(len(available_scales) - 1):
            scale1 = available_scales[i]
            scale2 = available_scales[i + 1]
            
            metrics1 = self.scales[scale1]['tables']
            metrics2 = self.scales[scale2]['tables']
            
            # Post-service growth
            post1 = self._find_table_by_type(self.scales[scale1], 'post-service')
            post2 = self._find_table_by_type(self.scales[scale2], 'post-service')
            
            if post1 and post2:
                growth[f'post_{scale1}_to_{scale2}'] = {
                    'storage_growth_factor': round(
                        post2['total_size_with_indexes_mb'] / post1['total_size_with_indexes_mb'], 2
                    ) if post1['total_size_with_indexes_mb'] > 0 else 0,
                    'item_growth_factor': round(
                        post2['item_count'] / post1['item_count'], 2
                    ) if post1['item_count'] > 0 else 0
                }
            
            # Timeline-service growth
            timeline1 = self._find_table_by_type(self.scales[scale1], 'timeline-service')
            timeline2 = self._find_table_by_type(self.scales[scale2], 'timeline-service')
            
            if timeline1 and timeline2:
                growth[f'timeline_{scale1}_to_{scale2}'] = {
                    'storage_growth_factor': round(
                        timeline2['total_size_with_indexes_mb'] / timeline1['total_size_with_indexes_mb'], 2
                    ) if timeline1['total_size_with_indexes_mb'] > 0 else 0,
                    'item_growth_factor': round(
                        timeline2['item_count'] / timeline1['item_count'], 2
                    ) if timeline1['item_count'] > 0 else 0
                }
        
        return growth
    
    def generate_report(self) -> str:
        """Generate text report"""
        comparison = self.compare_scales()
        
        report = []
        report.append("=" * 100)
        report.append("DATABASE STORAGE COMPARISON REPORT")
        report.append("=" * 100)
        report.append(f"Generated: {comparison['timestamp']}")
        report.append(f"Scales Compared: {', '.join(comparison['scales_compared'])}")
        report.append("")
        
        # Summary table
        report.append("STORAGE SUMMARY BY SCALE")
        report.append("-" * 100)
        report.append(f"{'Scale':<10} {'Service':<20} {'Items':>15} {'Storage (MB)':>15} {'Storage (GB)':>15} {'Monthly Cost':>15}")
        report.append("-" * 100)
        
        for scale in ['5K', '25K', '100K']:
            if scale in comparison['metrics_by_scale']:
                metrics = comparison['metrics_by_scale'][scale]
                
                # Post-service
                if 'post_service' in metrics:
                    ps = metrics['post_service']
                    report.append(
                        f"{scale:<10} {'Post-service':<20} {ps['item_count']:>15,} "
                        f"{ps['storage_mb']:>15.2f} {ps['storage_gb']:>15.4f} "
                        f"${ps['monthly_cost_usd']:>14.4f}"
                    )
                
                # Timeline-service
                if 'timeline_service' in metrics:
                    ts = metrics['timeline_service']
                    report.append(
                        f"{'':<10} {'Timeline-service':<20} {ts['item_count']:>15,} "
                        f"{ts['storage_mb']:>15.2f} {ts['storage_gb']:>15.4f} "
                        f"${ts['monthly_cost_usd']:>14.4f}"
                    )
                
                # Comparison
                if 'comparison' in metrics:
                    comp = metrics['comparison']
                    report.append(
                        f"{'':<10} {'Amplification':<20} {'':<15} "
                        f"{comp.get('amplification_factor', 0):>15.2f}x {'':<15} {'':<15}"
                    )
                
                report.append("-" * 100)
        
        # Growth analysis
        if comparison['growth_analysis']:
            report.append("")
            report.append("GROWTH ANALYSIS")
            report.append("-" * 100)
            
            for key, growth in comparison['growth_analysis'].items():
                report.append(f"\n{key}:")
                report.append(f"  Storage Growth: {growth['storage_growth_factor']}x")
                report.append(f"  Item Growth: {growth['item_growth_factor']}x")
        
        report.append("")
        report.append("=" * 100)
        
        return "\n".join(report)
    
    def save_comparison(self, output_file: str):
        """Save comparison to JSON file"""
        comparison = self.compare_scales()
        
        with open(output_file, 'w') as f:
            json.dump(comparison, f, indent=2)
        
        print(f"✅ Comparison saved to: {output_file}")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Compare storage metrics across different scales'
    )
    parser.add_argument(
        '--metrics-5k',
        help='Path to 5K scale metrics JSON file'
    )
    parser.add_argument(
        '--metrics-25k',
        help='Path to 25K scale metrics JSON file'
    )
    parser.add_argument(
        '--metrics-100k',
        help='Path to 100K scale metrics JSON file'
    )
    parser.add_argument(
        '--output',
        default='storage_comparison.json',
        help='Output file for comparison results'
    )
    parser.add_argument(
        '--report',
        default='storage_report.txt',
        help='Output file for text report'
    )
    
    args = parser.parse_args()
    
    # Initialize comparison
    comparator = StorageComparison()
    
    # Load metrics for each scale
    if args.metrics_5k:
        comparator.load_metrics('5K', args.metrics_5k)
    if args.metrics_25k:
        comparator.load_metrics('25K', args.metrics_25k)
    if args.metrics_100k:
        comparator.load_metrics('100K', args.metrics_100k)
    
    if not comparator.scales:
        print("❌ No metrics loaded. Please provide at least one metrics file.")
        return
    
    # Generate and print report
    report = comparator.generate_report()
    print("\n" + report)
    
    # Save report to file
    with open(args.report, 'w') as f:
        f.write(report)
    print(f"\n✅ Report saved to: {args.report}")
    
    # Save comparison JSON
    comparator.save_comparison(args.output)


if __name__ == '__main__':
    main()
