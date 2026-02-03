# CryptoX Benchmark Makefile
# Go vs Java Exchange Performance Comparison

SHELL := /bin/bash
.PHONY: all clean help

# Java 21 configuration
export JAVA_HOME := /opt/homebrew/opt/openjdk@21
export PATH := $(JAVA_HOME)/bin:$(PATH)

# Build configuration
GO_BINARY_MAC := bin/go-exchange-darwin-arm64
GO_BINARY_LINUX := bin/go-exchange-linux-amd64
JAVA_JAR := bin/java-exchange.jar

# Benchmark configuration
RPS := 10000
DURATION := 10m
WARMUP_DURATION := 5m
GO_WARMUP_DURATION := 1m

# EC2 configuration (set these before using EC2 targets)
EC2_HOST ?= ubuntu@your-ec2-ip
EC2_KEY ?= ~/.ssh/your-key.pem

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m

# ==================== HELP ====================

help:
	@echo ""
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║              CryptoX Benchmark Makefile                              ║$(NC)"
	@echo "$(BLUE)╠══════════════════════════════════════════════════════════════════════╣$(NC)"
	@echo "$(BLUE)║  BUILD COMMANDS                                                      ║$(NC)"
	@echo "$(BLUE)╠══════════════════════════════════════════════════════════════════════╣$(NC)"
	@echo "  make build-go-mac      Build Go binary for Mac M4"
	@echo "  make build-go-linux    Cross-compile Go for Ubuntu/EC2"
	@echo "  make build-java        Build Java JAR"
	@echo "  make build-all         Build everything"
	@echo ""
	@echo "$(BLUE)╠══════════════════════════════════════════════════════════════════════╣$(NC)"
	@echo "$(BLUE)║  LOCAL MAC COMMANDS                                                  ║$(NC)"
	@echo "$(BLUE)╠══════════════════════════════════════════════════════════════════════╣$(NC)"
	@echo "  make run-go-mac        Run Go natively on Mac (:8080)"
	@echo "  make run-java-mac      Run Java natively on Mac (:8081)"
	@echo "  make stop-apps         Stop all native apps"
	@echo "  make benchmark-mac     Full Mac benchmark (Go + Java)"
	@echo "  make benchmark-go-mac  Benchmark Go only"
	@echo "  make benchmark-java-mac Benchmark Java only"
	@echo ""
	@echo "$(BLUE)╠══════════════════════════════════════════════════════════════════════╣$(NC)"
	@echo "$(BLUE)║  EC2 COMMANDS                                                        ║$(NC)"
	@echo "$(BLUE)╠══════════════════════════════════════════════════════════════════════╣$(NC)"
	@echo "  make deploy-ec2        Copy binaries to EC2"
	@echo "  make benchmark-ec2     Full EC2 benchmark"
	@echo ""
	@echo "$(BLUE)╠══════════════════════════════════════════════════════════════════════╣$(NC)"
	@echo "$(BLUE)║  UTILITY COMMANDS                                                    ║$(NC)"
	@echo "$(BLUE)╠══════════════════════════════════════════════════════════════════════╣$(NC)"
	@echo "  make graphs-mac        Generate Mac benchmark graphs"
	@echo "  make graphs-ec2        Generate EC2 benchmark graphs"
	@echo "  make postgres-start    Start Postgres (Docker)"
	@echo "  make postgres-stop     Stop Postgres"
	@echo "  make clean             Remove binaries and results"
	@echo ""
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""

# ==================== BUILD ====================

build-go-mac:
	@echo "$(GREEN)Building Go binary for Mac M4...$(NC)"
	cd go-exchange && go mod download && \
	GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o ../$(GO_BINARY_MAC) ./cmd/server
	@echo "$(GREEN)✓ Built: $(GO_BINARY_MAC)$(NC)"

build-go-linux:
	@echo "$(GREEN)Building Go binary for Linux (EC2)...$(NC)"
	cd go-exchange && go mod download && \
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o ../$(GO_BINARY_LINUX) ./cmd/server
	@echo "$(GREEN)✓ Built: $(GO_BINARY_LINUX)$(NC)"

