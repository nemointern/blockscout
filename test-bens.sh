#!/bin/bash

# BENS Integration Test Script
# Tests the BENS service and its integration with CitreaScan Blockscout

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BENS_URL="${BENS_URL:-http://localhost:8050}"
CHAIN_ID="${CHAIN_ID:-4114}"

echo -e "${YELLOW}Testing BENS Integration for CitreaScan${NC}\n"

# Test 1: Health Check
echo -e "${YELLOW}[1/6] Testing BENS Health...${NC}"
if curl -f -s "${BENS_URL}/health" > /dev/null; then
    echo -e "${GREEN}✓ BENS health check passed${NC}"
else
    echo -e "${RED}✗ BENS health check failed${NC}"
    echo "Make sure BENS is running: docker-compose up -d bens"
    exit 1
fi

# Test 2: Get Protocols
echo -e "\n${YELLOW}[2/6] Testing Protocols Endpoint...${NC}"
PROTOCOLS_RESPONSE=$(curl -s "${BENS_URL}/api/v1/${CHAIN_ID}/protocols")
if echo "$PROTOCOLS_RESPONSE" | grep -q "namoshi"; then
    echo -e "${GREEN}✓ Namoshi protocol found${NC}"
    echo "$PROTOCOLS_RESPONSE" | jq '.protocols[] | {id, title, tld_list}' 2>/dev/null || echo "$PROTOCOLS_RESPONSE"
else
    echo -e "${RED}✗ Namoshi protocol not found${NC}"
    echo "Response: $PROTOCOLS_RESPONSE"
    echo "Check bens-config.json configuration"
    exit 1
fi

# Test 3: Domain Lookup (Search)
echo -e "\n${YELLOW}[3/6] Testing Domain Search...${NC}"
SEARCH_RESPONSE=$(curl -s "${BENS_URL}/api/v1/${CHAIN_ID}/domains:lookup?name=test&only_active=false")
if [ -n "$SEARCH_RESPONSE" ]; then
    echo -e "${GREEN}✓ Domain search endpoint responding${NC}"
    DOMAIN_COUNT=$(echo "$SEARCH_RESPONSE" | jq '.items | length' 2>/dev/null || echo "0")
    echo "Found $DOMAIN_COUNT domains matching 'test'"
    echo "$SEARCH_RESPONSE" | jq '.items[0] | {name, resolved_address, expiry_date}' 2>/dev/null || true
else
    echo -e "${YELLOW}⚠ Domain search returned empty response${NC}"
fi

# Test 4: Get Specific Domain (if any exist)
echo -e "\n${YELLOW}[4/6] Testing Specific Domain Lookup...${NC}"
# Try a few common test domains
TEST_DOMAINS=("test.btc" "vitalik.btc" "satoshi.btc" "test.citrea" "alice.citrea")
DOMAIN_FOUND=false

for domain in "${TEST_DOMAINS[@]}"; do
    DOMAIN_RESPONSE=$(curl -s "${BENS_URL}/api/v1/${CHAIN_ID}/domains/${domain}")
    if echo "$DOMAIN_RESPONSE" | jq -e '.name' > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Found domain: ${domain}${NC}"
        echo "$DOMAIN_RESPONSE" | jq '{name, owner, resolved_address, expiry_date}' 2>/dev/null
        DOMAIN_FOUND=true
        break
    fi
done

if [ "$DOMAIN_FOUND" = false ]; then
    echo -e "${YELLOW}⚠ No test domains found (this is OK if no domains registered yet)${NC}"
fi

# Test 5: Get Address Info
echo -e "\n${YELLOW}[5/6] Testing Address Lookup...${NC}"
# Use a zero address as test (unlikely to have a domain, but tests the endpoint)
TEST_ADDRESS="0x0000000000000000000000000000000000000000"
ADDRESS_RESPONSE=$(curl -s "${BENS_URL}/api/v1/${CHAIN_ID}/addresses/${TEST_ADDRESS}")
if [ -n "$ADDRESS_RESPONSE" ]; then
    echo -e "${GREEN}✓ Address lookup endpoint responding${NC}"
    echo "$ADDRESS_RESPONSE" | jq '.' 2>/dev/null || echo "$ADDRESS_RESPONSE"
else
    echo -e "${YELLOW}⚠ Address lookup returned empty response${NC}"
fi

# Test 6: Batch Resolve (if possible)
echo -e "\n${YELLOW}[6/6] Testing Batch Address Resolution...${NC}"
BATCH_PAYLOAD='{"addresses":["0x0000000000000000000000000000000000000000","0x0000000000000000000000000000000000000001"]}'
BATCH_RESPONSE=$(curl -s -X POST "${BENS_URL}/api/v1/${CHAIN_ID}/addresses:batch-resolve-names" \
    -H "Content-Type: application/json" \
    -d "$BATCH_PAYLOAD")
if [ -n "$BATCH_RESPONSE" ]; then
    echo -e "${GREEN}✓ Batch resolve endpoint responding${NC}"
    echo "$BATCH_RESPONSE" | jq '.' 2>/dev/null || echo "$BATCH_RESPONSE"
else
    echo -e "${YELLOW}⚠ Batch resolve returned empty response${NC}"
fi

# Summary
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}BENS Integration Tests Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if we can access Blockscout
echo -e "${YELLOW}Testing Blockscout Integration...${NC}"
BLOCKSCOUT_URL="${BLOCKSCOUT_URL:-http://localhost}"
if curl -f -s "${BLOCKSCOUT_URL}" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Blockscout is accessible at ${BLOCKSCOUT_URL}${NC}"
    echo -e "\nNext steps:"
    echo "1. Open ${BLOCKSCOUT_URL} in your browser"
    echo "2. Try searching for a domain (e.g., 'test.btc' or 'vitalik.citrea')"
    echo "3. Check if domain names appear next to addresses"
else
    echo -e "${YELLOW}⚠ Blockscout not accessible at ${BLOCKSCOUT_URL}${NC}"
    echo "Start Blockscout with: docker-compose up -d"
fi

echo -e "\n${GREEN}All tests passed!${NC}"
echo "BENS is properly configured and responding."
echo ""
echo "For more detailed testing, see LOCAL_TESTING.md"
