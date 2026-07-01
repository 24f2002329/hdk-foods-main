# Cashfree Payment Gateway Integration

This document outlines the Cashfree payment gateway integration, order creation, session generation, and payment verification sequences.

---

## 1. End-to-End Checkout Flow

```mermaid
sequenceDiagram
    participant Client as Flutter Application
    participant SDK as Cashfree PG SDK
    participant Backend as Django Backend (orders/payments)
    participant CF as Cashfree API Services

    Client->>Backend: POST /api/orders/create/ (Payload)
    Backend-->>Client: 201 Created (Order object, order_id)
    
    Client->>Backend: POST /api/orders/<order_id>/select-payment/ (COD or Online)
    
    alt Payment Method is COD
        Backend-->>Client: 200 OK (Payment select success, proceed to tracker)
    else Payment Method is Online (Cashfree)
        Backend->>CF: Create Cashfree Order (Order amount, ID)
        CF-->>Backend: Return Cashfree Session (payment_session_id, order_id)
        Backend-->>Client: 200 OK (payment_session_id)
        
        Client->>SDK: Start Payment Flow (payment_session_id)
        Note over SDK: Render UPI / Card / NetBanking UI
        SDK-->>Client: Return Payment Transaction Status
        
        Client->>Backend: POST /api/orders/<order_id>/verify-payment/
        Backend->>CF: Query Payment Status (verify cashfree_order_id)
        CF-->>Backend: Return Status (PAID / FAILED)
        
        alt Verification SUCCESS
            Backend->>Backend: Mark Order as "confirmed", set payment_status="paid"
            Backend-->>Client: 200 OK (Verification Success)
        else Verification FAILED
            Backend-->>Client: 400 Bad Request (Payment failed or pending)
        end
    end
```

---

## 2. API Endpoints

### 1. Select Payment Method
* **Endpoint**: `POST /api/orders/<order_id>/select-payment/`
* **Payload**:
  ```json
  {
    "payment_method": "online"  // 'cod' or 'online'
  }
  ```
* **Response (Online)**:
  ```json
  {
    "payment_session_id": "session_a1b2c3d4...",
    "cf_order_id": "cf_order_998877..."
  }
  ```

### 2. Verify Payment
* **Endpoint**: `POST /api/orders/<order_id>/verify-payment/`
* **Response**:
  ```json
  {
    "status": "success",
    "message": "Payment verified successfully"
  }
  ```

---

## 3. Flutter Integration (`flutter_cashfree_pg_sdk`)

For online payments, the Flutter client processes transactions natively:

```dart
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';

void startCashfreePayment(String sessionId, String orderId) {
  var session = CFSessionBuilder()
      .setEnvironment(AppConfig.isProd ? CFEnvironment.PRODUCTION : CFEnvironment.SANDBOX)
      .setPaymentSessionId(sessionId)
      .setOrderId(orderId)
      .build();

  var payment = CFWebCheckoutPaymentBuilder().setSession(session).build();
  
  // Launch Cashfree Gateway Overlay
  CFPaymentGatewayService().doPayment(payment);
}
```
* **Production Gateway**: Set `CFEnvironment.PRODUCTION`.
* **Sandbox Gateway**: Set `CFEnvironment.SANDBOX` (requires test UPI ids or mock cards).
