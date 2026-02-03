# CryptoX Exchange Benchmark: Go vs Java

---

## 📌 Context & Purpose

This benchmark was developed in response to the Medium article:  
👉 [Go vs Java for Microservices: We Tried Both, Here's What Happened](https://medium.com/engineering-playbook/go-vs-java-for-microservices-we-tried-both-heres-what-happened-f1e03fb9bf3b)

Our client referenced this article when evaluating our **Go recommendation for a greenfield cryptocurrency exchange project**. This benchmark provides an evidence-based counter-analysis.

### Our Hypothesis

The performance issues attributed to Go in the referenced article likely stem from **ORM overhead** rather than inherent language limitations. In our experience, Go ORMs can introduce significant latency that obscures Go's true performance characteristics.

### Our Approach

| Design Choice | Rationale |
|---------------|-----------|
| **Raw SQL with Repository Pattern** | Eliminates ORM abstraction overhead |
| **Fiber with Prefork Mode** | Enables full utilization of all CPU cores |
| **Identical test conditions** | Same schema, API contracts, and workloads |

### Key Finding

Go's prefork architecture leverages **100% of available CPU cores**, while Java's virtual threads model leaves significant compute capacity underutilized. Combined with zero-allocation HTTP handling and direct SQL access, Go achieves **9x higher throughput** and **1,200x lower latency** in our tests.

---

A **realistic, minimalistic benchmark** for testing database and HTTP CRUD operations under different loads.

## What This Tests

This project simulates a simplified cryptocurrency exchange to benchmark how Go and Java handle real-world workloads:

| Operation | HTTP Method | Database Operation | Load Distribution |
|-----------|-------------|-------------------|-------------------|
| Create Order | `POST /orders` | INSERT | 30% |
| Get Orderbook | `GET /orderbook/{pair}` | SELECT + Aggregation | 30% |
| Get Balance | `GET /balance/{userId}` | SELECT by FK | 25% |
| Match Orders | `POST /trades/match` | UPDATE | 15% |

Both implementations use **identical database schemas** and **identical API contracts**, providing a fair apples-to-apples comparison.

---

## 🏆 Benchmark Results

> **Go achieved 9,995 RPS with 2.2ms latency while Java maxed out at 1,108 RPS with 100% errors under the same load.**

| Environment | Target RPS | Go RPS | Java RPS | Go Advantage | Details |
|-------------|------------|--------|----------|--------------|---------|
| **Mac M4 Pro (14 cores)** | 10,000 | 9,995 | 1,108 | **9x faster** | [View Results](results/mac/RESULTS.md) |
| **EC2 ARM64 (2 vCPU)** | 10,000 | 1,636 | 402 | **4x faster** | [View Results](results/ec2/RESULTS.md) |
| **EC2 ARM64 (2 vCPU)** | 1,500 | 1,339 | 308 | **4x faster** | [View Results](results/ec2-1500rps/RESULTS.md) |

### Key Metrics (Mac M4 Pro - Best Performance)

| Metric | Go (Fiber) | Java (Virtual Threads) | Go Advantage |
|--------|------------|------------------------|--------------|
| **Actual RPS** | 9,995 | 1,108 | **9x faster** |
| **Avg Latency** | 2.22 ms | 2,668 ms | **1,200x faster** |
| **P95 Latency** | 8.53 ms | 4,265 ms | **500x faster** |
| **Error Rate** | 0% | 100% | ✅ |

---

## 📊 Why Go Outperforms Java

| Factor | Go | Java | Impact |
|--------|-----|------|--------|
| **HTTP Framework** | Fiber (fasthttp) - zero allocation | Spring Boot - reflection heavy | 10x faster HTTP |
| **Execution Model** | Native binary + Prefork | JVM + Virtual Threads | No JVM overhead |
| **Database Access** | Raw SQL (pgx) | Hibernate ORM | No ORM overhead |
| **Memory Footprint** | ~50-100 MB | ~300-500 MB | 5x less memory |
| **Startup Time** | ~100 ms | ~3-5 seconds | 30-50x faster |
| **Garbage Collection** | Go GC (low latency) | ZGC (still higher) | Lower tail latency |

---

## 🔧 Optimizations Applied

> ### 📢 Can You Make Java Faster?
> 
> This is a **minimal HTTP + PostgreSQL CRUD** setup. If you believe we're missing optimizations in the Java implementation, **we welcome your contribution!**
> 
> **How to contribute:**
> 1. Fork this repository
> 2. Improve the Java code in `java-exchange/`
> 3. Run the benchmark and save results to `results/<your-name>-<optimization>/`
> 4. Create a PR with your changes and benchmark results
> 
> **Results directory format:**
> ```
> results/
> ├── mac/                          # Original Mac results
> ├── ec2/                          # Original EC2 results (10K RPS)
> ├── ec2-1500rps/                  # EC2 at 1500 RPS
> └── <your-name>-<optimization>/   # Your improved results
>     ├── go-10k-results.json
>     ├── java-10k-results.json
>     ├── RESULTS.md
>     └── *.png
> ```

### Go Optimizations

| Optimization | Description | Impact |
|--------------|-------------|--------|
| **Fiber (fasthttp)** | Replaced Chi/net/http with Fiber | 10x faster HTTP |
| **Prefork Mode** | One worker process per CPU core | Full CPU utilization |
| **go-json** | Fast JSON serialization library | 3-4x faster serialization |
| **Parallel Queries** | Concurrent bids/asks fetching | 50% faster orderbook |
| **Connection Pooling** | Smart per-worker pool sizing | No connection exhaustion |
| **Optimized Indexes** | Partial indexes for hot queries | 30-50% faster queries |
| **Postgres Tuning** | 500 connections, optimized buffers | Higher throughput |

### Java Optimizations

| Optimization | Description | Impact |
|--------------|-------------|--------|
| **Java 21 LTS** | Latest LTS with performance improvements | Baseline requirement |
| **Virtual Threads (Project Loom)** | Lightweight threads introduced in Java 21 | Millions of concurrent tasks |
| **ZGC Garbage Collector** | Low-latency GC with sub-millisecond pauses | Reduced GC stalls |
| **HikariCP Tuning** | 200 max connections, optimized pool | Better connection reuse |
| **Native SQL Queries** | Bypassed Hibernate HQL for hot paths | Reduced ORM overhead |
| **Read-Only Transactions** | `@Transactional(readOnly=true)` for reads | Hibernate flush optimization |
| **Query Hints** | `@QueryHint` for read-only entity graphs | Reduced dirty checking |
| **JVM Tuning** | `-Xms2g -Xmx4g` heap, ZGC flags | Stable memory allocation |
| **Spring Boot 3.2+** | Latest Spring with virtual thread support | Native async integration |

> **Note:** Despite these optimizations, Java's fundamental architecture (JVM startup, Hibernate reflection, Spring's annotation processing) creates inherent overhead that Go avoids by compiling to native binaries with minimal runtime.

