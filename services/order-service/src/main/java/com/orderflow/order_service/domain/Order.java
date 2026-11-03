package com.orderflow.order_service.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public class Order {

    private final UUID id;
    private final String customerId;
    private final String customerEmail;
    private final BigDecimal totalAmount;
    private OrderStatus status;
    private final Instant createdAt;

    public Order(UUID id, String customerId, String customerEmail, BigDecimal totalAmount,
            OrderStatus status, Instant createdAt) {
        this.id = id;
        this.customerId = customerId;
        this.customerEmail = customerEmail;
        this.totalAmount = totalAmount;
        this.status = status;
        this.createdAt = createdAt;
    }

    public static Order create(String customerId, String customerEmail, BigDecimal totalAmount) {
        if (totalAmount == null || totalAmount.signum() <= 0) {
            throw new InvalidOrderTotalException("Order total must be positive");
        }
        if (customerId == null || customerId.isBlank()) {
            throw new InvalidCustomerIdException("Order customer ID must not be empty");
        }
        return new Order(UUID.randomUUID(), customerId, customerEmail, totalAmount,
                OrderStatus.CREATED, Instant.now());
    }

    public UUID getId() {
        return id;
    }

    public String getCustomerId() {
        return customerId;
    }

    public String getCustomerEmail() {
        return customerEmail;
    }

    public BigDecimal getTotalAmount() {
        return totalAmount;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}