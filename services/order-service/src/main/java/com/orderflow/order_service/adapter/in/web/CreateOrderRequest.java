package com.orderflow.order_service.adapter.in.web;

import java.math.BigDecimal;

public record CreateOrderRequest(BigDecimal totalAmount) {
}