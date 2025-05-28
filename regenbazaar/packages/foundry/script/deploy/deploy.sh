#!/bin/bash

# Enable debugging
set -e

# Define colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if anvil is installed
if ! command -v anvil &> /dev/null; then
    echo -e "${RED}Error: anvil is not installed${NC}"
    exit 1
fi

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo -e "${RED}Error: forge is not installed${NC}"
    exit 1
fi

# Default RPC URL
RPC_URL="http://localhost:8545"

# Start anvil if --local flag is passed
ANVIL_PID=""
LOCAL_MODE=false

# Parse arguments
DEPLOY_ALL=false
START_ANVIL=false

for arg in "$@"; do
    case $arg in
        --local)
            START_ANVIL=true
            shift
            ;;
        --all)
            DEPLOY_ALL=true
            shift
            ;;
        --rpc=*)
            RPC_URL="${arg#*=}"
            shift
            ;;
        --help)
            echo "Usage: ./deploy.sh [options] [contract-number]"
            echo ""
            echo "Options:"
            echo "  --local          Start a local anvil chain and deploy to it"
            echo "  --all            Deploy all contracts in sequence"
            echo "  --rpc=URL        Use a specific RPC URL (default: http://localhost:8545)"
            echo ""
            echo "Examples:"
            echo "  ./deploy.sh --local --all                   Deploy all contracts to a local anvil chain"
            echo "  ./deploy.sh 1                               Deploy only the REBAZToken"
            echo "  ./deploy.sh --rpc=https://eth-sepolia... 3  Deploy ImpactProductStaking to Sepolia"
            exit 0
            ;;
    esac
done

# Start local anvil if requested
if [ "$START_ANVIL" = true ]; then
    echo -e "${BLUE}Starting local anvil chain...${NC}"
    anvil --block-time 5 &
    ANVIL_PID=$!
    
    # Give anvil time to start
    sleep 2
fi

cd ../..

# Deploy the contracts
echo -e "${BLUE}Deploying contracts to $RPC_URL${NC}"

if [ "$DEPLOY_ALL" = true ]; then
    # Deploy all contracts in sequence
    echo -e "${GREEN}Deploying all contracts...${NC}"
    forge script script/deploy/DeployAll.s.sol:DeployAll --rpc-url $RPC_URL --broadcast --via-ir
else
    # Deploy specific contract based on argument
    CONTRACT_NUM=$1
    
    if [ -z "$CONTRACT_NUM" ]; then
        echo -e "${RED}Error: No contract number specified${NC}"
        echo "Use --help for usage information"
        
        # Shutdown anvil if we started it
        if [ -n "$ANVIL_PID" ]; then
            kill $ANVIL_PID
        fi
        
        exit 1
    fi
    
    case $CONTRACT_NUM in
        1)
            echo -e "${GREEN}Deploying REBAZToken...${NC}"
            forge script script/deploy/1_DeployREBAZToken.s.sol:DeployREBAZToken --rpc-url $RPC_URL --broadcast --via-ir
            ;;
        2)
            echo -e "${GREEN}Deploying ImpactProductNFT...${NC}"
            forge script script/deploy/2_DeployImpactProductNFT.s.sol:DeployImpactProductNFT --rpc-url $RPC_URL --broadcast --via-ir
            ;;
        3)
            echo -e "${GREEN}Deploying ImpactProductStaking...${NC}"
            forge script script/deploy/3_DeployImpactProductStaking.s.sol:DeployImpactProductStaking --rpc-url $RPC_URL --broadcast --via-ir
            ;;
        4)
            echo -e "${GREEN}Deploying RegenMarketplace...${NC}"
            forge script script/deploy/4_DeployMarketplace.s.sol:DeployMarketplace --rpc-url $RPC_URL --broadcast --via-ir
            ;;
        5)
            echo -e "${GREEN}Deploying ImpactProductFactory...${NC}"
            forge script script/deploy/5_DeployImpactProductFactory.s.sol:DeployImpactProductFactory --rpc-url $RPC_URL --broadcast --via-ir
            ;;
        *)
            echo -e "${RED}Error: Invalid contract number${NC}"
            echo "Valid options are 1-5 or --all"
            ;;
    esac
fi

# Shutdown anvil if we started it
if [ -n "$ANVIL_PID" ]; then
    echo -e "${BLUE}Shutting down local anvil chain...${NC}"
    kill $ANVIL_PID
fi

echo -e "${GREEN}Deployment complete!${NC}" 