#!/usr/bin/env python3
"""
Database Storage Measurement Tool

Collects storage metrics from DynamoDB tables for Post-service and Timeline-service.
Measures table sizes, item counts, and calculates storage efficiency.
"""

import boto3
import json
import sys
from datetime import datetime
from typing import Dict, List, Tuple
import argparse


class StorageMeasurement:
    """Measures DynamoDB table storage metrics"""
    
    def __init__(self, region: str = "us-west-2"):
        """
        Initialize DynamoDB client
        
        Args:
            region: AWS region name
        """
        self.region = region
        self.dynamodb = boto3.client('dynamodb', region_name=region)
        self.dynamodb_resource = boto3.resource('dynamodb', region_name=region)
    
    def get_table_metrics(self, table_name: str) -> Dict:
        """
        Get storage metrics for a DynamoDB table
        
        Args:
            table_name: Name of the DynamoDB table
            
        Returns:
            Dictionary containing table metrics
        """
        try:
            # Get table description
            response = self.dynamodb.describe_table(TableName=table_name)
            table = response['Table']
            
            # Get ACCURATE item count via scan (describe-table is cached and stale)
            print(f"Getting accurate count for {table_name} (this may take a moment)...")
            actual_count = self._get_accurate_item_count(table_name)
            
            # Extract key metrics
            metrics = {
                'table_name': table_name,
                'item_count': actual_count,  # Use accurate count
                'item_count_cached': table.get('ItemCount', 0),  # Store cached value for reference
                'table_size_bytes': table.get('TableSizeBytes', 0),
                'table_size_kb': round(table.get('TableSizeBytes', 0) / 1024, 2),
                'table_size_mb': round(table.get('TableSizeBytes', 0) / (1024 * 1024), 2),
                'table_size_gb': round(table.get('TableSizeBytes', 0) / (1024 * 1024 * 1024), 4),
                'table_status': table.get('TableStatus', 'UNKNOWN'),
                'creation_date': str(table.get('CreationDateTime', '')),
            }
            
            # If cached size is 0 but we have items, estimate size from sample
            if metrics['table_size_bytes'] == 0 and actual_count > 0:
                print(f"Cached size is 0, sampling items to estimate actual size...")
                size_estimate = self._estimate_table_size(table_name, actual_count)
                metrics['table_size_bytes'] = size_estimate['total_bytes']
                metrics['table_size_kb'] = round(size_estimate['total_bytes'] / 1024, 2)
                metrics['table_size_mb'] = round(size_estimate['total_bytes'] / (1024 * 1024), 2)
                metrics['table_size_gb'] = round(size_estimate['total_bytes'] / (1024 * 1024 * 1024), 4)
                metrics['avg_item_size_bytes'] = size_estimate['avg_item_bytes']
                metrics['size_estimated'] = True
            else:
                # Calculate average item size
                if metrics['item_count'] > 0:
                    metrics['avg_item_size_bytes'] = round(
                        metrics['table_size_bytes'] / metrics['item_count'], 2
                    )
                else:
                    metrics['avg_item_size_bytes'] = 0
                metrics['size_estimated'] = False
            
            # Get GSI information if exists
            gsi_info = []
            if 'GlobalSecondaryIndexes' in table:
                for gsi in table['GlobalSecondaryIndexes']:
                    gsi_info.append({
                        'index_name': gsi['IndexName'],
                        'item_count': gsi.get('ItemCount', 0),
                        'index_size_bytes': gsi.get('IndexSizeBytes', 0),
                        'index_size_mb': round(gsi.get('IndexSizeBytes', 0) / (1024 * 1024), 2)
                    })
            metrics['global_secondary_indexes'] = gsi_info
            
            # Calculate total size including GSIs
            total_gsi_size = sum(gsi['index_size_bytes'] for gsi in gsi_info)
            metrics['total_size_with_indexes_bytes'] = metrics['table_size_bytes'] + total_gsi_size
            metrics['total_size_with_indexes_mb'] = round(
                metrics['total_size_with_indexes_bytes'] / (1024 * 1024), 2
            )
            metrics['total_size_with_indexes_gb'] = round(
                metrics['total_size_with_indexes_bytes'] / (1024 * 1024 * 1024), 4
            )
            
            return metrics
            
        except Exception as e:
            print(f"Error getting metrics for table {table_name}: {e}")
            return None
    
    def _get_accurate_item_count(self, table_name: str) -> int:
        """
        Get accurate item count using scan (not cached metadata)
        
        Args:
            table_name: Name of the DynamoDB table
            
        Returns:
            Actual number of items in the table
        """
        try:
            table = self.dynamodb_resource.Table(table_name)
            
            total_count = 0
            response = table.scan(Select='COUNT')
            total_count = response.get('Count', 0)
            
            # Handle pagination
            while 'LastEvaluatedKey' in response:
                response = table.scan(
                    Select='COUNT',
                    ExclusiveStartKey=response['LastEvaluatedKey']
                )
                total_count += response.get('Count', 0)
            
            return total_count
            
        except Exception as e:
            print(f"Error counting items in {table_name}: {e}")
            return 0
    
    def _estimate_table_size(self, table_name: str, total_count: int, sample_size: int = 1000) -> Dict:
        """
        Estimate table size by sampling items
        
        Args:
            table_name: Name of the DynamoDB table
            total_count: Total number of items in table
            sample_size: Number of items to sample
            
        Returns:
            Dictionary with size estimates
        """
        try:
            table = self.dynamodb_resource.Table(table_name)
            
            # Sample items
            response = table.scan(Limit=min(sample_size, total_count))
            items = response.get('Items', [])
            
            if not items:
                return {'total_bytes': 0, 'avg_item_bytes': 0}
            
            # Calculate sizes
            item_sizes = []
            for item in items:
                # Estimate item size (JSON serialization approximation)
                item_size = len(json.dumps(item, default=str).encode('utf-8'))
                item_sizes.append(item_size)
            
            avg_size = sum(item_sizes) / len(item_sizes)
            total_size = int(avg_size * total_count)
            
            print(f"   Sampled {len(items)} items, avg size: {avg_size:.2f} bytes")
            print(f"   Estimated total: {total_size / (1024*1024):.2f} MB for {total_count:,} items")
            
            return {
                'total_bytes': total_size,
                'avg_item_bytes': round(avg_size, 2),
                'sample_count': len(items)
            }
            
        except Exception as e:
            print(f"Error estimating size for {table_name}: {e}")
            return {'total_bytes': 0, 'avg_item_bytes': 0}

    def scan_table_for_accurate_count(self, table_name: str, sample_size: int = 100) -> Dict:
        """
        Scan table to get accurate item count and size distribution
        
        Args:
            table_name: Name of the DynamoDB table
            sample_size: Number of items to sample for size analysis
            
        Returns:
            Dictionary with accurate metrics
        """
        try:
            table = self.dynamodb_resource.Table(table_name)
            
            # Perform scan to count items
            print(f"Scanning {table_name} (this may take a while)...")
            
            total_items = 0
            item_sizes = []
            
            # Scan with pagination
            response = table.scan(Limit=sample_size)
            items = response.get('Items', [])
            
            for item in items:
                # Estimate item size (approximate)
                item_size = len(json.dumps(item, default=str).encode('utf-8'))
                item_sizes.append(item_size)
            
            total_items = len(items)
            
            # Continue scanning for total count (but not size analysis)
            while 'LastEvaluatedKey' in response:
                response = table.scan(
                    ExclusiveStartKey=response['LastEvaluatedKey'],
                    Select='COUNT'
                )
                total_items += response.get('Count', 0)
            
            metrics = {
                'actual_item_count': total_items,
                'sampled_items': len(item_sizes),
                'avg_item_size_bytes': round(sum(item_sizes) / len(item_sizes), 2) if item_sizes else 0,
                'min_item_size_bytes': min(item_sizes) if item_sizes else 0,
                'max_item_size_bytes': max(item_sizes) if item_sizes else 0,
            }
            
            # Estimate total size based on sample
            if metrics['avg_item_size_bytes'] > 0:
                estimated_total_size = metrics['avg_item_size_bytes'] * total_items
                metrics['estimated_total_size_mb'] = round(estimated_total_size / (1024 * 1024), 2)
                metrics['estimated_total_size_gb'] = round(estimated_total_size / (1024 * 1024 * 1024), 4)
            
            return metrics
            
        except Exception as e:
            print(f"Error scanning table {table_name}: {e}")
            return None
    
    def calculate_costs(self, size_gb: float) -> Dict:
        """
        Calculate DynamoDB storage costs
        
        Args:
            size_gb: Storage size in gigabytes
            
        Returns:
            Dictionary with cost calculations
        """
        # DynamoDB pricing (us-west-2)
        STORAGE_COST_PER_GB_MONTH = 0.25  # Standard table class
        
        return {
            'storage_gb': size_gb,
            'monthly_storage_cost_usd': round(size_gb * STORAGE_COST_PER_GB_MONTH, 4),
            'annual_storage_cost_usd': round(size_gb * STORAGE_COST_PER_GB_MONTH * 12, 2),
        }
    
    def measure_all_tables(self, table_configs: List[Dict]) -> Dict:
        """
        Measure multiple tables and compare
        
        Args:
            table_configs: List of table configurations with name and type
            
        Returns:
            Dictionary with all measurements
        """
        results = {
            'timestamp': datetime.now().isoformat(),
            'region': self.region,
            'tables': {}
        }
        
        for config in table_configs:
            table_name = config['name']
            service_type = config.get('type', 'unknown')
            
            print(f"\n{'='*80}")
            print(f"Measuring: {table_name} ({service_type})")
            print(f"{'='*80}")
            
            # Get table metrics
            metrics = self.get_table_metrics(table_name)
            
            if metrics:
                # Add service type
                metrics['service_type'] = service_type
                
                # Calculate costs
                costs = self.calculate_costs(metrics['total_size_with_indexes_gb'])
                metrics['costs'] = costs
                
                # Print summary
                self._print_table_summary(metrics)
                
                # Store results
                results['tables'][table_name] = metrics
        
        # Calculate comparison metrics
        results['comparison'] = self._calculate_comparison(results['tables'])
        
        return results
    
    def _print_table_summary(self, metrics: Dict):
        """Print formatted summary of table metrics"""
        print(f"\n📊 Table: {metrics['table_name']}")
        print(f"   Service: {metrics['service_type']}")
        print(f"   Status: {metrics['table_status']}")
        print(f"   Item Count: {metrics['item_count']:,}")
        print(f"   Table Size: {metrics['table_size_mb']:.2f} MB ({metrics['table_size_gb']:.4f} GB)")
        print(f"   Avg Item Size: {metrics['avg_item_size_bytes']:.2f} bytes")
        
        if metrics['global_secondary_indexes']:
            print(f"\n   📑 Global Secondary Indexes:")
            for gsi in metrics['global_secondary_indexes']:
                print(f"      - {gsi['index_name']}: {gsi['index_size_mb']:.2f} MB ({gsi['item_count']:,} items)")
        
        print(f"\n   💰 Total Size (with indexes): {metrics['total_size_with_indexes_mb']:.2f} MB ({metrics['total_size_with_indexes_gb']:.4f} GB)")
        print(f"   💵 Monthly Cost: ${metrics['costs']['monthly_storage_cost_usd']:.4f}")
        print(f"   💵 Annual Cost: ${metrics['costs']['annual_storage_cost_usd']:.2f}")
    
    def _calculate_comparison(self, tables: Dict) -> Dict:
        """Calculate comparison metrics between tables"""
        comparison = {}
        
        # Find post and timeline tables
        post_table = None
        timeline_table = None
        
        for table_name, metrics in tables.items():
            if metrics['service_type'] == 'post-service':
                post_table = metrics
            elif metrics['service_type'] == 'timeline-service':
                timeline_table = metrics
        
        if post_table and timeline_table:
            comparison = {
                'post_storage_mb': post_table['total_size_with_indexes_mb'],
                'timeline_storage_mb': timeline_table['total_size_with_indexes_mb'],
                'storage_difference_mb': timeline_table['total_size_with_indexes_mb'] - post_table['total_size_with_indexes_mb'],
                'post_item_count': post_table['item_count'],
                'timeline_item_count': timeline_table['item_count'],
                'cost_difference_monthly_usd': round(
                    timeline_table['costs']['monthly_storage_cost_usd'] - 
                    post_table['costs']['monthly_storage_cost_usd'], 4
                )
            }
        
        return comparison


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Measure DynamoDB storage for Post and Timeline services'
    )
    parser.add_argument(
        '--region',
        default='us-west-2',
        help='AWS region (default: us-west-2)'
    )
    parser.add_argument(
        '--post-table',
        default='posts-table',
        help='Post service table name'
    )
    parser.add_argument(
        '--timeline-table',
        default='timelines-table',
        help='Timeline service table name'
    )
    parser.add_argument(
        '--output',
        default='storage_metrics.json',
        help='Output file for results (JSON)'
    )
    parser.add_argument(
        '--scan',
        action='store_true',
        help='Perform table scan for accurate measurements (slower)'
    )
    
    args = parser.parse_args()
    
    # Initialize measurement tool
    measurer = StorageMeasurement(region=args.region)
    
    # Define tables to measure
    table_configs = [
        {'name': args.post_table, 'type': 'post-service'},
        {'name': args.timeline_table, 'type': 'timeline-service'}
    ]
    
    # Measure all tables
    results = measurer.measure_all_tables(table_configs)
    
    # Print comparison
    if results['comparison']:
        print(f"\n{'='*80}")
        print("📈 COMPARISON: Post-service vs Timeline-service")
        print(f"{'='*80}")
        comp = results['comparison']
        print(f"\n📦 Storage:")
        print(f"   Post-service: {comp['post_storage_mb']:.2f} MB")
        print(f"   Timeline-service: {comp['timeline_storage_mb']:.2f} MB")
        print(f"   Difference: +{comp['storage_difference_mb']:.2f} MB")
        
        print(f"\n📊 Items:")
        print(f"   Post items: {comp['post_item_count']:,}")
        print(f"   Timeline items: {comp['timeline_item_count']:,}")
        
        print(f"\n💰 Cost Difference:")
        print(f"   Monthly: ${comp['cost_difference_monthly_usd']:.4f}")
        print(f"{'='*80}\n")
    
    # Save results to file
    with open(args.output, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print(f"✅ Results saved to: {args.output}")
    print(f"\nRun with --scan flag for more accurate measurements (slower)")


if __name__ == '__main__':
    main()
