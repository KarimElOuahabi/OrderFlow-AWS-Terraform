package com.orderflow.order_service.application;

import com.orderflow.order_service.application.port.in.CreateOrderUseCase;
import com.orderflow.order_service.application.port.out.OrderRepository;
import com.orderflow.order_service.application.port.out.OutboxPort;
import com.orderflow.order_service.domain.Order;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@Service
public class OrderService implements CreateOrderUseCase {
    private final OrderRepository orderRepository;
    private final OutboxPort outbox;

    public OrderService(OrderRepository orderRepository, OutboxPort outbox) {
        this.orderRepository = orderRepository;
        this.outbox = outbox;
    }

    @Override
    @Transactional
    public Order createOrder(String customerId, String customerEmail, BigDecimal orderAmount) {
        Order order = Order.create(customerId, customerEmail, orderAmount);
        Order saved = orderRepository.save(order);
        outbox.saveOrderCreated(saved);
        return saved;
    }
}