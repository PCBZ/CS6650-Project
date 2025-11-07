#!/bin/bash

echo "Generating 100,000 test users..."
echo "This may take several minutes..."
python3 generate_test_data.py 100000 --url ${1:-http://localhost:8080} --concurrency 100