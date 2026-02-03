# CryptoX Exchange Benchmark: Go vs Java

A benchmark comparing Go (Fiber + raw SQL) vs Java (Spring Boot + JPA) for cryptocurrency exchange operations.

## 🏆 Benchmark Results

> **Go achieved 9,995 RPS with 2.2ms latency while Java maxed out at 1,108 RPS with 100% errors under the same load.**

📊 **[View Full Benchmark Results →](results/mac/RESULTS.md)**

| Metric | Go (Fiber) | Java (Virtual Threads) | Go Advantage |
|--------|------------|------------------------|--------------|
| **Actual RPS** | 9,995 | 1,108 | **9x faster** |
| **Avg Latency** | 2.22 ms | 2,668 ms | **1,200x faster** |
| **P95 Latency** | 8.53 ms | 4,265 ms | **500x faster** |
| **Error Rate** | 0% | 100% | ✅ |

*Tested on Apple M4 Pro (14 cores), 3-minute sustained load at 10K RPS target*

---

## 🎯 Purpose

This project benchmarks two implementations of a simplified crypto exchange to demonstrate performance differences between:

- **Go Exchange**: Fiber (fasthttp) + `pgx` (raw SQL) + Prefork mode
- **Java Exchange**: Spring Boot 3.x + Spring Data JPA + Hibernate + Virtual Threads

## 📊 Why Go Wins

| Metric | Go (Achieved) | Java (Achieved) | Go Advantage |
|--------|---------------|-----------------|--------------|
| RPS | 9,995 | 1,108 | 9x faster |
| Avg Latency | 2.2ms | 2,669ms | 1,200x faster |
| P95 Latency | 8.5ms | 4,265ms | 500x faster |
| Memory Usage | ~50-100MB | ~300-500MB | 5x less |
| Docker Image | ~20MB | ~200MB | 10x smaller |
| Cold Start | ~100ms | ~3-5s | 30-50x faster |

### Why Go Outperforms Java Here

