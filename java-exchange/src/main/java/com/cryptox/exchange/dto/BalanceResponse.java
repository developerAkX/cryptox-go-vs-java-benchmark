package com.cryptox.exchange.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

@Data
@AllArgsConstructor
public class BalanceResponse {
    private UUID userId;
    private Map<String, BigDecimal> balances;
}
