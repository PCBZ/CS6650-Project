#!/usr/bin/env python3
"""
Visualize Fan-out Strategy Comparison

Creates clean, focused charts comparing Push, Pull, and Hybrid strategies.
"""

import json
import argparse
import matplotlib.pyplot as plt
import numpy as np
from typing import Dict, Optional


def load_metrics(filepath: str) -> Optional[Dict]:
    """Load storage metrics from JSON file"""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Warning: Could not load {filepath}: {e}")
        return None


class StrategyVisualizer:
    """Visualize comparison between fan-out strategies"""
    
    def __init__(self, push_file: str, pull_file: str, hybrid_file: str):
        """Load all strategy data"""
        self.push_data = load_metrics(push_file)
        self.pull_data = load_metrics(pull_file)
        self.hybrid_data = load_metrics(hybrid_file)
        
        self.strategies = []
        self.timeline_storage = []
        self.post_storage = []
        self.timeline_items = []
        self.post_items = []
        self.timeline_costs = []
        self.post_costs = []
        self.total_costs = []
        
        self._extract_data()
    
    def _extract_data(self):
        """Extract data from all strategies"""
        data_map = {
            'Push': self.push_data,
            'Pull': self.pull_data,
            'Hybrid': self.hybrid_data
        }
        
        for name, data in data_map.items():
            if data is None:
                continue
                
            self.strategies.append(name)
            
            # Get comparison metrics
            comp = data.get('comparison', {})
            self.timeline_storage.append(comp.get('timeline_storage_mb', 0))
            self.post_storage.append(comp.get('post_storage_mb', 0))
            self.timeline_items.append(comp.get('timeline_item_count', 0))
            self.post_items.append(comp.get('post_item_count', 0))
            
            # Get costs from tables
            tables = data.get('tables', {})
            post_cost = 0
            timeline_cost = 0
            
            for table_data in tables.values():
                service_type = table_data.get('service_type', '')
                monthly_cost = table_data.get('costs', {}).get('monthly_storage_cost_usd', 0)
                
                if service_type == 'post-service':
                    post_cost = monthly_cost
                elif service_type == 'timeline-service':
                    timeline_cost = monthly_cost
            
            self.post_costs.append(post_cost)
            self.timeline_costs.append(timeline_cost)
            self.total_costs.append(post_cost + timeline_cost)
    
    def create_comparison_dashboard(self, output_file: str = 'strategy_comparison.png'):
        """Create comprehensive comparison with all key metrics"""
        fig = plt.figure(figsize=(18, 10))
        gs = fig.add_gridspec(2, 3, hspace=0.35, wspace=0.3)
        
        colors = ['#FF6B6B', '#4ECDC4', '#FFD93D']
        
        # 1. Storage Breakdown (Stacked Bar)
        ax1 = fig.add_subplot(gs[0, :2])
        x = np.arange(len(self.strategies))
        width = 0.6
        
        bars1 = ax1.bar(x, self.post_storage, width, label='Post Service', color='#2196F3')
        bars2 = ax1.bar(x, self.timeline_storage, width, bottom=self.post_storage, 
                       label='Timeline Service', color='#FF5722')
        
        ax1.set_xlabel('Strategy', fontsize=12, fontweight='bold')
        ax1.set_ylabel('Storage (MB)', fontsize=12, fontweight='bold')
        ax1.set_title('Storage Usage by Service', fontsize=13, fontweight='bold')
        ax1.set_xticks(x)
        ax1.set_xticklabels(self.strategies, fontsize=11)
        ax1.legend(loc='upper left')
        ax1.grid(axis='y', alpha=0.3)
        
        # Add total labels on top
        total_storage = [p + t for p, t in zip(self.post_storage, self.timeline_storage)]
        for i, (bar, total) in enumerate(zip(bars2, total_storage)):
            ax1.text(bar.get_x() + bar.get_width()/2., total,
                   f'{total:.1f} MB',
                   ha='center', va='bottom', fontsize=10, fontweight='bold')
        
        # 2. Monthly Costs (Stacked Bar)
        ax2 = fig.add_subplot(gs[1, :2])
        
        bars1 = ax2.bar(x, self.post_costs, width, label='Post Service', color='#4CAF50')
        bars2 = ax2.bar(x, self.timeline_costs, width, bottom=self.post_costs,
                       label='Timeline Service', color='#F44336')
        
        ax2.set_xlabel('Strategy', fontsize=12, fontweight='bold')
        ax2.set_ylabel('Monthly Cost (USD)', fontsize=12, fontweight='bold')
        ax2.set_title('Monthly Storage Costs by Service', fontsize=13, fontweight='bold')
        ax2.set_xticks(x)
        ax2.set_xticklabels(self.strategies, fontsize=11)
        ax2.legend(loc='upper left')
        ax2.grid(axis='y', alpha=0.3)
        
        # Add total labels with cost efficiency indicator
        min_cost = min(self.total_costs) if self.total_costs else 0
        for i, (bar, total) in enumerate(zip(bars2, self.total_costs)):
            label = f'${total:.4f}'
            if total == min_cost and min_cost > 0:
                label += ' ⭐'
            ax2.text(bar.get_x() + bar.get_width()/2., total,
                   label,
                   ha='center', va='bottom', fontsize=10, fontweight='bold')
        
        # 3. Key Metrics Summary Table
        ax3 = fig.add_subplot(gs[:, 2])
        ax3.axis('off')
        
        # Prepare summary data
        table_data = []
        headers = ['Metric', 'Push', 'Pull', 'Hybrid']
        
        # Storage
        table_data.append(['Storage (MB)',
                          f'{total_storage[0]:.1f}' if len(total_storage) > 0 else '0',
                          f'{total_storage[1]:.1f}' if len(total_storage) > 1 else '0',
                          f'{total_storage[2]:.1f}' if len(total_storage) > 2 else '0'])
        
        # Cost
        table_data.append(['Cost ($/mo)',
                          f'${self.total_costs[0]:.4f}' if len(self.total_costs) > 0 else '$0',
                          f'${self.total_costs[1]:.4f}' if len(self.total_costs) > 1 else '$0',
                          f'${self.total_costs[2]:.4f}' if len(self.total_costs) > 2 else '$0'])
        
        # Timeline Items
        table_data.append(['Timeline Items',
                          f'{self.timeline_items[0]:,}' if len(self.timeline_items) > 0 else '0',
                          f'{self.timeline_items[1]:,}' if len(self.timeline_items) > 1 else '0',
                          f'{self.timeline_items[2]:,}' if len(self.timeline_items) > 2 else '0'])
        
        # Post Items
        table_data.append(['Post Items',
                          f'{self.post_items[0]:,}' if len(self.post_items) > 0 else '0',
                          f'{self.post_items[1]:,}' if len(self.post_items) > 1 else '0',
                          f'{self.post_items[2]:,}' if len(self.post_items) > 2 else '0'])
        
        # Cost Efficiency (MB per dollar)
        efficiency = []
        for i in range(len(self.strategies)):
            if self.total_costs[i] > 0:
                eff = total_storage[i] / self.total_costs[i]
                efficiency.append(f'{eff:,.0f}')
            else:
                efficiency.append('N/A')
        
        table_data.append(['MB per $', efficiency[0] if len(efficiency) > 0 else 'N/A',
                          efficiency[1] if len(efficiency) > 1 else 'N/A',
                          efficiency[2] if len(efficiency) > 2 else 'N/A'])
        
        # Add winner row
        min_cost_idx = self.total_costs.index(min(self.total_costs)) if self.total_costs else 0
        min_storage_idx = total_storage.index(min(total_storage)) if total_storage else 0
        
        winners = ['', '', '']
        if min_cost_idx < len(winners):
            winners[min_cost_idx] = '💰 Best Cost'
        if min_storage_idx < len(winners):
            if winners[min_storage_idx]:
                winners[min_storage_idx] += '\n📊 Least Storage'
            else:
                winners[min_storage_idx] = '📊 Least Storage'
        
        table_data.append(['Winner', winners[0], winners[1], winners[2]])
        
        # Create table
        table = ax3.table(
            cellText=table_data,
            colLabels=headers,
            cellLoc='center',
            loc='center',
            colWidths=[0.32, 0.23, 0.23, 0.23]
        )
        
        table.auto_set_font_size(False)
        table.set_fontsize(9)
        table.scale(1, 2.5)
        
        # Style header row
        for i in range(4):
            cell = table[(0, i)]
            cell.set_facecolor('#2196F3')
            cell.set_text_props(weight='bold', color='white')
        
        # Style metric names column
        for i in range(1, len(table_data) + 1):
            cell = table[(i, 0)]
            cell.set_facecolor('#E3F2FD')
            cell.set_text_props(weight='bold')
        
        # Highlight best values
        if len(self.total_costs) >= 3:
            # Highlight lowest storage
            table[(1, min_storage_idx + 1)].set_facecolor('#C8E6C9')
            # Highlight lowest cost
            table[(2, min_cost_idx + 1)].set_facecolor('#C8E6C9')
            # Highlight winner row
            for i in range(1, 4):
                table[(len(table_data), i)].set_facecolor('#FFF9C4')
        
        ax3.set_title('Strategy Comparison Summary (5K Users)', 
                     fontsize=13, fontweight='bold', pad=20)
        
        fig.suptitle('Fan-out Strategy Analysis Dashboard', 
                    fontsize=16, fontweight='bold', y=0.98)
        
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        print(f"✅ Comparison dashboard saved to: {output_file}")
        plt.close()
    
    def create_tradeoff_analysis(self, output_file: str = 'strategy_tradeoffs.png'):
        """Create visual analysis of storage vs cost tradeoffs"""
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
        
        colors = ['#FF6B6B', '#4ECDC4', '#FFD93D']
        total_storage = [p + t for p, t in zip(self.post_storage, self.timeline_storage)]
        
        # Chart 1: Storage vs Cost Scatter
        ax1.scatter(self.total_costs, total_storage, s=500, c=colors, alpha=0.6, edgecolors='black', linewidth=2)
        
        for i, strat in enumerate(self.strategies):
            ax1.annotate(strat, 
                        (self.total_costs[i], total_storage[i]),
                        ha='center', va='center', 
                        fontsize=12, fontweight='bold')
        
        ax1.set_xlabel('Monthly Cost (USD)', fontsize=12, fontweight='bold')
        ax1.set_ylabel('Total Storage (MB)', fontsize=12, fontweight='bold')
        ax1.set_title('Storage vs Cost Trade-off', fontsize=14, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        
        # Add quadrant labels
        if self.total_costs and total_storage:
            mid_cost = sum(self.total_costs) / len(self.total_costs)
            mid_storage = sum(total_storage) / len(total_storage)
            
            ax1.axhline(y=mid_storage, color='gray', linestyle='--', alpha=0.5)
            ax1.axvline(x=mid_cost, color='gray', linestyle='--', alpha=0.5)
            
            ax1.text(0.02, 0.98, 'Low Cost\nHigh Storage', transform=ax1.transAxes,
                    ha='left', va='top', fontsize=9, style='italic', alpha=0.6)
            ax1.text(0.98, 0.02, 'High Cost\nLow Storage', transform=ax1.transAxes,
                    ha='right', va='bottom', fontsize=9, style='italic', alpha=0.6)
        
        # Chart 2: Relative Performance (Normalized)
        metrics = ['Storage', 'Cost', 'Timeline\nItems']
        
        # Normalize data (0-100 scale, lower is better for storage/cost)
        max_storage = max(total_storage) if total_storage else 1
        max_cost = max(self.total_costs) if self.total_costs else 1
        max_items = max(self.timeline_items) if self.timeline_items else 1
        
        x = np.arange(len(metrics))
        width = 0.25
        
        for i, strat in enumerate(self.strategies):
            norm_storage = (total_storage[i] / max_storage * 100) if max_storage else 0
            norm_cost = (self.total_costs[i] / max_cost * 100) if max_cost else 0
            norm_items = (self.timeline_items[i] / max_items * 100) if max_items else 0
            
            values = [norm_storage, norm_cost, norm_items]
            offset = (i - 1) * width
            
            bars = ax2.bar(x + offset, values, width, label=strat, color=colors[i], alpha=0.8)
            
            # Add value labels
            for j, bar in enumerate(bars):
                height = bar.get_height()
                ax2.text(bar.get_x() + bar.get_width()/2., height,
                       f'{height:.0f}%',
                       ha='center', va='bottom', fontsize=8)
        
        ax2.set_ylabel('Relative Value (%)', fontsize=12, fontweight='bold')
        ax2.set_title('Normalized Comparison (Higher = More)', fontsize=14, fontweight='bold')
        ax2.set_xticks(x)
        ax2.set_xticklabels(metrics)
        ax2.legend()
        ax2.grid(axis='y', alpha=0.3)
        ax2.set_ylim(0, 110)
        
        plt.tight_layout()
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        print(f"✅ Trade-off analysis saved to: {output_file}")
        plt.close()
    
    def generate_all_charts(self, output_dir: str = '.'):
        """Generate focused visualization charts (no redundancy)"""
        import os
        
        os.makedirs(output_dir, exist_ok=True)
        
        print("\n" + "="*80)
        print("Generating fan-out strategy visualizations...")
        print("="*80 + "\n")
        
        self.create_comparison_dashboard(f'{output_dir}/strategy_comparison.png')
        self.create_tradeoff_analysis(f'{output_dir}/strategy_tradeoffs.png')
        
        print("\n" + "="*80)
        print("✅ All charts generated successfully!")
        print("="*80)


def main():
    parser = argparse.ArgumentParser(
        description='Visualize fan-out strategy comparison'
    )
    parser.add_argument('--push', required=True, help='Path to push strategy metrics JSON')
    parser.add_argument('--pull', required=True, help='Path to pull strategy metrics JSON')
    parser.add_argument('--hybrid', required=True, help='Path to hybrid strategy metrics JSON')
    parser.add_argument('--output-dir', default='./charts', 
                       help='Output directory for charts (default: ./charts)')
    
    args = parser.parse_args()
    
    visualizer = StrategyVisualizer(args.push, args.pull, args.hybrid)
    visualizer.generate_all_charts(args.output_dir)


if __name__ == '__main__':
    main()
