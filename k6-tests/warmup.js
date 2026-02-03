import http from 'k6/http';
import { check, sleep } from 'k6';

// Warmup configuration - light load to warm up JIT compiler
const TARGET = __ENV.TARGET || 'http://localhost:8080';
const DURATION = __ENV.DURATION || '5m';

const TEST_USER_IDS = [
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333'
];

export const options = {
    scenarios: {
        warmup: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30s', target: 20 },   // Ramp up slowly
                { duration: DURATION, target: 50 }, // Sustain moderate load
                { duration: '10s', target: 0 },     // Cool down
            ],
        },
    },
};

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

export default function () {
    const headers = { 'Content-Type': 'application/json' };
    const operation = Math.random();

    if (operation < 0.3) {
        const payload = JSON.stringify({
            user_id: randomUser(),
            pair: 'BTCUSDT',
            side: randomSide(),
            price: parseFloat(randomPrice()),
            quantity: parseFloat(randomQuantity())
        });
        const res = http.post(`${TARGET}/orders`, payload, { headers });
        check(res, { 'create order': (r) => r.status === 201 });

    } else if (operation < 0.6) {
        const res = http.get(`${TARGET}/orderbook/BTCUSDT`);
        check(res, { 'get orderbook': (r) => r.status === 200 });

    } else if (operation < 0.85) {
        const res = http.get(`${TARGET}/balance/${randomUser()}`);
        check(res, { 'get balance': (r) => r.status === 200 });

    } else {
        const res = http.post(`${TARGET}/trades/match?pair=BTCUSDT`, null, { headers });
        check(res, { 'match orders': (r) => r.status === 200 });
    }

    sleep(0.1); // Small delay for warmup
}

export function handleSummary(data) {
    const service = TARGET.includes('8080') ? 'Go' : 'Java';
    const rps = data.metrics.http_reqs?.values?.rate || 0;
    const p95 = data.metrics.http_req_duration?.values?.['p(95)'] || 0;
    
    console.log(`\n✅ ${service} Warmup Complete`);
    console.log(`   RPS: ${rps.toFixed(0)}, P95: ${p95.toFixed(2)}ms\n`);
    
    return {};
}
