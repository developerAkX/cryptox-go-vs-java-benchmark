import http from 'k6/http';
import { check } from 'k6';

// Quick smoke test to verify services are up
const TARGET = __ENV.TARGET || 'http://localhost:8080';

export const options = {
    vus: 1,
    iterations: 5,
};

export default function () {
    // Health check
    let res = http.get(`${TARGET}/health`);
    check(res, {
        'health check ok': (r) => r.status === 200,
    });

    // Get orderbook (use BTCUSDT without slash for compatibility)
    res = http.get(`${TARGET}/orderbook/BTCUSDT`);
    check(res, {
        'orderbook ok': (r) => r.status === 200,
    });

    // Get balance
    res = http.get(`${TARGET}/balance/11111111-1111-1111-1111-111111111111`);
    check(res, {
        'balance ok': (r) => r.status === 200,
    });

    // Create order
    const payload = JSON.stringify({
        user_id: '11111111-1111-1111-1111-111111111111',
        pair: 'BTCUSDT',
        side: 'BUY',
        price: 42000.00,
        quantity: 0.1
    });
    res = http.post(`${TARGET}/orders`, payload, {
        headers: { 'Content-Type': 'application/json' }
    });
    check(res, {
        'create order ok': (r) => r.status === 201,
    });
}