build-java:
	@echo "$(GREEN)Building Java JAR...$(NC)"
	@echo "Using Java: $$($(JAVA_HOME)/bin/java -version 2>&1 | head -1)"
	cd java-exchange && $(JAVA_HOME)/bin/java -version && \
	mvn clean package -DskipTests -q
	cp java-exchange/target/java-exchange-1.0.0.jar $(JAVA_JAR)
	@echo "$(GREEN)✓ Built: $(JAVA_JAR)$(NC)"

build-all: build-go-mac build-go-linux build-java
	@echo "$(GREEN)✓ All binaries built successfully!$(NC)"
	@ls -lh bin/

# ==================== POSTGRES ====================

postgres-start:
	@echo "$(GREEN)Starting Postgres...$(NC)"
	docker compose up -d postgres
	@sleep 3
	@docker compose ps postgres
	@echo "$(GREEN)✓ Postgres running on localhost:5432$(NC)"

postgres-stop:
	@echo "$(YELLOW)Stopping Postgres...$(NC)"
	docker compose stop postgres

postgres-reset:
	@echo "$(YELLOW)Resetting Postgres data...$(NC)"
	docker compose down -v
	docker compose up -d postgres
	@sleep 3
	@echo "$(GREEN)✓ Postgres reset complete$(NC)"

# ==================== LOCAL MAC ====================

run-go-mac: postgres-start
	@echo "$(GREEN)Starting Go Exchange on :8080...$(NC)"
	@if [ ! -f $(GO_BINARY_MAC) ]; then make build-go-mac; fi
	DATABASE_URL="postgres://postgres:postgres@localhost:5432/cryptox?sslmode=disable" \
	./$(GO_BINARY_MAC) &
	@sleep 2
	@curl -s http://localhost:8080/health > /dev/null && echo "$(GREEN)✓ Go Exchange running on http://localhost:8080$(NC)"

run-java-mac: postgres-start
	@echo "$(GREEN)Starting Java Exchange on :8081...$(NC)"
	@if [ ! -f $(JAVA_JAR) ]; then make build-java; fi
	$(JAVA_HOME)/bin/java \
		-Xms2g -Xmx4g \
		-XX:+UseZGC \
		-XX:+ZGenerational \
		-Dspring.profiles.active=default \
		-jar $(JAVA_JAR) &
	@sleep 10
	@curl -s http://localhost:8081/health > /dev/null && echo "$(GREEN)✓ Java Exchange running on http://localhost:8081$(NC)"

stop-go:
	@echo "$(YELLOW)Stopping Go Exchange...$(NC)"
	@pkill -f "go-exchange-darwin" 2>/dev/null || true
	@echo "$(GREEN)✓ Go stopped$(NC)"

stop-java:
	@echo "$(YELLOW)Stopping Java Exchange...$(NC)"
	@pkill -f "java-exchange.jar" 2>/dev/null || true
	@echo "$(GREEN)✓ Java stopped$(NC)"

stop-apps: stop-go stop-java

stop-docker-apps:
	@echo "$(YELLOW)Stopping Docker Go/Java services...$(NC)"
	docker compose stop go-exchange java-exchange 2>/dev/null || true

# ==================== WARMUP ====================

warmup-go:
	@echo "$(GREEN)Warming up Go ($(GO_WARMUP_DURATION))...$(NC)"
	k6 run --env TARGET=http://localhost:8080 --env DURATION=$(GO_WARMUP_DURATION) k6-tests/warmup.js

warmup-java:
	@echo "$(GREEN)Warming up Java ($(WARMUP_DURATION)) - Critical for JIT...$(NC)"
	k6 run --env TARGET=http://localhost:8081 --env DURATION=$(WARMUP_DURATION) k6-tests/warmup.js

# ==================== BENCHMARKS ====================

