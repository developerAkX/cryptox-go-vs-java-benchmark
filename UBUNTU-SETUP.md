# Ubuntu EC2 Setup Guide

This guide explains how to set up and run the Go and Java crypto exchange benchmarks on an Ubuntu EC2 instance.

## Prerequisites

- Ubuntu 22.04 LTS (or Amazon Linux 2023)
- EC2 instance type: `c5.xlarge` (4 vCPU, 8GB RAM) recommended
- Security Group: Open ports **8080**, **8081**, **5432**

## Quick Setup

### 1. Connect to EC2

```bash
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

### 2. Install Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Install Java 21
sudo apt install -y openjdk-21-jre-headless

# Verify installations
docker --version
java -version
```

**Log out and back in** for Docker group changes to take effect.

### 3. Copy Files from Mac

On your Mac, run:

```bash
export EC2_HOST=ubuntu@<EC2_PUBLIC_IP>
export EC2_KEY=~/.ssh/your-key.pem

# Deploy binaries
make deploy-ec2

# Or manually:
scp -i $EC2_KEY bin/go-exchange-linux-amd64 $EC2_HOST:~/go-exchange
scp -i $EC2_KEY bin/java-exchange.jar $EC2_HOST:~/java-exchange.jar
scp -i $EC2_KEY docker-compose.yml $EC2_HOST:~/
scp -i $EC2_KEY init.sql $EC2_HOST:~/
```

### 4. Start PostgreSQL

On EC2:

```bash
cd ~
docker compose up -d postgres

# Verify
docker compose ps
docker compose logs postgres
```

### 5. Run Go Exchange

```bash
chmod +x ~/go-exchange

# Set environment and run
export DATABASE_URL="postgres://postgres:postgres@localhost:5432/cryptox?sslmode=disable"
./go-exchange &

# Verify
curl http://localhost:8080/health
```

### 6. Run Java Exchange

```bash
java -Xms2g -Xmx4g \
     -XX:+UseZGC \
     -XX:+ZGenerational \
     -jar ~/java-exchange.jar &

# Wait for startup (10-15 seconds)
sleep 15

# Verify
curl http://localhost:8081/health
```

## Running Benchmarks from Mac

Once EC2 is set up, run benchmarks from your Mac:

```bash
# Set EC2 connection details
export EC2_HOST=ubuntu@<EC2_PUBLIC_IP>
export EC2_KEY=~/.ssh/your-key.pem

# Run full EC2 benchmark
make benchmark-ec2

# Or run individually:
make benchmark-go-ec2
make benchmark-java-ec2
```

## Manual Commands

### Stop Services

```bash
# Stop Go
pkill -f go-exchange

# Stop Java
pkill -f java-exchange

# Stop Postgres
docker compose stop postgres
```

### View Logs

```bash
# Go logs
tail -f go.log

# Java logs
tail -f java.log

# Postgres logs
docker compose logs -f postgres
```

### Reset Database

```bash
docker compose down -v
docker compose up -d postgres
sleep 3
```

## Monitoring

### Check Resource Usage

```bash
# CPU and Memory
htop

# Disk I/O
iostat -x 1

# Network
iftop

# Docker stats
docker stats
```

### Check Connection Counts

```bash
# Active connections
ss -tuln | grep -E '8080|8081|5432'

# Postgres connections
docker exec cryptox-postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

## Troubleshooting

### Port Already in Use

```bash
# Find process using port
sudo lsof -i :8080
sudo lsof -i :8081

# Kill process
sudo kill -9 <PID>
```

### Java Out of Memory

Increase heap size:

```bash
java -Xms4g -Xmx6g -XX:+UseZGC -jar java-exchange.jar &
```

### Database Connection Issues

```bash
# Check Postgres is running
docker compose ps

# Check logs
docker compose logs postgres

# Restart Postgres
docker compose restart postgres
```

### Firewall Issues

```bash
# Check firewall
sudo ufw status

# Allow ports
sudo ufw allow 8080
sudo ufw allow 8081
sudo ufw allow 5432
```

## EC2 Instance Sizing Guide

| Instance Type | vCPU | RAM | Expected Go RPS | Expected Java RPS |
|---------------|------|-----|-----------------|-------------------|
| c5.large | 2 | 4GB | ~3,000 | ~2,500 |
| c5.xlarge | 4 | 8GB | ~6,000 | ~5,000 |
| c5.2xlarge | 8 | 16GB | ~10,000+ | ~8,000+ |
| c5.4xlarge | 16 | 32GB | ~15,000+ | ~12,000+ |

## Security Notes

- Never expose port 5432 (Postgres) to the internet
- Use security groups to restrict access
- Consider using RDS for production workloads
- Use IAM roles instead of access keys

## Cost Optimization

- Use spot instances for benchmarking (up to 90% savings)
- Stop instances when not in use
- Use `c5.xlarge` for testing, scale up only for final benchmarks
