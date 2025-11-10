# Social Graph Service Data Loading

This directory contains scripts to generate and load test data into DynamoDB tables for the social-graph-service.

## Overview

The data loading process:
1. **Segments users** into 4 categories (Small 80%, Medium 15%, Big 4.99%, Top 0.01%)
2. **Generates relationships** using power-law distribution to simulate realistic social networks
3. **Enforces constraints** on follower/following counts per segment
4. **Loads data** into two DynamoDB tables (followers and following)

## Prerequisites

- Python 3.7+
- AWS credentials configured (via `aws configure` or environment variables)
- DynamoDB tables created:
  - `social-graph-followers` (or custom name)
  - `social-graph-following` (or custom name)

## Installation

Install Python dependencies:

```bash
pip install -r requirements.txt
```

## Usage

### Quick Start (Recommended)

**Linux/macOS/WSL:**
```bash
# Load 5,000 users (default)
./generate_and_load.sh

# Load custom number of users
./generate_and_load.sh --users 25000

# Custom configuration
./generate_and_load.sh \
    --users 10000 \
    --region us-east-1 \
    --followers-table my-followers \
    --following-table my-following

# Show help
./generate_and_load.sh --help
```

**Windows (PowerShell):**
```powershell
# Load 5,000 users (default)
.\load_test_data.ps1

# Load custom number of users
.\load_test_data.ps1 -Users 25000

# Custom configuration
.\load_test_data.ps1 `
    -Users 10000 `
    -AwsRegion us-east-1 `
    -FollowersTable my-followers `
    -FollowingTable my-following
```

### Advanced: Using Python Directly

```bash
# Basic usage
python load_dynamodb.py --users 5000

# Custom table names
python load_dynamodb.py \
    --users 25000 \
    --followers-table my-followers-table \
    --following-table my-following-table \
    --region us-east-1

# Quiet mode (less verbose)
python load_dynamodb.py --users 100000 --quiet
```

## Environment Variables

You can set these environment variables to customize the defaults:

- `FOLLOWERS_TABLE_NAME`: Name of the followers table (default: `social-graph-followers`)
- `FOLLOWING_TABLE_NAME`: Name of the following table (default: `social-graph-following`)
- `AWS_REGION`: AWS region (default: `us-west-2`)

Example:

**Bash:**
```bash
export FOLLOWERS_TABLE_NAME=my-followers
export FOLLOWING_TABLE_NAME=my-following
export AWS_REGION=us-east-1
./generate_and_load.sh --users 5000
```

**PowerShell:**
```powershell
$env:FOLLOWERS_TABLE_NAME="my-followers"
$env:FOLLOWING_TABLE_NAME="my-following"
$env:AWS_REGION="us-east-1"
.\load_test_data.ps1 -Users 5000
```

## Data Distribution

### User Segments (for any total N)

| Segment | Percentage | Follower Range | Following Range |
|---------|-----------|----------------|-----------------|
| Small   | 80%       | Low            | Low-Medium      |
| Medium  | 15%       | Medium         | Low-Medium      |
| Big     | 4.99%     | High           | Low             |
| Top     | 0.01%     | Very High      | Very Low        |

### Specific Targets by User Count

**5,000 users:**
- Small (4,000 users): **1 follower** each, 1-50 following
- Medium (750 users): **100 followers** each, 1-50 following
- Big (249 users): **500 followers** each, 0-30 following
- Top (1 user): **2,000 followers**, 0-50 following

*Example: User 913 is consistently the Top tier user with exactly 2,000 followers*

**25,000 users:**
- Small (20,000 users): **1 follower** each
- Medium (3,750 users): **500 followers** each
- Big (1,247 users): **2,500 followers** each
- Top (3 users): **10,000 followers** each

**100,000 users:**
- Small (80,000 users): **1 follower** each
- Medium (15,000 users): **2,000 followers** each
- Big (4,990 users): **10,000 followers** each
- Top (10 users): **40,000 followers** each

> **Note:** The generator uses a fixed random seed (42) to ensure reproducible user-to-tier assignments across multiple runs.

## DynamoDB Table Structure

### Followers Table

```
{
  "user_id": "12345",                    // String (Primary Key)
  "follower_ids": ["101", "202", "303"]  // List of Strings
}
```

### Following Table

```
{
  "user_id": "12345",                     // String (Primary Key)
  "following_ids": ["404", "505", "606"]  // List of Strings
}
```

## Testing

Run unit tests to validate the generated data:

```bash
cd tests
pytest test_relationships.py -v
```

## Performance

Loading times (approximate):
- 5,000 users (~205K relationships): ~30 seconds
- 25,000 users (~2.56M relationships): ~3-5 minutes
- 100,000 users (~40M relationships): ~15-20 minutes

*Note: Times may vary based on network speed and DynamoDB capacity mode.*

## Validation

After loading data, verify the results:

**Check follower counts:**
```bash
# Via API (replace with your ALB DNS)
curl http://YOUR-ALB-DNS/api/social-graph/followers/913/count

# Via DynamoDB directly
aws dynamodb get-item \
    --table-name social-graph-followers \
    --key '{"user_id": {"N": "913"}}' \
    --region us-west-2
```

**Expected results for 5,000 users:**
- User 913 (Top tier): 2,000 followers
- User 1 (Small tier): 1 follower
- User 100 (Small tier): 1 follower

**Run comprehensive tests:**
```powershell
# From project root
.\test-social-graph-full.ps1
```

## Troubleshooting

### AWS Credentials Not Found

```
NoCredentialsError: Unable to locate credentials
```

**Solution:** Configure AWS credentials:
```bash
aws configure
```

### Table Does Not Exist

```
ResourceNotFoundException: Requested resource not found
```

**Solution:** Create the DynamoDB tables first using Terraform:
```bash
cd ../terraform
terraform apply
```

### Rate Limiting

If you see `ProvisionedThroughputExceededException`, the script will automatically retry with exponential backoff. For large datasets (100K+ users), consider using DynamoDB on-demand billing mode.

## Scripts Overview

### Main Scripts
- **`generate_and_load.sh`** ✅ - Bash script with comprehensive checks (Linux/macOS/WSL)
- **`load_test_data.ps1`** ✅ - PowerShell script (Windows)
- **`load_dynamodb.py`** - Core Python loader (called by both scripts)

### Core Modules
- **`core/segmenter.py`** - User segmentation logic with fixed random seed
- **`core/generator.py`** - Relationship generation with weighted power-law distribution

### Legacy/Testing
- **`generate_test_local.py`** - Generate CSV files for local testing
- **`tests/debug_generator.py`** - Debug script to verify user segments
- **`tests/test_relationships.py`** - Unit tests for relationship generation

## Architecture

```
generate_and_load.sh (Bash) ──┐
load_test_data.ps1 (PowerShell) ──┼──> load_dynamodb.py ──┐
                                  │                        │
                                  └────────────────────────┴──> core/segmenter.py
                                                              └──> core/generator.py
                                                              └──> DynamoDB (batch write)
```
