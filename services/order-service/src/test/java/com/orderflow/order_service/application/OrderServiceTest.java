package com.orderflow.order_service.application;

import com.orderflow.order_service.application.port.out.OrderRepository;
import com.orderflow.order_service.application.port.out.OutboxPort;
import com.orderflow.order_service.domain.InvalidOrderTotalException;
import com.orderflow.order_service.domain.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    OrderRepository orderRepository;

    @Mock
    OutboxPort outbox;

    @InjectMocks
    OrderService orderService;

    @Test
    void createOrder_savesOrder_andWritesOutboxEvent() {
        when(orderRepository.save(any(Order.class))).thenAnswer(i -> i.getArgument(0));

        Order result = orderService.createOrder("c-01", "c01@example.com", new BigDecimal("100.00"));

        assertEquals("c-01", result.getCustomerId());
        assertEquals("c01@example.com", result.getCustomerEmail());
        verify(orderRepository).save(any(Order.class));
        System.out.println("1 - Order saved successfully");
        verify(outbox).saveOrderCreated(result);
        System.out.println("2 - OrderCreated event written to the outbox");
    }

    @Test
    void createOrder_withNullEmail_stillSavesOrder() {
        when(orderRepository.save(any(Order.class))).thenAnswer(i -> i.getArgument(0));

        Order result = orderService.createOrder("c-01", null, new BigDecimal("100.00"));

        assertNull(result.getCustomerEmail());
        verify(orderRepository).save(any(Order.class));
        verify(outbox).saveOrderCreated(result);
    }

    @Test
    void createOrder_invalidTotal_savesNothing_andWritesNothing() {
        assertThrows(InvalidOrderTotalException.class,
                () -> orderService.createOrder("c-01", "c01@example.com", new BigDecimal("-5")));

        verifyNoInteractions(orderRepository, outbox);
        System.out.println("3 - Invalid order rejected: nothing saved, nothing in the outbox");
    }
}