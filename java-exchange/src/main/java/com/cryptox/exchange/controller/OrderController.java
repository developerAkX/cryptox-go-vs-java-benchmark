package com.cryptox.exchange.controller;

import com.cryptox.exchange.dto.CreateOrderRequest;
import com.cryptox.exchange.dto.MatchResult;
import com.cryptox.exchange.dto.OrderBookResponse;
import com.cryptox.exchange.entity.Order;
import com.cryptox.exchange.service.TradingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
public class OrderController {

    private final TradingService tradingService;

    @PostMapping("/orders")
    public ResponseEntity<Order> createOrder(@Valid @RequestBody CreateOrderRequest request) {
        Order order = tradingService.createOrder(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(order);
    }

    @GetMapping("/orderbook/{pair}")
    public ResponseEntity<OrderBookResponse> getOrderBook(@PathVariable String pair) {
        OrderBookResponse orderBook = tradingService.getOrderBook(pair);
        return ResponseEntity.ok(orderBook);
    }

    @PostMapping("/trades/match")
    public ResponseEntity<MatchResult> matchOrders(@RequestParam(defaultValue = "BTC/USDT") String pair) {
        MatchResult result = tradingService.matchOrders(pair);
        return ResponseEntity.ok(result);
    }
}
