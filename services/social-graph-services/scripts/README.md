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

### Option 1: Using Shell Script (Linux/Mac)

```bash
# Load 5,000 users (default)
./load_test_data.sh

# Load 25,000 users
./load_test_data.sh 25000

# Load 100,000 users
./load_test_data.sh 100000
```

### Option 2: Using PowerShell Script (Windows)

```powershell
# Load 5,000 users (default)
.\load_test_data.ps1

# Load 25,000 users
.\load_test_data.ps1 -Users 25000

# Load 100,000 users
.\load_test_data.ps1 -Users 100000
```

### Option 3: Using Python Directly

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

```bash
export FOLLOWERS_TABLE_NAME=my-followers
export FOLLOWING_TABLE_NAME=my-following
export AWS_REGION=us-east-1
./load_test_data.sh 5000
```

## Data Distribution

### User Segments (for any total N)

| Segment | Percentage | Follower Range | Following Range |
|---------|-----------|----------------|-----------------|
| Small   | 80%       | Low            | Low-Medium      |
| Medium  | 15%       | Medium         | Low-Medium      |
| Big     | 4.99%     | High           | Low             |
| Top     | 0.01%     | Very High      | Very Low        |

### Specific Ranges by User Count

**5,000 users:**
- Small: 1-99 followers, 1-49 following
- Medium: 100-499 followers, 1-49 following
- Big: 500-1,999 followers, 0-25 following
- Top: 2,000-4,999 followers, 0-25 following

**25,000 users:**
- Small: 1-499 followers, 1-299 following
- Medium: 500-2,499 followers, 1-299 following
- Big: 2,500-9,999 followers, 0-125 following
- Top: 10,000-24,999 followers, 0-125 following

**100,000 users:**
- Small: 1-1,999 followers, 1-999 following
- Medium: 2,000-9,999 followers, 1-999 following
- Big: 10,000-39,999 followers, 0-500 following
- Top: 40,000-99,999 followers, 0-500 following

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
- 5,000 users: ~30 seconds
- 25,000 users: ~2 minutes
- 100,000 users: ~10 minutes

*Note: Times may vary based on network speed and DynamoDB provisioned capacity.*

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

## Core Modules

- **`core/segmenter.py`**: User segmentation logic
- **`core/generator.py`**: Relationship generation with power-law distribution
- **`load_dynamodb.py`**: Main script to load data into DynamoDB

## Related Files

- **`generate_test_local.py`**: Generate CSV files for local testing (deprecated for production use)
- **`tests/test_relationships.py`**: Unit tests for relationship generation
