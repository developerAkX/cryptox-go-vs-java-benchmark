import http from 'k6/http';
import { check } from 'k6';
import { Rate, Counter, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const droppedRequests = new Counter('dropped_requests');
const createOrderLatency = new Trend('create_order_latency', true);
const getOrderBookLatency = new Trend('get_orderbook_latency', true);
const getBalanceLatency = new Trend('get_balance_latency', true);
const matchOrdersLatency = new Trend('match_orders_latency', true);

// Configuration
const TARGET = __ENV.TARGET || 'http://localhost:8080';
const RPS = parseInt(__ENV.RPS) || 10000;
const DURATION = __ENV.DURATION || '10m';
const RESULTS_DIR = __ENV.RESULTS_DIR || 'results/mac';

const TEST_USER_IDS = [
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333'
];

// Force 10,000 RPS using constant-arrival-rate
export const options = {
    scenarios: {
        constant_rps: {
            executor: 'constant-arrival-rate',
            rate: RPS,
            timeUnit: '1s',
            duration: DURATION,
            preAllocatedVUs: 500,
            maxVUs: 3000,
        },
    },
    thresholds: {
        http_req_duration: ['p(90)<500', 'p(95)<1000', 'p(99)<2000'],
        errors: ['rate<0.05'],
    },
    noConnectionReuse: false,
    userAgent: 'k6-benchmark/1.0',
};

// Random helpers
function randomUser() {
    return TEST_USER_IDS[Math.floor(Math.random() * TEST_USER_IDS.length)];
}

function randomPrice() {
    return (41000 + Math.random() * 2000).toFixed(2);
}

function randomQuantity() {
    return (0.01 + Math.random() * 0.5).toFixed(4);
}

function randomSide() {
    return Math.random() > 0.5 ? 'BUY' : 'SELL';
}

// Main test function
export default function () {
    const headers = { 'Content-Type': 'application/json' };
    const operation = Math.random();

    try {
        if (operation < 0.3) {
            // 30% - Create Order
            const payload = JSON.stringify({
                user_id: randomUser(),
                pair: 'BTCUSDT',
                side: randomSide(),
                price: parseFloat(randomPrice()),
                quantity: parseFloat(randomQuantity())
            });

            const res = http.post(`${TARGET}/orders`, payload, { headers, timeout: '10s' });
            createOrderLatency.add(res.timings.duration);

            const success = check(res, {
                'create order status is 201': (r) => r.status === 201,
            });
            errorRate.add(!success);
            if (!success && res.status === 0) droppedRequests.add(1);

        } else if (operation < 0.6) {
            // 30% - Get Order Book
            const res = http.get(`${TARGET}/orderbook/BTCUSDT`, { timeout: '10s' });
            getOrderBookLatency.add(res.timings.duration);

            const success = check(res, {
                'get orderbook status is 200': (r) => r.status === 200,
            });
            errorRate.add(!success);
            if (!success && res.status === 0) droppedRequests.add(1);

        } else if (operation < 0.85) {
            // 25% - Get Balance
            const userId = randomUser();
            const res = http.get(`${TARGET}/balance/${userId}`, { timeout: '10s' });
            getBalanceLatency.add(res.timings.duration);

            const success = check(res, {
                'get balance status is 200': (r) => r.status === 200,
            });
            errorRate.add(!success);
            if (!success && res.status === 0) droppedRequests.add(1);

        } else {
            // 15% - Match Orders
            const res = http.post(`${TARGET}/trades/match?pair=BTCUSDT`, null, { headers, timeout: '10s' });
            matchOrdersLatency.add(res.timings.duration);

            const success = check(res, {
                'match orders status is 200': (r) => r.status === 200,
            });
            errorRate.add(!success);
            if (!success && res.status === 0) droppedRequests.add(1);
        }
    } catch (e) {
        droppedRequests.add(1);
        errorRate.add(true);
    }
}

// Summary handler
export function handleSummary(data) {
    const service = TARGET.includes('8080') ? 'go' : 'java';
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    
    const summary = generateTextSummary(data, service);
    
    return {
        'stdout': summary,
        [`${RESULTS_DIR}/${service}-10k-results.json`]: JSON.stringify(data, null, 2),
    };
}

function generateTextSummary(data, service) {
    const m = data.metrics;
    const serviceName = service === 'go' ? 'Go Exchange' : 'Java Exchange (Virtual Threads)';
    
    const p90 = m.http_req_duration?.values?.['p(90)'] || 0;
    const p95 = m.http_req_duration?.values?.['p(95)'] || 0;
    const p99 = m.http_req_duration?.values?.['p(99)'] || 0;
    const avg = m.http_req_duration?.values?.avg || 0;
    const max = m.http_req_duration?.values?.max || 0;
    const totalReqs = m.http_reqs?.values?.count || 0;
    const rps = m.http_reqs?.values?.rate || 0;
    const dropped = m.dropped_requests?.values?.count || 0;
    const errorPct = (m.errors?.values?.rate || 0) * 100;

    return `
╔══════════════════════════════════════════════════════════════════════════════╗
║                        10K RPS BENCHMARK RESULTS                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Service: ${serviceName.padEnd(66)}║
║  Target:  ${TARGET.padEnd(66)}║
╠══════════════════════════════════════════════════════════════════════════════╣
║                              LATENCY (ms)                                    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║    Average:    ${avg.toFixed(2).padStart(10)} ms                                             ║
║    P90:        ${p90.toFixed(2).padStart(10)} ms                                             ║
║    P95:        ${p95.toFixed(2).padStart(10)} ms                                             ║
║    P99:        ${p99.toFixed(2).padStart(10)} ms                                             ║
║    Max:        ${max.toFixed(2).padStart(10)} ms                                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                             THROUGHPUT                                       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║    Total Requests:     ${totalReqs.toString().padStart(12)}                                      ║
║    Actual RPS:         ${rps.toFixed(2).padStart(12)} /s                                    ║
║    Target RPS:         ${RPS.toString().padStart(12)} /s                                    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                              ERRORS                                          ║
╠══════════════════════════════════════════════════════════════════════════════╣
║    Error Rate:         ${errorPct.toFixed(4).padStart(12)} %                                     ║
║    Dropped Requests:   ${dropped.toString().padStart(12)}                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝
`;
}
