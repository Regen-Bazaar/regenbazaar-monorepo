#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting Anvil...${NC}"
# Start Anvil in the background with the first account pre-funded
anvil --block-time 5 &
ANVIL_PID=$!

# Wait for Anvil to start
sleep 2

# First Anvil account private key
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

echo -e "${BLUE}Deploying all contracts...${NC}"
# Deploy all contracts using the first Anvil account 
forge script script/deploy/DeployAll.s.sol:DeployAll --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# Kill Anvil when done
kill $ANVIL_PID

echo -e "${GREEN}Deployment complete!${NC}" 