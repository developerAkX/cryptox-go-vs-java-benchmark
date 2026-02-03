#!/bin/bash

# CryptoX Benchmark Runner
# Runs load tests against both Go and Java exchanges and compares results

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           CryptoX Exchange Benchmark Suite                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"

# Check if services are running
check_service() {
    local url=$1
    local name=$2
    if curl -s "$url/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name is running"
        return 0
    else
        echo -e "${YELLOW}✗${NC} $name is not running"
        return 1
    fi
}

# Check prerequisites
echo -e "\n${BLUE}[1/5] Checking prerequisites...${NC}"

if ! command -v k6 &> /dev/null; then
    echo "k6 is not installed. Install it with:"
    echo "  brew install k6  (macOS)"
    echo "  sudo apt install k6  (Ubuntu)"
    exit 1
fi
echo -e "${GREEN}✓${NC} k6 is installed"

if ! command -v docker &> /dev/null; then
    echo "Docker is not installed"
    exit 1
fi
echo -e "${GREEN}✓${NC} Docker is installed"

# Start services if not running
echo -e "\n${BLUE}[2/5] Checking services...${NC}"

GO_RUNNING=true
JAVA_RUNNING=true

check_service "http://localhost:8080" "Go Exchange" || GO_RUNNING=false
check_service "http://localhost:8081" "Java Exchange" || JAVA_RUNNING=false

if [ "$GO_RUNNING" = false ] || [ "$JAVA_RUNNING" = false ]; then
    echo -e "\n${YELLOW}Starting services with docker-compose...${NC}"
    docker-compose up -d --build
    
    echo "Waiting for services to be ready..."
    sleep 30
    
    # Verify again
    check_service "http://localhost:8080" "Go Exchange" || { echo "Go Exchange failed to start"; exit 1; }
    check_service "http://localhost:8081" "Java Exchange" || { echo "Java Exchange failed to start"; exit 1; }
fi

# Clear old orders for fair test
echo -e "\n${BLUE}[3/5] Resetting database state...${NC}"
docker exec cryptox-postgres psql -U postgres -d cryptox -c "DELETE FROM trades; UPDATE orders SET status='CANCELLED' WHERE status='OPEN';" > /dev/null 2>&1 || true
echo -e "${GREEN}✓${NC} Database reset"

# Run Go benchmark
echo -e "\n${BLUE}[4/5] Running Go Exchange benchmark...${NC}"
echo "This will take approximately 5 minutes..."
k6 run --env TARGET=http://localhost:8080 k6-tests/benchmark.js 2>&1 | tee /tmp/go-results.txt

# Reset database between tests
echo -e "\n${YELLOW}Resetting database for Java test...${NC}"
docker exec cryptox-postgres psql -U postgres -d cryptox -c "DELETE FROM trades; UPDATE orders SET status='CANCELLED' WHERE status='OPEN';" > /dev/null 2>&1 || true
sleep 5

# Run Java benchmark
echo -e "\n${BLUE}[5/5] Running Java Exchange benchmark...${NC}"
echo "This will take approximately 5 minutes..."
k6 run --env TARGET=http://localhost:8081 k6-tests/benchmark.js 2>&1 | tee /tmp/java-results.txt

# Summary
echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    BENCHMARK COMPLETE                        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${GREEN}Results saved to:${NC}"
echo "  - results-go.json"
echo "  - results-java.json"

echo -e "\n${YELLOW}Resource usage during test:${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo -e "\n${GREEN}To view detailed comparison, check the JSON files or run:${NC}"
echo "  cat results-go.json | jq '.metrics.http_req_duration.values'"
echo "  cat results-java.json | jq '.metrics.http_req_duration.values'"
