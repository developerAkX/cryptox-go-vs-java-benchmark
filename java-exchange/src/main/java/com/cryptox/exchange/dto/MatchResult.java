package com.cryptox.exchange.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.math.BigDecimal;

@Data
@AllArgsConstructor
public class MatchResult {
    private int tradesExecuted;
    private BigDecimal volumeMatched;
}
