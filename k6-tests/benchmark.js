import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const createOrderTrend = new Trend('create_order_duration');
const getOrderBookTrend = new Trend('get_orderbook_duration');
const getBalanceTrend = new Trend('get_balance_duration');
const matchOrdersTrend = new Trend('match_orders_duration');

// Test configuration
const TARGET = __ENV.TARGET || 'http://localhost:8080';
const TEST_USER_IDS = [
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333'
];

// Ramping stages to reach 10,000 RPS
// Note: Actual RPS depends on your hardware and response times
export const options = {
    scenarios: {
        // Scenario 1: Ramping VUs for mixed workload
        mixed_load: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30s', target: 50 },    // Warm-up
                { duration: '60s', target: 200 },   // Ramp to medium load
                { duration: '120s', target: 500 },  // Ramp to high load (target ~10k RPS)
                { duration: '60s', target: 500 },   // Sustain peak
                { duration: '30s', target: 0 },     // Cool down
            ],
            gracefulRampDown: '30s',
        },
    },
    thresholds: {
        http_req_duration: ['p(95)<500', 'p(99)<1000'], // 95% under 500ms, 99% under 1s
        errors: ['rate<0.01'],                          // Error rate under 1%
    },
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

    // Weighted distribution of operations (simulates real traffic)
    const operation = Math.random();

    if (operation < 0.3) {
        // 30% - Create Order (write-heavy)
        const payload = JSON.stringify({
            user_id: randomUser(),
            pair: 'BTCUSDT',
            side: randomSide(),
            price: parseFloat(randomPrice()),
            quantity: parseFloat(randomQuantity())
        });

        const start = Date.now();
        const res = http.post(`${TARGET}/orders`, payload, { headers });
        createOrderTrend.add(Date.now() - start);

        const success = check(res, {
            'create order status is 201': (r) => r.status === 201,
        });
        errorRate.add(!success);

    } else if (operation < 0.6) {
        // 30% - Get Order Book (read-heavy)
        const start = Date.now();
        const res = http.get(`${TARGET}/orderbook/BTCUSDT`);
        getOrderBookTrend.add(Date.now() - start);

        const success = check(res, {
            'get orderbook status is 200': (r) => r.status === 200,
            'orderbook has bids': (r) => JSON.parse(r.body).bids !== undefined,
        });
        errorRate.add(!success);

    } else if (operation < 0.85) {
        // 25% - Get Balance (read)
        const userId = randomUser();
        const start = Date.now();
        const res = http.get(`${TARGET}/balance/${userId}`);
        getBalanceTrend.add(Date.now() - start);

        const success = check(res, {
            'get balance status is 200': (r) => r.status === 200,
        });
        errorRate.add(!success);

    } else {
        // 15% - Match Orders (complex transaction)
        const start = Date.now();
        const res = http.post(`${TARGET}/trades/match?pair=BTCUSDT`, null, { headers });
        matchOrdersTrend.add(Date.now() - start);

        const success = check(res, {
            'match orders status is 200': (r) => r.status === 200,
        });
        errorRate.add(!success);
    }

    // Minimal sleep to maximize throughput
    sleep(0.01);
}

// Summary handler for pretty output
export function handleSummary(data) {
    const service = TARGET.includes('8080') ? 'Go' : 'Java';
    
    return {
        'stdout': textSummary(data, { indent: ' ', enableColors: true }),
        [`results-${service.toLowerCase()}.json`]: JSON.stringify(data, null, 2),
    };
}

function textSummary(data, options) {
    const metrics = data.metrics;
    
    let summary = `
╔══════════════════════════════════════════════════════════════════╗
║                    BENCHMARK RESULTS                             ║
╠══════════════════════════════════════════════════════════════════╣
║  Target: ${TARGET.padEnd(54)}║
╠══════════════════════════════════════════════════════════════════╣
║  HTTP Request Duration:                                          ║
║    - Average: ${(metrics.http_req_duration.values.avg || 0).toFixed(2).padEnd(10)}ms                                    ║
║    - p50:     ${(metrics.http_req_duration.values['p(50)'] || 0).toFixed(2).padEnd(10)}ms                                    ║
║    - p95:     ${(metrics.http_req_duration.values['p(95)'] || 0).toFixed(2).padEnd(10)}ms                                    ║
║    - p99:     ${(metrics.http_req_duration.values['p(99)'] || 0).toFixed(2).padEnd(10)}ms                                    ║
║    - max:     ${(metrics.http_req_duration.values.max || 0).toFixed(2).padEnd(10)}ms                                    ║
╠══════════════════════════════════════════════════════════════════╣
║  Throughput:                                                     ║
║    - Requests: ${(metrics.http_reqs.values.count || 0).toString().padEnd(10)}                                    ║
║    - RPS:      ${(metrics.http_reqs.values.rate || 0).toFixed(2).padEnd(10)}/s                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  Error Rate: ${((metrics.errors?.values?.rate || 0) * 100).toFixed(2).padEnd(10)}%                                      ║
╚══════════════════════════════════════════════════════════════════╝
`;
    return summary;
}
