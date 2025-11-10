# Social Graph Service Testing Guide

## 📋 Script Overview

### Production Scripts (Keep)

#### 1. **Data Generation & Loading**
- `services/social-graph-services/scripts/load_test_data_validated.ps1` ⭐ **PRIMARY** (Windows)
- `services/social-graph-services/scripts/generate_and_load_validated.sh` ⭐ **PRIMARY** (Linux/macOS)
- Purpose: Generate social graph data with user validation via gRPC
- Features:
  - Validates users exist in user-service
  - Dynamic scaling based on user count
  - Configurable via `core/config.py`

#### 2. **Legacy Data Generation (Fallback)**
- `services/social-graph-services/scripts/load_test_data.ps1` (Windows)
- `services/social-graph-services/scripts/generate_and_load.sh` (Linux/macOS)
- Purpose: Quick data generation without user validation
- Use case: Local testing, no gRPC access

#### 3. **API Testing**
- `test-social-graph-full.ps1` ⭐ **PRIMARY** (Project root)
- Purpose: Comprehensive HTTP API and gRPC endpoint testing
- Tests: Health, counts, lists, pagination, relationships

#### 4. **Deployment**
- `deploy-social-graph.ps1` (Project root, Windows)
- `deploy-social-graph.sh` (Project root, Linux/macOS)
- Purpose: Build Docker image, push to ECR, update ECS

### Utility Scripts (Keep)

#### 5. **Configuration & Debug**
- `services/social-graph-services/scripts/tests/show_config.py` - Display current config
- `services/social-graph-services/scripts/tests/test_dynamic_scaling.py` - Test scaling across user counts
- `services/social-graph-services/scripts/tests/debug_generator.py` - Debug user segmentation

#### 6. **Core Modules**
- `services/social-graph-services/scripts/core/config.py` - Central configuration
- `services/social-graph-services/scripts/core/segmenter.py` - User segmentation logic
- `services/social-graph-services/scripts/core/generator.py` - Relationship generation

### Deprecated Scripts (Can Remove)

#### 7. **Old Test Scripts**
- `services/social-graph-services/scripts/tests/generate_test_local.py` - Superseded by new generator
- `services/social-graph-services/scripts/tests/test_generate_local.py` - Old local testing
- `services/social-graph-services/scripts/load_test_data.sh` - Duplicate of bash version

---

## 🚀 Complete Testing Workflow

### Step 1: Generate Test Data

**Option A: With User Validation (Recommended for Production)**
```powershell
# From VPC (Service Connect)
cd services/social-graph-services/scripts
.\load_test_data_validated.ps1 -GrpcEndpoint "user-service-grpc:50051" -MaxUsers 5000

# Skip validation (local testing)
.\load_test_data_validated.ps1 -SkipValidation -MaxUsers 5000
```

**Option B: Quick Generation (No Validation)**
```powershell
cd services/social-graph-services/scripts
.\load_test_data.ps1 -Users 5000
```

### Step 2: Test API Endpoints

```powershell
# From project root
.\test-social-graph-full.ps1
```

Expected output:
```
✅ HTTP API Endpoints:
   • Health check
   • Get follower/following counts
   • Get followers/following lists
   • Check relationships
   • Pagination support

📌 Key Endpoints:
   GET  http://ALB-DNS/api/social-graph/health
   GET  http://ALB-DNS/api/social-graph/followers/{userId}/count
   GET  http://ALB-DNS/api/social-graph/following/{userId}/count
   GET  http://ALB-DNS/api/social-graph/{userId}/followers
   GET  http://ALB-DNS/api/social-graph/{userId}/following
   GET  http://ALB-DNS/api/social-graph/relationship/check?followerId=X&targetId=Y
```

### Step 3: Verify Data Distribution

```powershell
# Check scaling across different user counts
cd services/social-graph-services/scripts/tests
python test_dynamic_scaling.py
```

Expected output:
```
📊 5,000 Users:
    Tier       Count      Pct      Followers Range           Following Range
    ---------- ---------- -------- ------------------------- -------------------------
    small      4,000      80.00  %      0-50               10-50
    medium     750        15.00  %     50-150              10-50
    big        249        4.98   %    300-700               5-25
    top        1          0.02   %  1,500-2,500             5-25
```

### Step 4: Inspect Configuration

```powershell
cd services/social-graph-services/scripts
python core/config.py
```

---

## 📊 Test Data Characteristics

