package com.cryptox.exchange.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
@AllArgsConstructor
public class OrderBookResponse {
    private String pair;
    private List<OrderBookEntry> bids;
    private List<OrderBookEntry> asks;

    @Data
    @AllArgsConstructor
    public static class OrderBookEntry {
        private BigDecimal price;
        private BigDecimal quantity;
    }
}
