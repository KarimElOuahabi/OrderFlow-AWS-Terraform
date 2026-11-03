package com.orderflow.order_service.application.port.in;

import com.orderflow.order_service.domain.Order;
import java.math.BigDecimal;

public interface CreateOrderUseCase {
     Order createOrder(String customerId, String customerEmail, BigDecimal totalAmount);
}
