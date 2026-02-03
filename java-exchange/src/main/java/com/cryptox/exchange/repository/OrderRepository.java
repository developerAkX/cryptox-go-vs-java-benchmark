package com.cryptox.exchange.repository;

import com.cryptox.exchange.entity.Order;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrderRepository extends JpaRepository<Order, UUID> {

    // Original queries for matching engine
    @Query("SELECT o FROM Order o WHERE o.pair = :pair AND o.side = 'BUY' AND o.status = 'OPEN' ORDER BY o.price DESC, o.createdAt ASC")
    List<Order> findBids(@Param("pair") String pair);

    @Query("SELECT o FROM Order o WHERE o.pair = :pair AND o.side = 'SELL' AND o.status = 'OPEN' ORDER BY o.price ASC, o.createdAt ASC")
    List<Order> findAsks(@Param("pair") String pair);

    @Query("SELECT o FROM Order o WHERE o.pair = :pair AND o.side = 'BUY' AND o.status = 'OPEN' ORDER BY o.price DESC, o.createdAt ASC LIMIT 1")
    Optional<Order> findBestBid(@Param("pair") String pair);

    @Query("SELECT o FROM Order o WHERE o.pair = :pair AND o.side = 'SELL' AND o.status = 'OPEN' ORDER BY o.price ASC, o.createdAt ASC LIMIT 1")
    Optional<Order> findBestAsk(@Param("pair") String pair);

    // Optimized native queries for order book aggregation (bypasses Hibernate overhead)
    @Query(value = """
            SELECT price, SUM(quantity) as total_quantity
            FROM orders
            WHERE pair = :pair AND side = 'BUY' AND status = 'OPEN'
            GROUP BY price
            ORDER BY price DESC
            LIMIT 50
            """, nativeQuery = true)
    List<Object[]> findBidsAggregated(@Param("pair") String pair);

    @Query(value = """
            SELECT price, SUM(quantity) as total_quantity
            FROM orders
            WHERE pair = :pair AND side = 'SELL' AND status = 'OPEN'
            GROUP BY price
            ORDER BY price ASC
            LIMIT 50
            """, nativeQuery = true)
    List<Object[]> findAsksAggregated(@Param("pair") String pair);
}
