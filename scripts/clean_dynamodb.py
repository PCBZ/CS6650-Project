#!/usr/bin/env python3
"""
清理 Post Service 和 Timeline Service 的 DynamoDB 表数据

用法:
    python scripts/clean_dynamodb.py
    python scripts/clean_dynamodb.py --tables posts-table posts-timeline-service
    python scripts/clean_dynamodb.py --confirm  # 跳过确认提示
"""

import sys
import argparse
from typing import List

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    print("❌ 错误: 缺少 boto3 库")
    print("   请运行: pip install boto3")
    print("   或: pip install -r requirements.txt")
    sys.exit(1)


def delete_all_items(dynamodb, table_name: str, region: str = "us-west-2") -> int:
    """
    删除 DynamoDB 表中的所有项目
    
    Args:
        dynamodb: boto3 DynamoDB 客户端
        table_name: 表名
        region: AWS 区域
    
    Returns:
        删除的项目数量
    """
    try:
        table = dynamodb.Table(table_name)
        deleted_count = 0
        
        print(f"📊 开始清理表: {table_name}")
        
        # 扫描表获取所有项目
        scan_kwargs = {}
        done = False
        start_key = None
        
        while not done:
            if start_key:
                scan_kwargs['ExclusiveStartKey'] = start_key
            
            response = table.scan(**scan_kwargs)
            items = response.get('Items', [])
            
            if not items:
                print(f"  ✓ 表 {table_name} 为空，无需清理")
                break
            
            # 批量删除项目
            with table.batch_writer() as batch:
                for item in items:
                    # 获取主键
                    key = {}
                    table_desc = dynamodb.meta.client.describe_table(TableName=table_name)
                    key_schema = table_desc['Table']['KeySchema']
                    
                    for key_attr in key_schema:
                        key_name = key_attr['AttributeName']
                        key_type = key_attr['KeyType']
                        # 从 item 中获取键值
                        if key_name in item:
                            key[key_name] = item[key_name]
                    
                    if key:
                        batch.delete_item(Key=key)
                        deleted_count += 1
                        
                        if deleted_count % 100 == 0:
                            print(f"  ⏳ 已删除 {deleted_count} 个项目...", end='\r', flush=True)
            
            start_key = response.get('LastEvaluatedKey')
            done = start_key is None
        
        print(f"\n  ✅ 表 {table_name} 清理完成，共删除 {deleted_count} 个项目")
        return deleted_count
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'ResourceNotFoundException':
            print(f"  ⚠️  表 {table_name} 不存在，跳过")
            return 0
        else:
            print(f"  ❌ 清理表 {table_name} 时出错: {e}")
            raise
    except Exception as e:
        print(f"  ❌ 清理表 {table_name} 时发生未知错误: {e}")
        raise


def get_table_item_count(dynamodb, table_name: str) -> int:
    """
    获取表中的项目数量（近似值）
    """
    try:
        response = dynamodb.meta.client.describe_table(TableName=table_name)
        return response['Table'].get('ItemCount', 0)
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            return 0
        raise


def main():
    parser = argparse.ArgumentParser(
        description='清理 Post Service 和 Timeline Service 的 DynamoDB 表数据',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 清理默认表（posts-table 和 posts-timeline-service）
  python scripts/clean_dynamodb.py
  
  # 清理指定表
  python scripts/clean_dynamodb.py --tables posts-table
  
  # 跳过确认提示
  python scripts/clean_dynamodb.py --confirm
        """
    )
    
    parser.add_argument(
        '--tables',
        nargs='+',
        default=['posts-table', 'posts-timeline-service'],
        help='要清理的 DynamoDB 表名（默认: posts-table posts-timeline-service）'
    )
    
    parser.add_argument(
        '--region',
        default='us-west-2',
        help='AWS 区域（默认: us-west-2）'
    )
    
    parser.add_argument(
        '--confirm',
        action='store_true',
        help='跳过确认提示，直接执行清理'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='仅显示将要清理的表和项目数量，不执行实际删除'
    )
    
    args = parser.parse_args()
    
    # 创建 DynamoDB 客户端
    try:
        dynamodb = boto3.resource('dynamodb', region_name=args.region)
        dynamodb_client = boto3.client('dynamodb', region_name=args.region)
    except Exception as e:
        print(f"❌ 无法连接到 AWS DynamoDB: {e}")
        print("   请确保已配置 AWS 凭证（aws configure 或环境变量）")
        sys.exit(1)
    
    # 显示将要清理的表信息
    print("=" * 60)
    print("🧹 DynamoDB 表清理工具")
    print("=" * 60)
    print(f"\n📋 目标表列表:")
    
    total_items = 0
    valid_tables = []
    
    for table_name in args.tables:
        try:
            count = get_table_item_count(dynamodb, table_name)
            print(f"  • {table_name}: {count:,} 个项目")
            total_items += count
            valid_tables.append(table_name)
        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                print(f"  • {table_name}: ⚠️  表不存在")
            else:
                print(f"  • {table_name}: ❌ 错误 - {e}")
    
    if not valid_tables:
        print("\n❌ 没有有效的表可以清理")
        sys.exit(1)
    
    print(f"\n📊 总计: {len(valid_tables)} 个表，约 {total_items:,} 个项目")
    
    # 确认提示
    if args.dry_run:
        print("\n🔍 这是 dry-run 模式，不会执行实际删除操作")
        sys.exit(0)
    
    if not args.confirm:
        print("\n⚠️  警告: 此操作将永久删除表中的所有数据，无法恢复！")
        response = input("是否继续？(yes/no): ").strip().lower()
        if response not in ['yes', 'y']:
            print("❌ 操作已取消")
            sys.exit(0)
    
    # 执行清理
    print("\n" + "=" * 60)
    print("🚀 开始清理...")
    print("=" * 60 + "\n")
    
    total_deleted = 0
    for table_name in valid_tables:
        try:
            deleted = delete_all_items(dynamodb, table_name, args.region)
            total_deleted += deleted
        except Exception as e:
            print(f"❌ 清理表 {table_name} 失败: {e}")
            continue
    
    # 总结
    print("\n" + "=" * 60)
    print("✨ 清理完成")
    print("=" * 60)
    print(f"📊 总计删除: {total_deleted:,} 个项目")
    print(f"📋 清理的表数: {len(valid_tables)}")
    print()


if __name__ == '__main__':
    main()

