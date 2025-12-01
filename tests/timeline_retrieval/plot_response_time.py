import matplotlib.pyplot as plt
import numpy as np

# Updated data with new following counts and values
data = {
    'Push': [45, 47, 48],
    'Pull': [50, 1000, 3200],
    'Hybrid': [52, 850, 2200]
}

following_counts = ['10 Following', '500 Following', '1600 Following']

# Create figure and axis
fig, ax = plt.subplots(figsize=(12, 8))

# Colors matching the React version
colors = {
    'Push': '#22c55e',    # Green
    'Pull': '#ef4444',    # Red  
    'Hybrid': '#3b82f6'   # Blue
}

# Bar positions
x = np.arange(len(following_counts))  # the label locations
width = 0.25  # the width of the bars

# Create bars
bars1 = ax.bar(x - width, data['Push'], width, label='Push Algorithm', color=colors['Push'], alpha=0.8)
bars2 = ax.bar(x, data['Pull'], width, label='Pull Algorithm', color=colors['Pull'], alpha=0.8)
bars3 = ax.bar(x + width, data['Hybrid'], width, label='Hybrid Algorithm', color=colors['Hybrid'], alpha=0.8)

# Add value labels on bars
def add_value_labels(bars):
    for bar in bars:
        height = bar.get_height()
        ax.annotate(f'{height}ms',
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3),  # 3 points vertical offset
                    textcoords="offset points",
                    ha='center', va='bottom',
                    fontsize=10, fontweight='bold')

add_value_labels(bars1)
add_value_labels(bars2)
add_value_labels(bars3)

# Customize the chart
ax.set_ylabel('Response Time (ms)', fontsize=14, fontweight='bold')
ax.set_xlabel('Following Count', fontsize=14, fontweight='bold')
ax.set_title('Fan-out Algorithm Performance Comparison\nResponse Time by Algorithm and Following Count', 
             fontsize=16, fontweight='bold', pad=20)

# Set x-axis labels
ax.set_xticks(x)
ax.set_xticklabels(following_counts)
ax.legend(loc='upper left', fontsize=12)

# Add grid for better readability
ax.grid(True, alpha=0.3, linestyle='--')
ax.set_axisbelow(True)

# Set y-axis to start from 0 for better comparison
ax.set_ylim(0, max(data['Pull']) * 1.1)

# Add performance insights as text box
textstr = '\n'.join([
    '🏆 Push: Excellent scalability (1.07x factor)',
    '⚖️ Hybrid: Moderate performance (42.3x factor)', 
    '⚠️ Pull: Poor scalability (64.0x factor)'
])

props = dict(boxstyle='round', facecolor='lightblue', alpha=0.8)
ax.text(0.02, 0.98, textstr, transform=ax.transAxes, fontsize=11,
        verticalalignment='top', bbox=props)

# Adjust layout to prevent label cutoff
plt.tight_layout()

# Show the plot
plt.show()

# Optional: Save the figure
# plt.savefig('fanout_algorithm_performance.png', dpi=300, bbox_inches='tight')

# Print summary statistics
print("Performance Summary:")
print("=" * 70)
print(f"{'Algorithm':<10} | {'10 Following':<12} | {'500 Following':<13} | {'1600 Following':<14} | {'Scale Factor'}")
print("-" * 70)

for algorithm in data.keys():
    values = data[algorithm]
    scale_factor = values[2] / values[0]  # 1600 following / 10 following
    print(f"{algorithm:<10} | {values[0]:>8}ms    | {values[1]:>9}ms     | {values[2]:>10}ms     | {scale_factor:>8.1f}x")

print()
print("Key Insights:")
print("=" * 70)
print("📊 Push Algorithm:")
print(f"   - Maintains consistent low latency: 45ms → 47ms → 48ms")
print(f"   - Scale factor: {data['Push'][2] / data['Push'][0]:.1f}x (excellent)")
print()
print("📊 Pull Algorithm:")
print(f"   - Dramatic performance degradation: 50ms → 1000ms → 3200ms")
print(f"   - Scale factor: {data['Pull'][2] / data['Pull'][0]:.1f}x (poor)")
print()
print("📊 Hybrid Algorithm:")
print(f"   - Moderate performance: 52ms → 850ms → 2200ms")
print(f"   - Scale factor: {data['Hybrid'][2] / data['Hybrid'][0]:.1f}x (moderate)")
print()
print("🎯 Recommendation: Push Algorithm is optimal for scalable timeline generation.")