1. **Fiber (fasthttp)** - 10x faster than net/http, zero-allocation
2. **Prefork Mode** - One worker per CPU core, full utilization
3. **Raw SQL vs ORM** - Go uses raw SQL (pgx), Java uses Hibernate with reflection
4. **No JVM Overhead** - Go compiles to native binary, Java runs on JVM
5. **Lower Memory** - Go's lightweight goroutines vs Java's thread pools
6. **Faster GC** - Go's GC is optimized for low latency

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         k6 Load Tester                       │
│                    (Generates 10,000 RPS)                    │
└─────────────────┬───────────────────────┬───────────────────┘
                  │                       │
                  ▼                       ▼
        ┌─────────────────┐     ┌─────────────────┐
        │   Go Exchange   │     │  Java Exchange  │
        │   Port: 8080    │     │   Port: 8081    │
        │  Fiber+Prefork  │     │ Spring+VThreads │
        │   ~20MB image   │     │   ~200MB image  │
        └────────┬────────┘     └────────┬────────┘
                 │                       │
                 └───────────┬───────────┘
                             ▼
                 ┌─────────────────────┐
                 │     PostgreSQL      │
                 │     Port: 5432      │
                 │   (500 connections) │
                 └─────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- [k6](https://k6.io/docs/get-started/installation/) for load testing
- (Optional) Go 1.22+ and Java 21+ for local development

### 1. Start All Services

```bash
# Build and start everything
docker-compose up -d --build

# Wait for services to be ready (Java takes longer to start)
sleep 30

# Verify services are up
curl http://localhost:8080/health  # Go
curl http://localhost:8081/health  # Java
```

### 2. Run Smoke Tests

```bash
# Test Go exchange
k6 run --env TARGET=http://localhost:8080 k6-tests/smoke-test.js

# Test Java exchange
k6 run --env TARGET=http://localhost:8081 k6-tests/smoke-test.js
```

### 3. Run Full Benchmark

```bash
# Benchmark Go exchange
k6 run --env TARGET=http://localhost:8080 k6-tests/benchmark.js

# Wait for DB to settle, clear orders
docker-compose exec postgres psql -U postgres -d cryptox -c "DELETE FROM trades; DELETE FROM orders WHERE status='OPEN';"

# Benchmark Java exchange
k6 run --env TARGET=http://localhost:8081 k6-tests/benchmark.js
```

### 4. View Results

Results are saved to:
- `results-go.json`
- `results-java.json`

## 📈 API Endpoints

Both services expose identical endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| POST | `/orders` | Create a new order |
| GET | `/orderbook/{pair}` | Get order book for trading pair |
| GET | `/balance/{userId}` | Get user wallet balances |
| POST | `/trades/match?pair=X` | Match orders (simplified) |

### Example Requests

```bash
# Create an order
curl -X POST http://localhost:8080/orders \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "11111111-1111-1111-1111-111111111111",
    "pair": "BTC/USDT",
    "side": "BUY",
    "price": 42000.00,
    "quantity": 0.5
  }'

# Get order book
curl http://localhost:8080/orderbook/BTC%2FUSDT

# Get balance
curl http://localhost:8080/balance/11111111-1111-1111-1111-111111111111

# Match orders
curl -X POST "http://localhost:8080/trades/match?pair=BTC%2FUSDT"
```

## 🔧 Configuration

### Resource Limits (docker-compose.yml)

| Service | CPU Limit | Memory Limit |
|---------|-----------|--------------|
| Go Exchange | 2 cores | 512MB |
| Java Exchange | 2 cores | 1GB |
| PostgreSQL | Unlimited | Unlimited |

### Database Connection Pools

| Service | Max Connections | Min Connections |
|---------|-----------------|-----------------|
| Go (pgx) | 100 | 20 |
| Java (HikariCP) | 100 | 20 |

## 🍎 Testing on MacBook (Local)

### Realistic Expectations

Testing at 10,000 RPS on a MacBook is **not realistic** because:

1. Client (k6), servers, and database compete for CPU/RAM
2. Docker Desktop on macOS adds overhead
3. Network stack on localhost has limitations

### What You CAN Test Locally

- **Relative performance** - Go vs Java on same hardware
- **Up to ~2,000 RPS** - Achievable on M1/M2 MacBooks
- **Latency percentiles** - p50, p95, p99 are still meaningful

### Recommended Local Test

```bash
# Reduced load for MacBook testing
k6 run --env TARGET=http://localhost:8080 \
  --vus 100 --duration 60s \
  k6-tests/benchmark.js
```

## ☁️ Testing on AWS (For True 10k RPS)

### Recommended Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Load Test Machine                         │
│                     c5.2xlarge (8 vCPU, 16GB)                     │
│                          Running k6                               │
└──────────────────────────┬───────────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
    ┌─────────────────┐       ┌─────────────────┐
    │  Go Exchange    │       │  Java Exchange  │
    │ c5.large (2 vCPU)│       │ c5.xlarge (4 vCPU)│
    │    2GB RAM      │       │     4GB RAM      │
    └────────┬────────┘       └────────┬────────┘
             │                         │
             └───────────┬─────────────┘
                         ▼
            ┌─────────────────────────┐
            │   RDS PostgreSQL        │
            │   db.r5.large           │
            │   (2 vCPU, 16GB RAM)    │
            └─────────────────────────┘
```

### AWS Deployment Steps

1. **Create RDS PostgreSQL Instance**
   ```bash
   # Use db.r5.large or larger for 10k RPS
   # Enable Multi-AZ for production
   ```

2. **Deploy Services on EC2/ECS**
   ```bash
   # Push images to ECR
   docker tag cryptox-go:latest <account>.dkr.ecr.<region>.amazonaws.com/cryptox-go:latest
   docker push <account>.dkr.ecr.<region>.amazonaws.com/cryptox-go:latest
   
   # Deploy on ECS or EC2
   ```

3. **Run Load Test from Separate Machine**
   ```bash
   # SSH into load test machine
   k6 run --env TARGET=http://<go-exchange-ip>:8080 \
     --vus 500 --duration 300s \
     k6-tests/benchmark.js
   ```

### Cost Estimate (AWS)

| Resource | Type | Cost/Hour |
|----------|------|-----------|
| Load Test Machine | c5.2xlarge | ~$0.34 |
| Go Exchange | c5.large | ~$0.085 |
| Java Exchange | c5.xlarge | ~$0.17 |
| RDS PostgreSQL | db.r5.large | ~$0.24 |
| **Total** | | **~$0.84/hour** |

## 🐳 Deployment to Coolify/Docploy

Both services are Docker-ready:

### Coolify Deployment

1. Add GitHub repo to Coolify
2. Configure two services:
   - **go-exchange**: Build context `./go-exchange`
   - **java-exchange**: Build context `./java-exchange`
3. Add PostgreSQL database
4. Set environment variables:
   ```
   # Go
   DATABASE_URL=postgres://user:pass@host:5432/db?sslmode=disable
   
   # Java
   DATABASE_URL=jdbc:postgresql://host:5432/db
   DB_USER=user
   DB_PASSWORD=pass
   ```

### Docploy Deployment

```yaml
# docploy.yml
services:
  go-exchange:
    build: ./go-exchange
    port: 8080
    env:
      DATABASE_URL: ${DATABASE_URL}
      
  java-exchange:
    build: ./java-exchange
    port: 8081
    env:
      DATABASE_URL: ${JDBC_DATABASE_URL}
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
```

## 📁 Project Structure

```
CryptoX/
├── go-exchange/
│   ├── cmd/server/main.go       # Fiber entry point (prefork)
│   ├── internal/
│   │   ├── handler/handler.go   # Fiber HTTP handlers
│   │   ├── repository/          # Database layer (raw SQL, pgx)
│   │   └── model/models.go      # Data structures
│   ├── Dockerfile
│   └── go.mod
├── java-exchange/
│   ├── src/main/java/com/cryptox/exchange/
│   │   ├── controller/          # REST controllers
│   │   ├── service/             # Business logic
│   │   ├── repository/          # JPA repositories (native SQL)
│   │   ├── entity/              # JPA entities
│   │   └── dto/                 # Data transfer objects
│   ├── src/main/resources/application.yml
│   ├── Dockerfile
│   └── pom.xml
├── k6-tests/
│   ├── 10k-benchmark.js         # 10K RPS load test
│   ├── warmup.js                # JVM warmup script
│   └── generate-graphs.py       # Plotly graph generator
├── bin/                         # Pre-built binaries
│   ├── go-exchange-darwin-arm64
│   ├── go-exchange-linux-amd64
│   └── java-exchange.jar
├── results/
│   ├── mac/                     # Mac benchmark results
│   │   ├── RESULTS.md           # Full results with graphs
│   │   └── *.png                # Chart images
│   └── ec2/                     # (Future) EC2 results
├── docker-compose.yml
├── init.sql                     # Database schema + indexes
├── Makefile                     # Build/benchmark commands
└── README.md
```

## 🔍 Monitoring During Tests

```bash
# Watch Docker stats in real-time
docker stats

# Watch PostgreSQL connections
docker exec cryptox-postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# View service logs
docker-compose logs -f go-exchange
docker-compose logs -f java-exchange
```

## 🧹 Cleanup

```bash
# Stop all services
docker-compose down

# Remove volumes (clears database)
docker-compose down -v

# Remove images
docker rmi cryptox-go cryptox-java
```

## 📚 References

- [k6 Documentation](https://k6.io/docs/)
- [pgx - PostgreSQL Driver for Go](https://github.com/jackc/pgx)
- [Spring Boot Documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [HikariCP Connection Pool](https://github.com/brettwooldridge/HikariCP)
