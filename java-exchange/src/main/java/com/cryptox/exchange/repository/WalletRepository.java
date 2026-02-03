package com.cryptox.exchange.repository;

import com.cryptox.exchange.entity.Wallet;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.QueryHints;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import jakarta.persistence.QueryHint;
import java.util.List;
import java.util.UUID;

@Repository
public interface WalletRepository extends JpaRepository<Wallet, UUID> {
    
    @Query("SELECT w FROM Wallet w WHERE w.userId = :userId")
    @QueryHints({
        @QueryHint(name = "org.hibernate.fetchSize", value = "50"),
        @QueryHint(name = "org.hibernate.readOnly", value = "true")
    })
    List<Wallet> findByUserId(@Param("userId") UUID userId);
}