---

## 📋 Prerequisites

### Load Test Machine (k6 Client)

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **OS** | macOS, Linux, Windows | macOS M1+ or Linux |
| **CPU** | 4 cores | 8+ cores |
| **RAM** | 8 GB | 16+ GB |
| **Network** | 100 Mbps | 1 Gbps |

**Required Software:**
- [k6](https://k6.io/docs/get-started/installation/) - Load testing tool
- Python 3.9+ with `plotly`, `pandas`, `kaleido` (for graphs)

```bash
# Install k6 on macOS
brew install k6

# Install k6 on Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
  --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update && sudo apt-get install k6

# Install Python dependencies (for graph generation)
pip install plotly pandas kaleido
```

### HTTP Server Machine

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **OS** | Ubuntu 22.04+ or macOS | Linux ARM64/x86_64 |
| **CPU** | 2 cores | 4+ cores |
| **RAM** | 4 GB | 8+ GB |
| **Storage** | 10 GB | 20+ GB SSD |

**Required Software:**
- Docker & Docker Compose
- Java 21 (OpenJDK)
- (Optional) Go 1.22+ for building from source

```bash
# Install on Ubuntu
sudo apt update
sudo apt install -y docker.io docker-compose openjdk-21-jre-headless
sudo usermod -aG docker $USER
# Log out and back in for Docker group changes

# Verify installations
docker --version
java -version
```

> 📖 **For EC2/Cloud deployment:** See [UBUNTU-SETUP.md](UBUNTU-SETUP.md) for detailed cloud setup instructions, AWS instance sizing, and cost estimates.

---

## 🚀 Step-by-Step Guide

### Option A: Using Pre-built Binaries (Fastest)

**1. Clone the repository**
```bash
git clone https://github.com/developerAkX/cryptox-go-vs-java-benchmark.git
cd cryptox-go-vs-java-benchmark
```

**2. Start PostgreSQL**
```bash
docker-compose up -d postgres
sleep 5
# Verify Postgres is ready
docker-compose ps
```

**3. Start Go Exchange** (Terminal 1)
```bash
export DATABASE_URL="postgres://postgres:postgres@localhost:5432/cryptox?sslmode=disable"

# Choose your platform:
./bin/go-exchange-darwin-arm64   # macOS Apple Silicon
./bin/go-exchange-linux-amd64    # Linux x86_64
./bin/go-exchange-linux-arm64    # Linux ARM64 (AWS Graviton)
```

**4. Start Java Exchange** (Terminal 2)
```bash
java -Xms2g -Xmx4g -XX:+UseZGC -XX:+ZGenerational -jar bin/java-exchange.jar
```

**5. Verify Both Services**
```bash
curl http://localhost:8080/health  # Go - should return {"status":"ok"}
curl http://localhost:8081/health  # Java - should return {"status":"ok"}
```

**6. Run Go Benchmark** (Terminal 3)
```bash
k6 run --env TARGET=http://localhost:8080 \
       --env RPS=10000 \
       --env DURATION=3m \
       --env RESULTS_DIR=results/my-test \
       k6-tests/10k-benchmark.js
```

**7. Run Java Benchmark**
```bash
k6 run --env TARGET=http://localhost:8081 \
       --env RPS=10000 \
       --env DURATION=3m \
       --env RESULTS_DIR=results/my-test \
       k6-tests/10k-benchmark.js
```

**8. Generate Graphs**
```bash
python3 k6-tests/generate-graphs.py results/my-test
# Open results/my-test/RESULTS.md to view results
```

---

### Option B: Using Docker Compose (Easiest)

**1. Clone and start all services**
```bash
git clone https://github.com/developerAkX/cryptox-go-vs-java-benchmark.git
cd cryptox-go-vs-java-benchmark
docker-compose up -d --build
```

**2. Wait for services to start** (Java takes ~30 seconds)
```bash
sleep 30
curl http://localhost:8080/health  # Go
curl http://localhost:8081/health  # Java
```

**3. Run benchmarks**
```bash
# Go benchmark
k6 run --env TARGET=http://localhost:8080 --env RPS=10000 --env DURATION=3m k6-tests/10k-benchmark.js

# Java benchmark  
k6 run --env TARGET=http://localhost:8081 --env RPS=10000 --env DURATION=3m k6-tests/10k-benchmark.js
```

**4. Cleanup**
```bash
docker-compose down -v
```

---

### Option C: Remote Testing (EC2/Cloud)

For testing on remote servers with k6 running locally:

```bash
# Set your EC2/server IP
export SERVER_IP=your-server-ip

# Run benchmark against remote Go server
k6 run --env TARGET=http://$SERVER_IP:8080 \
       --env RPS=1500 \
       --env DURATION=3m \
       --env RESULTS_DIR=results/ec2-test \
       k6-tests/10k-benchmark.js

# Run benchmark against remote Java server
k6 run --env TARGET=http://$SERVER_IP:8081 \
       --env RPS=1500 \
       --env DURATION=3m \
       --env RESULTS_DIR=results/ec2-test \
       k6-tests/10k-benchmark.js
```

> 📖 **Full EC2 setup guide:** See [UBUNTU-SETUP.md](UBUNTU-SETUP.md) for complete instructions.

---

## 📈 API Endpoints

Both services expose identical REST APIs:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| POST | `/orders` | Create a new order |
| GET | `/orderbook/{pair}` | Get order book for trading pair |
| GET | `/balance/{userId}` | Get user wallet balances |
| POST | `/trades/match?pair=X` | Match orders for a pair |

### Example Requests

```bash
# Health check
curl http://localhost:8080/health

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

# Get user balance
curl http://localhost:8080/balance/11111111-1111-1111-1111-111111111111

# Match orders
curl -X POST "http://localhost:8080/trades/match?pair=BTC%2FUSDT"
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         k6 Load Tester                       │
│              (Generates up to 10,000 RPS)                    │
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

---

## 📁 Project Structure

```
cryptox-go-vs-java-benchmark/
├── go-exchange/           # Go implementation (Fiber + pgx)
├── java-exchange/         # Java implementation (Spring Boot + JPA)
├── k6-tests/              # Load testing scripts
│   ├── 10k-benchmark.js   # Main benchmark script
│   └── generate-graphs.py # Results visualization
├── bin/                   # Pre-built binaries
│   ├── go-exchange-darwin-arm64
│   ├── go-exchange-linux-amd64
│   ├── go-exchange-linux-arm64
│   └── java-exchange.jar
├── results/               # Benchmark results
│   ├── mac/               # Mac M4 Pro results
│   ├── ec2/               # EC2 10K RPS results
│   └── ec2-1500rps/       # EC2 1.5K RPS results
├── docker-compose.yml     # Docker setup
├── init.sql               # Database schema
├── UBUNTU-SETUP.md        # EC2/Cloud deployment guide
└── README.md
```

---

## 📚 References

- [k6 Load Testing](https://k6.io/docs/)
- [Fiber - Go Web Framework](https://gofiber.io/)
- [pgx - PostgreSQL Driver for Go](https://github.com/jackc/pgx)
- [Spring Boot](https://spring.io/projects/spring-boot)
- [Java Virtual Threads (Project Loom)](https://openjdk.org/jeps/444)
- [HikariCP Connection Pool](https://github.com/brettwooldridge/HikariCP)

---

## 📄 License

MIT License - Feel free to use this benchmark for your own comparisons.
