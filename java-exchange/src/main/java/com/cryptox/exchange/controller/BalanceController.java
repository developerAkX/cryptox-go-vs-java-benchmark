package com.cryptox.exchange.controller;

import com.cryptox.exchange.dto.BalanceResponse;
import com.cryptox.exchange.service.TradingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequiredArgsConstructor
public class BalanceController {

    private final TradingService tradingService;

    @GetMapping("/balance/{userId}")
    public ResponseEntity<BalanceResponse> getBalance(@PathVariable UUID userId) {
        BalanceResponse balance = tradingService.getUserBalances(userId);
        return ResponseEntity.ok(balance);
    }
}
