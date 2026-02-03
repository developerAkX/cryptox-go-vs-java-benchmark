package com.cryptox.exchange.service;

import com.cryptox.exchange.dto.BalanceResponse;
import com.cryptox.exchange.dto.CreateOrderRequest;
import com.cryptox.exchange.dto.MatchResult;
import com.cryptox.exchange.dto.OrderBookResponse;
import com.cryptox.exchange.entity.Order;
import com.cryptox.exchange.entity.Trade;
import com.cryptox.exchange.entity.Wallet;
import com.cryptox.exchange.repository.OrderRepository;
import com.cryptox.exchange.repository.TradeRepository;
import com.cryptox.exchange.repository.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TradingService {

    private final OrderRepository orderRepository;
    private final WalletRepository walletRepository;
    private final TradeRepository tradeRepository;

    @Transactional
    public Order createOrder(CreateOrderRequest request) {
        Order order = new Order();
        order.setUserId(request.getUserId());
        order.setPair(request.getPair());
        order.setSide(request.getSide());
        order.setPrice(request.getPrice());
        order.setQuantity(request.getQuantity());
        order.setStatus(Order.OrderStatus.OPEN);
        order.setCreatedAt(LocalDateTime.now());

        return orderRepository.save(order);
    }

    @Transactional(readOnly = true)
    public OrderBookResponse getOrderBook(String pair) {
        // Use optimized native queries that aggregate at DB level
        List<Object[]> bidsRaw = orderRepository.findBidsAggregated(pair);
        List<Object[]> asksRaw = orderRepository.findAsksAggregated(pair);

        List<OrderBookResponse.OrderBookEntry> bidEntries = bidsRaw.stream()
                .map(row -> new OrderBookResponse.OrderBookEntry(
                        (BigDecimal) row[0],
                        (BigDecimal) row[1]
                ))
                .toList();

        List<OrderBookResponse.OrderBookEntry> askEntries = asksRaw.stream()
                .map(row -> new OrderBookResponse.OrderBookEntry(
                        (BigDecimal) row[0],
                        (BigDecimal) row[1]
                ))
                .toList();

        return new OrderBookResponse(pair, bidEntries, askEntries);
    }

    @Transactional(readOnly = true)
    public BalanceResponse getUserBalances(UUID userId) {
        List<Wallet> wallets = walletRepository.findByUserId(userId);

        Map<String, BigDecimal> balances = wallets.stream()
                .collect(Collectors.toMap(Wallet::getCurrency, Wallet::getBalance));

        return new BalanceResponse(userId, balances);
    }

    @Transactional
    public MatchResult matchOrders(String pair) {
        Optional<Order> bestBidOpt = orderRepository.findBestBid(pair);
        Optional<Order> bestAskOpt = orderRepository.findBestAsk(pair);

        if (bestBidOpt.isEmpty() || bestAskOpt.isEmpty()) {
            return new MatchResult(0, BigDecimal.ZERO);
        }

        Order bestBid = bestBidOpt.get();
        Order bestAsk = bestAskOpt.get();

        // Check if orders can match (bid price >= ask price)
        if (bestBid.getPrice().compareTo(bestAsk.getPrice()) < 0) {
            return new MatchResult(0, BigDecimal.ZERO);
        }

        // Calculate trade quantity
        BigDecimal tradeQty = bestBid.getQuantity().min(bestAsk.getQuantity());
        BigDecimal tradePrice = bestAsk.getPrice(); // Execute at ask price

        // Create trade
        Trade trade = new Trade();
        trade.setBuyOrderId(bestBid.getId());
        trade.setSellOrderId(bestAsk.getId());
        trade.setPrice(tradePrice);
        trade.setQuantity(tradeQty);
        trade.setExecutedAt(LocalDateTime.now());
        tradeRepository.save(trade);

        // Update orders
        if (bestBid.getQuantity().compareTo(tradeQty) == 0) {
            bestBid.setStatus(Order.OrderStatus.FILLED);
        } else {
            bestBid.setQuantity(bestBid.getQuantity().subtract(tradeQty));
        }
        orderRepository.save(bestBid);

        if (bestAsk.getQuantity().compareTo(tradeQty) == 0) {
            bestAsk.setStatus(Order.OrderStatus.FILLED);
        } else {
            bestAsk.setQuantity(bestAsk.getQuantity().subtract(tradeQty));
        }
        orderRepository.save(bestAsk);

        return new MatchResult(1, tradeQty.multiply(tradePrice));
    }
}
