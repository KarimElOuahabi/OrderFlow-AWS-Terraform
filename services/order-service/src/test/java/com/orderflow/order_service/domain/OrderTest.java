package com.orderflow.order_service.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

class OrderTest {

    private static final String VALID_CUSTOMER_ID = "c-01";
    private static final String VALID_EMAIL = "c01@example.com";
    private static final BigDecimal VALID_TOTAL = new BigDecimal("100.00");

    @Test
    void create_withValidInput_returnsCreatedOrder() {
        Order order = Order.create(VALID_CUSTOMER_ID, VALID_EMAIL, VALID_TOTAL);

        assertEquals(VALID_CUSTOMER_ID, order.getCustomerId());
        assertEquals(VALID_TOTAL, order.getTotalAmount());
        assertEquals(OrderStatus.CREATED, order.getStatus());
    }

    @Test
    void create_keepsCustomerEmail() {
        Order order = Order.create(VALID_CUSTOMER_ID, VALID_EMAIL, VALID_TOTAL);

        assertEquals(VALID_EMAIL, order.getCustomerEmail());
    }

    @Test
    void create_withNullEmail_stillCreatesOrder() {
        Order order = Order.create(VALID_CUSTOMER_ID, null, VALID_TOTAL);

        assertNull(order.getCustomerEmail());
        assertEquals(OrderStatus.CREATED, order.getStatus());
    }

    @Test
    void create_withNegativeTotal_throwsInvalidOrderTotalException() {
        assertThrows(InvalidOrderTotalException.class,
                () -> Order.create(VALID_CUSTOMER_ID, VALID_EMAIL, new BigDecimal("-50.00")));
    }

    @Test
    void create_withZeroTotal_throwsInvalidOrderTotalException() {
        assertThrows(InvalidOrderTotalException.class,
                () -> Order.create(VALID_CUSTOMER_ID, VALID_EMAIL, BigDecimal.ZERO));
    }

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = { " ", "   ", "\t" })
    void create_withBlankCustomerId_throwsInvalidCustomerIdException(String customerId) {
        assertThrows(InvalidCustomerIdException.class,
                () -> Order.create(customerId, VALID_EMAIL, VALID_TOTAL));
    }
}