benchmark-go-mac: stop-docker-apps
	@echo ""
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║              GO EXCHANGE BENCHMARK ($(RPS) RPS, $(DURATION))                  ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@make run-go-mac
	@echo ""
	@echo "$(YELLOW)>>> Warmup phase ($(GO_WARMUP_DURATION))...$(NC)"
	@make warmup-go
	@echo ""
	@echo "$(GREEN)>>> Starting $(RPS) RPS benchmark for $(DURATION)...$(NC)"
	k6 run \
		--env TARGET=http://localhost:8080 \
		--env RPS=$(RPS) \
		--env DURATION=$(DURATION) \
		--env RESULTS_DIR=results/mac \
		k6-tests/10k-benchmark.js
	@make stop-go
	@echo "$(GREEN)✓ Go benchmark complete. Results in results/mac/$(NC)"

benchmark-java-mac: stop-docker-apps
	@echo ""
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║          JAVA EXCHANGE BENCHMARK ($(RPS) RPS, $(DURATION))                    ║$(NC)"
	@echo "$(BLUE)║          Virtual Threads + Optimized JPA                             ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@make run-java-mac
	@echo ""
	@echo "$(YELLOW)>>> Warmup phase ($(WARMUP_DURATION)) - Critical for JIT compiler...$(NC)"
	@make warmup-java
	@echo ""
	@echo "$(GREEN)>>> Starting $(RPS) RPS benchmark for $(DURATION)...$(NC)"
	k6 run \
		--env TARGET=http://localhost:8081 \
		--env RPS=$(RPS) \
		--env DURATION=$(DURATION) \
		--env RESULTS_DIR=results/mac \
		k6-tests/10k-benchmark.js
	@make stop-java
	@echo "$(GREEN)✓ Java benchmark complete. Results in results/mac/$(NC)"

benchmark-mac: stop-docker-apps postgres-reset
	@echo ""
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║          FULL MAC BENCHMARK: GO vs JAVA                              ║$(NC)"
	@echo "$(BLUE)║          $(RPS) RPS for $(DURATION) each                                      ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Phase 1/4: Building binaries...$(NC)"
	@make build-go-mac build-java
	@echo ""
	@echo "$(GREEN)Phase 2/4: Benchmarking Go...$(NC)"
	@make benchmark-go-mac
	@echo ""
	@echo "$(GREEN)Phase 3/4: Resetting database...$(NC)"
	@make postgres-reset
	@echo ""
	@echo "$(GREEN)Phase 4/4: Benchmarking Java...$(NC)"
	@make benchmark-java-mac
	@echo ""
	@echo "$(GREEN)Generating comparison graphs...$(NC)"
	@make graphs-mac
	@echo ""
	@echo "$(GREEN)╔══════════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║                    BENCHMARK COMPLETE!                               ║$(NC)"
	@echo "$(GREEN)╚══════════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "Results saved to: results/mac/"
	@echo "Open results/mac/summary.html in a browser to view the dashboard."
	@echo ""

# ==================== EC2 ====================

deploy-ec2:
	@echo "$(GREEN)Deploying to EC2: $(EC2_HOST)$(NC)"
	@if [ ! -f $(GO_BINARY_LINUX) ]; then make build-go-linux; fi
	@if [ ! -f $(JAVA_JAR) ]; then make build-java; fi
	scp -i $(EC2_KEY) $(GO_BINARY_LINUX) $(EC2_HOST):~/go-exchange
	scp -i $(EC2_KEY) $(JAVA_JAR) $(EC2_HOST):~/java-exchange.jar
	scp -i $(EC2_KEY) docker-compose.yml $(EC2_HOST):~/
	scp -i $(EC2_KEY) init.sql $(EC2_HOST):~/
	@echo "$(GREEN)✓ Deployed to EC2$(NC)"

ec2-start-postgres:
	ssh -i $(EC2_KEY) $(EC2_HOST) "docker compose up -d postgres && sleep 3"

