#!/bin/bash

echo "Generating 25,000 test users..."
python3 generate_test_data.py 25000 --url ${1:-http://localhost:8080} --concurrency 50