### User Segmentation (Configurable via `core/config.py`)
| Tier | Percentage | Follower Range (% of total) | Following Range |
|------|-----------|----------------------------|-----------------|
| Small | 80% | 0.01% - 1% | 0.2% - 1% |
| Medium | 15% | 1% - 3% | 0.2% - 1% |
| Big | 4.99% | 6% - 14% | 0.1% - 0.5% |
| Top | 0.01% | 30% - 50% | 0.1% - 0.5% |

### Example Distributions

**1,000 Users:**
- Small: 0-10 followers
- Medium: 10-30 followers
- Big: 60-140 followers
- Top: 300-500 followers

**5,000 Users:**
- Small: 0-50 followers
- Medium: 50-150 followers
- Big: 300-700 followers
- Top: 1,500-2,500 followers

**100,000 Users:**
- Small: 10-1,000 followers
- Medium: 1,000-3,000 followers
- Big: 6,000-14,000 followers
- Top: 30,000-50,000 followers

---

## 🔧 Customizing Test Configuration

Edit `services/social-graph-services/scripts/core/config.py`:

```python
# Change user tier ratios
USER_TIER_RATIOS = {
    "small": 0.80,      # 80%
    "medium": 0.15,     # 15%
    "big": 0.0499,      # 4.99%
    "top": 0.0001       # 0.01%
}

# Adjust follower ranges (% of total users)
FOLLOWER_RATIOS = {
    "small": (0.0001, 0.01),    # 0.01% to 1%
    "medium": (0.01, 0.03),      # 1% to 3%
    "big": (0.06, 0.14),         # 6% to 14%
    "top": (0.30, 0.50)          # 30% to 50%
}

# Change tier weights for follower selection
TIER_WEIGHTS = {
    "small": 1,
    "medium": 3,
    "big": 10,
    "top": 50
}

# Modify random seed (or set to None for randomness)
SEGMENTATION_SEED = 42
```

---

## 🧹 Cleanup Recommendations

### Scripts to Keep
✅ `load_test_data_validated.ps1` / `generate_and_load_validated.sh` - Primary data loaders  
✅ `load_test_data.ps1` / `generate_and_load.sh` - Fallback loaders  
✅ `test-social-graph-full.ps1` - API testing  
✅ `deploy-social-graph.ps1` / `deploy-social-graph.sh` - Deployment  
✅ All `core/*.py` modules - Core functionality  
✅ `tests/show_config.py`, `tests/test_dynamic_scaling.py` - Utilities

### Scripts to Remove (Optional)
❌ `tests/generate_test_local.py` - Superseded by new generator  
❌ `tests/test_generate_local.py` - Old local testing  
❌ `load_test_data.sh` - Duplicate (keep `generate_and_load.sh` instead)

---

## 📚 Documentation Files

- `services/social-graph-services/scripts/README.md` - General usage guide
- `services/social-graph-services/scripts/USER_VALIDATION.md` - gRPC validation details
- `services/social-graph-services/docs/DYNAMODB_SCHEMA.md` - DynamoDB table structure

---

## 🐛 Troubleshooting

### Data Generation Issues
```powershell
# Check configuration
python core/config.py

# Verify segmentation logic
python tests/debug_generator.py

# Test scaling
python tests/test_dynamic_scaling.py
```

### API Testing Issues
```powershell
# Update ALB DNS in test-social-graph-full.ps1
$ALB_DNS = "your-alb-dns.elb.amazonaws.com"

# Check ECS service status
aws ecs describe-services --cluster social-graph-service --services social-graph-service --region us-west-2
```

### gRPC Validation Issues
```powershell
# Use skip validation flag
.\load_test_data_validated.ps1 -SkipValidation -MaxUsers 5000

# Or verify gRPC endpoint accessibility
grpcurl -plaintext user-service-grpc:50051 list
```

---

## 🎯 Quick Reference

| Task | Command |
|------|---------|
| Generate 5K users (validated) | `.\load_test_data_validated.ps1 -GrpcEndpoint "user-service-grpc:50051" -MaxUsers 5000` |
| Generate 5K users (no validation) | `.\load_test_data_validated.ps1 -SkipValidation -MaxUsers 5000` |
| Test all API endpoints | `.\test-social-graph-full.ps1` |
| Show current config | `python core/config.py` |
| Test scaling | `python tests/test_dynamic_scaling.py` |
| Deploy service | `.\deploy-social-graph.ps1` |
