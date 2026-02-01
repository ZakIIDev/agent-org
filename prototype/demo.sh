#!/bin/bash

# Demo of the x402 Flow

echo "--- STEP 1: Attempt to access protected resource ---"
RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:3000/resource)
HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "Status: $HTTP_STATUS"
echo "Body: $BODY"

REFERENCE=$(echo "$BODY" | grep -oE '"reference":"[a-f0-9]+"' | cut -d'"' -f4)

echo -e "\n--- STEP 2: Payment Required ---"
echo "To proceed, we would normally pay 1.0 USDC to the address provided."
echo "Reference ID generated: $REFERENCE"

echo -e "\n--- STEP 3: Verification (Mock/Testing) ---"
echo "Wait for the partner to provide a txHash..."