ec2-start-go:
	ssh -i $(EC2_KEY) $(EC2_HOST) "chmod +x ~/go-exchange && DATABASE_URL='postgres://postgres:postgres@localhost:5432/cryptox?sslmode=disable' nohup ~/go-exchange > go.log 2>&1 &"
	@sleep 2
	@echo "$(GREEN)✓ Go started on EC2$(NC)"

ec2-start-java:
	ssh -i $(EC2_KEY) $(EC2_HOST) "nohup java -Xms2g -Xmx4g -XX:+UseZGC -jar ~/java-exchange.jar > java.log 2>&1 &"
	@sleep 10
	@echo "$(GREEN)✓ Java started on EC2$(NC)"

ec2-stop-go:
	ssh -i $(EC2_KEY) $(EC2_HOST) "pkill -f go-exchange || true"

ec2-stop-java:
	ssh -i $(EC2_KEY) $(EC2_HOST) "pkill -f java-exchange || true"

ec2-reset-db:
	ssh -i $(EC2_KEY) $(EC2_HOST) "docker compose down -v && docker compose up -d postgres && sleep 3"

benchmark-go-ec2:
	@echo "$(GREEN)Benchmarking Go on EC2...$(NC)"
	@make ec2-start-postgres
	@make ec2-start-go
	@EC2_IP=$$(echo $(EC2_HOST) | cut -d@ -f2) && \
	k6 run \
		--env TARGET=http://$$EC2_IP:8080 \
		--env RPS=$(RPS) \
		--env DURATION=$(DURATION) \
		--env RESULTS_DIR=results/ec2 \
		k6-tests/10k-benchmark.js
	@make ec2-stop-go
	@echo "$(GREEN)✓ Go EC2 benchmark complete$(NC)"

benchmark-java-ec2:
	@echo "$(GREEN)Benchmarking Java on EC2...$(NC)"
	@make ec2-start-java
	@echo "$(YELLOW)Warming up Java ($(WARMUP_DURATION))...$(NC)"
	@EC2_IP=$$(echo $(EC2_HOST) | cut -d@ -f2) && \
	k6 run --env TARGET=http://$$EC2_IP:8081 --env DURATION=$(WARMUP_DURATION) k6-tests/warmup.js && \
	k6 run \
		--env TARGET=http://$$EC2_IP:8081 \
		--env RPS=$(RPS) \
		--env DURATION=$(DURATION) \
		--env RESULTS_DIR=results/ec2 \
		k6-tests/10k-benchmark.js
	@make ec2-stop-java
	@echo "$(GREEN)✓ Java EC2 benchmark complete$(NC)"

benchmark-ec2: deploy-ec2
	@echo "$(GREEN)Full EC2 Benchmark...$(NC)"
	@make ec2-reset-db
	@make benchmark-go-ec2
	@make ec2-reset-db
	@make benchmark-java-ec2
	@make graphs-ec2
	@echo "$(GREEN)✓ EC2 benchmark complete. Results in results/ec2/$(NC)"

# ==================== GRAPHS ====================

graphs-mac:
	@echo "$(GREEN)Generating Mac benchmark graphs...$(NC)"
	pip install -q plotly pandas 2>/dev/null || pip3 install -q plotly pandas
	python3 k6-tests/generate-graphs.py results/mac
	@echo "$(GREEN)✓ Graphs saved to results/mac/$(NC)"

graphs-ec2:
	@echo "$(GREEN)Generating EC2 benchmark graphs...$(NC)"
	pip install -q plotly pandas 2>/dev/null || pip3 install -q plotly pandas
	python3 k6-tests/generate-graphs.py results/ec2
	@echo "$(GREEN)✓ Graphs saved to results/ec2/$(NC)"

# ==================== CLEAN ====================

clean:
	@echo "$(YELLOW)Cleaning up...$(NC)"
	rm -rf bin/*
	rm -rf results/mac/*.json results/mac/*.html
	rm -rf results/ec2/*.json results/ec2/*.html
	rm -rf java-exchange/target
	@echo "$(GREEN)✓ Cleaned$(NC)"

# ==================== ALL ====================

all: build-all benchmark-mac
