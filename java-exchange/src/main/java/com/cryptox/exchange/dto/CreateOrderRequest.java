package com.cryptox.exchange.dto;

import com.cryptox.exchange.entity.Order;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;

import java.math.BigDecimal;
import java.util.UUID;

@Data
public class CreateOrderRequest {
    @NotNull
    @JsonProperty("user_id")
    private UUID userId;

    @NotNull
    private String pair;

    @NotNull
    private Order.OrderSide side;

    @NotNull
    @Positive
    private BigDecimal price;

    @NotNull
    @Positive
    private BigDecimal quantity;
}
