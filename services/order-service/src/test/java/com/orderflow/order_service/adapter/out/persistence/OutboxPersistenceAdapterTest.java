package com.orderflow.order_service.adapter.out.persistence;

import com.orderflow.order_service.domain.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class OutboxPersistenceAdapterTest {

    @Mock
    SpringDataOutboxRepository repository;

    @InjectMocks
    OutboxPersistenceAdapter adapter;

    private String savedPayload() {
        ArgumentCaptor<OutboxJpaEntity> captor = ArgumentCaptor.forClass(OutboxJpaEntity.class);
        verify(repository).save(captor.capture());
        return captor.getValue().getPayload();
    }

    @Test
    void saveOrderCreated_payloadContainsCustomerEmail() {
        adapter.saveOrderCreated(Order.create("c-01", "c01@example.com", new BigDecimal("100.00")));

        assertTrue(savedPayload().contains("\"customerEmail\":\"c01@example.com\""));
    }

    @Test
    void saveOrderCreated_withNullEmail_writesJsonNull() {
        adapter.saveOrderCreated(Order.create("c-01", null, new BigDecimal("100.00")));

        String payload = savedPayload();
        assertTrue(payload.contains("\"customerEmail\":null"));
        assertFalse(payload.contains("\"null\""));
    }
}
