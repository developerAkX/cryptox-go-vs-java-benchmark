# CryptoX Binaries

Pre-built binaries for Go and Java crypto exchanges.

## Files

| File | Platform | Size | Description |
|------|----------|------|-------------|
| `go-exchange-darwin-arm64` | macOS M1/M2/M3/M4 | ~10MB | Go binary for Apple Silicon |
| `go-exchange-linux-amd64` | Linux x64 | ~10MB | Go binary for EC2/Ubuntu |
| `java-exchange.jar` | Any (JVM) | ~30MB | Java JAR (requires Java 21) |

## Quick Usage

### Mac (Apple Silicon)

```bash
# Go
./go-exchange-darwin-arm64

# Java
java -Xms2g -Xmx4g -XX:+UseZGC -jar java-exchange.jar
```

### Linux (EC2/Ubuntu)

```bash
# Go
chmod +x go-exchange-linux-amd64
./go-exchange-linux-amd64

# Java
java -Xms2g -Xmx4g -XX:+UseZGC -jar java-exchange.jar
```

## Environment Variables

### Go Exchange

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `postgres://postgres:postgres@localhost:5432/cryptox?sslmode=disable` | PostgreSQL connection string |
| `PORT` | `8080` | HTTP server port |

### Java Exchange

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `jdbc:postgresql://localhost:5432/cryptox` | JDBC connection string |
| `DB_USER` | `postgres` | Database username |
| `DB_PASSWORD` | `postgres` | Database password |
| `SERVER_PORT` | `8081` | HTTP server port |

## Building from Source

```bash
# From project root
make build-all

# Or individually:
make build-go-mac      # Mac binary
make build-go-linux    # Linux binary
make build-java        # Java JAR
```

## API Endpoints

Both services expose the same API:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| POST | `/orders` | Create order |
| GET | `/orderbook/{pair}` | Get order book |
| GET | `/balance/{userId}` | Get user balance |
| POST | `/trades/match?pair=X` | Match orders |

## Health Check

```bash
# Go (port 8080)
curl http://localhost:8080/health

# Java (port 8081)
curl http://localhost:8081/health
```
