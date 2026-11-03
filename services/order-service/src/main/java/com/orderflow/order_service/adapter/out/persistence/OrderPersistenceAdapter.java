package com.orderflow.order_service.adapter.out.persistence;

import com.orderflow.order_service.application.port.out.OrderRepository;
import com.orderflow.order_service.domain.Order;
import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.UUID;

@Component
public class OrderPersistenceAdapter implements OrderRepository {

    private final SpringDataOrderRepository jpaRepository;

    public OrderPersistenceAdapter(SpringDataOrderRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public Order save(Order order) {
        OrderJpaEntity saved = jpaRepository.save(toEntity(order));
        return toDomain(saved);
    }

    @Override
    public Optional<Order> findById(UUID id) {
        return jpaRepository.findById(id).map(this::toDomain);
    }

    private OrderJpaEntity toEntity(Order order) {
        return new OrderJpaEntity(order.getId(), order.getCustomerId(),
                order.getCustomerEmail(), order.getTotalAmount(), order.getStatus(), order.getCreatedAt());
    }

    private Order toDomain(OrderJpaEntity entity) {
        return new Order(entity.getId(), entity.getCustomerId(),
                entity.getCustomerEmail(), entity.getTotalAmount(), entity.getStatus(), entity.getCreatedAt());
    }
}