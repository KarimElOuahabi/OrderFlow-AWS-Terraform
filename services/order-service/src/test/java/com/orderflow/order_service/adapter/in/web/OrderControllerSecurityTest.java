package com.orderflow.order_service.adapter.in.web;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;

import com.orderflow.order_service.application.port.in.CreateOrderUseCase;
import com.orderflow.order_service.domain.Order;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(OrderController.class)
@Import(SecurityConfig.class)
class OrderControllerSecurityTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    CreateOrderUseCase createOrderUseCase;

    @MockitoBean
    JwtDecoder jwtDecoder;

    private static final String BODY = "{\"totalAmount\": 25.50}";

    @Test
    void createOrder_withoutToken_returns401() throws Exception {
        mockMvc.perform(post("/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(BODY))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void createOrder_withToken_returns201_andUsesSubjectAsCustomerId_andEmailClaim() throws Exception {
        when(createOrderUseCase.createOrder(any(), any(), any())).thenReturn(mock(Order.class));

        mockMvc.perform(post("/orders")
                        .with(jwt().jwt(j -> j.subject("user-123").claim("email", "user@example.com")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(BODY))
                .andExpect(status().isCreated());

        verify(createOrderUseCase).createOrder(eq("user-123"), eq("user@example.com"), eq(new BigDecimal("25.50")));
    }

    @Test
    void createOrder_withTokenWithoutEmail_returns201_andPassesNullEmail() throws Exception {
        when(createOrderUseCase.createOrder(any(), any(), any())).thenReturn(mock(Order.class));

        mockMvc.perform(post("/orders")
                        .with(jwt().jwt(j -> j.subject("user-123")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(BODY))
                .andExpect(status().isCreated());

        verify(createOrderUseCase).createOrder(eq("user-123"), isNull(), eq(new BigDecimal("25.50")));
    }
}