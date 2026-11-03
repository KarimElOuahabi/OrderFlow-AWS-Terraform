package com.orderflow.order_service.adapter.out.persistence;

import com.orderflow.order_service.application.port.out.OutboxPort;
import com.orderflow.order_service.application.port.out.PendingEvent;
import com.orderflow.order_service.domain.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Component
public class OutboxPersistenceAdapter implements OutboxPort {

    private final SpringDataOutboxRepository repository;

    public OutboxPersistenceAdapter(SpringDataOutboxRepository repository) {
        this.repository = repository;
    }

    @Override
    public void saveOrderCreated(Order order) {
        repository.save(new OutboxJpaEntity(
                UUID.randomUUID(), order.getId(), "OrderCreated", toJson(order), Instant.now()));
    }

    @Override
    public List<PendingEvent> findPending() {
        return repository.findTop50ByPublishedAtIsNullOrderByCreatedAtAsc().stream()
                .map(row -> new PendingEvent(row.getId(), row.getEventType(), row.getPayload()))
                .toList();
    }

    @Override
    @Transactional
    public void markPublished(UUID eventId) {
        repository.findById(eventId).ifPresent(row -> row.markPublished(Instant.now()));
    }

    private String toJson(Order order) {
        return """
                {"orderId":"%s","customerId":"%s","customerEmail":%s,"totalAmount":%s,"status":"%s","createdAt":"%s"}"""
                .formatted(order.getId(), escape(order.getCustomerId()),
                        toJsonString(order.getCustomerEmail()),
                        order.getTotalAmount().toPlainString(),
                        order.getStatus(), order.getCreatedAt());
    }

    // A missing value is written as JSON null, not as a quoted string.
    private String toJsonString(String value) {
        return value == null ? "null" : "\"" + escape(value) + "\"";
    }

    private String escape(String value) {
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}