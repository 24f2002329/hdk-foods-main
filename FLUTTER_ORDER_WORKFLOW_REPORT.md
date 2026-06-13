# Flutter Frontend Order Workflow Analysis
**Frontend Path:** `/home/devendra/Documents/hdk-foods-main/frontend/lib`

---

## 1. Directory Structure

```
lib/
├── core/
│   └── storage/
│       └── token_storage.dart              # Token persistence
├── features/
│   ├── address/
│   │   ├── models/
│   │   │   └── customer_address.dart       # Address model
│   │   ├── screens/
│   │   │   ├── address_screen.dart         # Address list & management
│   │   │   └── location_picker_screen.dart # Google Maps integration (referenced)
│   │   └── services/
│   │       ├── address_service.dart        # API: CRUD addresses
│   │       └── google_places_service.dart  # (referenced)
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── onboarding_screen.dart
│   │   │   └── splash_screen.dart
│   │   └── services/
│   │       └── auth_service.dart           # Firebase Auth + OTP
│   ├── cart/
│   │   ├── models/
│   │   │   └── cart_item.dart              # Local cart item model
│   │   ├── screens/
│   │   │   └── cart_screen.dart            # Cart UI with add/remove/quantity
│   │   └── services/
│   │       └── cart_provider.dart          # Provider-based state management
│   ├── checkout/
│   │   └── screens/
│   │       ├── checkout_screen.dart        # Address selection + order summary + place order
│   │       └── waiting_room_screen.dart    # 5-min countdown + call button + status polling
│   ├── home/
│   │   ├── screens/
│   │   │   └── home_screen.dart            # Tab-based navigation
│   │   ├── services/
│   │   │   └── product_service.dart        # Fetch products from API
│   │   └── widgets/
│   │       └── home_products_section.dart
│   ├── menu/
│   │   └── screens/
│   │       ├── menu_screen.dart
│   │       └── category_products_screen.dart
│   ├── orders/
│   │   ├── models/
│   │   │   └── order.dart                  # Minimal order model
│   │   ├── screens/
│   │   │   └── orders_screen.dart          # "Coming Soon" placeholder
│   │   └── services/
│   │       └── order_service.dart          # POST order creation
│   └── profile/
│       └── screens/
│           └── profile_screen.dart
├── shared/
│   ├── models/
│   │   ├── category.dart
│   │   └── product.dart
│   └── widgets/
│       ├── product_card.dart
│       ├── product_row.dart
│       ├── category_card.dart
│       └── category_grid_card.dart
├── main.dart                               # App entry, routing, Provider setup
└── firebase_options.dart
```

---

## 2. Cart Implementation

**✓ EXISTS**

### Cart State Management
- **File:** `features/cart/services/cart_provider.dart` (lines 1-86)
- **Approach:** Provider (ChangeNotifier pattern)
- **Class:** `CartProvider` 
- **Functionality:**
  - `addProduct(Product)` - add or increment (line 33)
  - `increaseQuantity(Product)` - alias for add (line 50)
  - `decreaseQuantity(Product)` - decrement or remove (line 54)
  - `removeProduct(Product)` - delete item (line 72)
  - `clearCart()` - empty cart (line 78)
  - Getters: `items`, `itemCount`, `totalAmount`

### Cart Model
- **File:** `features/cart/models/cart_item.dart` (lines 1-21)
- **Structure:** Product + quantity

### Cart Screen
- **File:** `features/cart/screens/cart_screen.dart` (lines 1-241)
- **Features:**
  - List cart items with image, price, quantity controls (lines 56-160)
  - Remove item button (line 142)
  - Clear all button (line 29)
  - Subtotal display (line 196)
  - "Proceed to Checkout" button → navigates to `/checkout` (line 208)
- **Consumer pattern:** Uses `context.watch<CartProvider>()` (line 40)

### Add-to-Cart Logic
- **Location:** `cart_provider.dart:addProduct()` (line 33)
- **Integration:** Called from product cards (assumed in `product_card.dart`)
- **State persistence:** In-memory only (clears on app restart)

---

## 3. Address Management

**✓ EXISTS - COMPREHENSIVE**

### Address Model
- **File:** `features/address/models/customer_address.dart` (lines 1-95)
- **Fields:** id, label, house, street, landmark, city, pincode, latitude, longitude, isDefault
- **Methods:**
  - `fromJson()` - backend parsing (line 26)
  - `toJson()` - serialize for API (line 41)
  - `copyWith()` - immutable updates (line 55)
  - `lineOne` & `lineTwo` - formatted address display (lines 81-94)

### Address Screen
- **File:** `features/address/screens/address_screen.dart` (lines 1-826)
- **Features:**
  - **List addresses** with FutureBuilder (line 110)
  - **Add new address** via FAB (line 103)
  - **Edit address** - opens modal bottom sheet (line 39)
  - **Delete address** with confirmation (line 73)
  - **Set default address** (line 63)
  - **Location picker** integration (lines 390-446)
    - Opens Google Maps to pick location
    - Auto-fills street, city, pincode, lat/long
  - **Form validation** for required fields (lines 664-670)

### Address Service
- **File:** `features/address/services/address_service.dart` (lines 1-88)
- **Base URL:** `http://10.53.14.18:8000`
- **Endpoints:**
  - `GET /api/addresses/` - fetch all (line 12)
  - `POST /api/addresses/` - create (line 26)
  - `PUT /api/addresses/{id}/` - update (line 46)
  - `DELETE /api/addresses/{id}/` - delete (line 66)
- **Auth:** Bearer token from TokenStorage (line 77)

---

## 4. Checkout & Order Placement

**✓ EXISTS - PARTIAL**

### Checkout Screen
- **File:** `features/checkout/screens/checkout_screen.dart` (lines 1-256)
- **Features:**
  - **Address selection** (lines 139-197)
    - Loads default address or first address on init (lines 37-59)
    - "Change" button to reselect (line 190)
    - "Add Address" button if none exist (line 155)
  - **Order summary** (lines 199-233)
    - Item breakdown with quantities & prices
    - Total amount display
  - **Place Order button** (lines 242-250)
    - Validates address selection
    - Creates order via OrderService (line 79)
    - Clears cart on success (line 84)
    - Navigates to WaitingRoomScreen (lines 87-95)
  - **Error handling** with SnackBar (lines 63-65, 99-101)

### Order Creation
- **File:** `features/orders/services/order_service.dart` (lines 1-41)
- **Endpoint:** `POST http://10.53.14.18:8000/api/orders/`
- **Payload:**
  ```json
  {
    "address_id": int,
    "items": [{"product_id": int, "quantity": int}],
    "payment_method": "cod",
    "delivery_notes": ""
  }
  ```
- **Response:** Order object with id, order_number, status (line 36)
- **Auth:** Firebase ID token (line 19)

---

## 5. Order Confirmation (Waiting Room)

**✓ EXISTS - IMPLEMENTS 5-MIN WINDOW + CALL BUTTON**

### Waiting Room Screen
- **File:** `features/checkout/screens/waiting_room_screen.dart` (lines 1-225)
- **Features:**
  - **5-minute countdown timer** (lines 46-56)
    - Starts on init (line 33)
    - Displays formatted MM:SS (line 108)
    - Countdown ticks every 1 second (line 47)
  - **Order status polling** (lines 58-62)
    - Polls every 10 seconds (line 59)
    - Hits `GET http://10.53.14.18:8000/api/orders/{orderId}/` (line 67)
    - Checks for `status == 'confirmed'` or `'rejected'` (lines 74, 85)
  - **UI display:**
    - Order number (line 161)
    - Large countdown timer in orange (lines 174-181)
    - "Restaurant is taking longer" message when time expires (lines 182-187)
    - Loading spinner (line 191)
  - **Call restaurant button** (lines 198-216)
    - Phone URI scheme `tel:+919999999999` (line 115)
    - Hard-coded number - needs to be parameterized
    - Uses `url_launcher` package (line 5)
  - **Behavior:**
    - Auto-navigates to payment on `confirmed` (lines 74-84)
    - Shows error & pops on `rejected` (lines 85-95)
    - Timers cancel on status change (lines 76, 86)

---

## 6. Payment

**MISSING - FRAMEWORK PRESENT BUT NOT INTEGRATED**

### What Exists
- **Razorpay dependency** in pubspec.yaml (line 48)
  ```yaml
  razorpay_flutter: ^1.3.6
  ```
- **Order service supports payment method** parameter (line 12 in order_service.dart)
  - Default set to `'cod'` (line 12)
  - Passed to backend but app doesn't expose UI

### What's Missing
- **No payment method selection screen**
- **No payment gateway integration** (Razorpay UI not implemented)
- **No payment status handling**
- **Waiting room shows SnackBar "Proceeding to payment..." but has no target screen** (line 81)

### Required Implementation
1. Create `features/payment/screens/payment_screen.dart`
2. Add Razorpay checkout UI
3. Handle payment success/failure callbacks
4. Navigate to order tracking on success

---

## 7. Order Tracking

**MISSING - PLACEHOLDER ONLY**

### What Exists
- **Screen:** `features/orders/screens/orders_screen.dart` (lines 1-28)
- **Status:** "Coming Soon" placeholder (line 21)
- **Routing:** Accessible from bottom nav in home_screen.dart

### What's Missing
- **No order history API integration**
- **No order details display** (status, items, delivery info, etc.)
- **No real-time tracking** (WebSocket or polling)
- **No order model expansion** - currently only has `id`, `order_number`, `status` (order.dart:1-15)

### Required Implementation
1. Fetch user's orders from `GET /api/orders/` endpoint
2. Display order list with status badges
3. Order detail screen showing:
   - Items ordered
   - Delivery address
   - Current status (pending → accepted → preparing → ready → out for delivery → delivered)
   - Estimated delivery time
   - Call/chat with delivery agent

---

## 8. API Service Layer

### Base URLs
- **Address API:** `http://10.53.14.18:8000` (address_service.dart:9)
- **Order API:** `http://10.53.14.18:8000/api/orders/` (order_service.dart:7)
- **Waiting room polling:** `http://10.53.14.18:8000/api/orders/{id}/` (waiting_room_screen.dart:67)
- **Auth API:** `http://10.53.14.18:8000/api/auth/verify-otp/` (auth_service.dart:68)

### HTTP Library
- **Package:** `http: ^1.6.0` (pubspec.yaml:37)
- **Usage:** Direct `http.get()`, `http.post()`, `http.put()`, `http.delete()` calls

### Order-Related Endpoints

| Endpoint | Method | File | Line | Purpose |
|----------|--------|------|------|---------|
| `/api/orders/` | POST | order_service.dart | 21 | Create order |
| `/api/orders/{id}/` | GET | waiting_room_screen.dart | 67 | Poll order status |
| `/api/addresses/` | GET | address_service.dart | 12 | Fetch user addresses |
| `/api/addresses/` | POST | address_service.dart | 26 | Create address |
| `/api/addresses/{id}/` | PUT | address_service.dart | 46 | Update address |
| `/api/addresses/{id}/` | DELETE | address_service.dart | 66 | Delete address |

### Authentication
- **Method:** Bearer token (Firebase ID token)
- **Storage:** `core/storage/token_storage.dart` (not shown but referenced)
- **Passed via:** `Authorization: Bearer {token}` header

---

## 9. State Management

**✓ PROVIDER (ChangeNotifier)**

### Setup
- **File:** `main.dart:28-29`
- **Root provider:** CartProvider (ChangeNotifier)
  ```dart
  ChangeNotifierProvider(create: (_) => CartProvider())
  ```

### Usage Pattern
- **Write:** `context.read<CartProvider>().addProduct(product)`
- **Watch:** `context.watch<CartProvider>().items`
- **Consume:** `Consumer<CartProvider>(builder: ...)`

### No Other State Management
- Address/order screens use local `setState()` with Futures
- No Bloc, Riverpod, or GetX
- No Redux or MobX
- No centralized authentication state (uses Firebase directly)

---

## 10. Routing & Navigation

### Named Routes (main.dart:75-80)
```dart
routes: {
  '/addresses': AddressScreen,
  '/login': LoginScreen,
  '/home': HomeScreen,
  '/checkout': CheckoutScreen,
}
```

### Navigation Flow
```
HomeScreen (splash → login → home)
  ↓
  Bottom Nav → Cart
    ↓
    CartScreen (shows items)
      ↓
      [Proceed to Checkout] → Navigator.pushNamed('/checkout')
        ↓
        CheckoutScreen (address selection)
          ↓
          [Place Order] → _placeOrder() creates order via OrderService
            ↓
            Navigator.pushReplacement() → WaitingRoomScreen
              ↓
              Polls order status (GET /api/orders/{id}/)
                ↓
                Status 'confirmed' → SnackBar "Proceeding to payment..." (no target!)
                ↓
                Status 'rejected' → Navigator.pop() back to checkout
```

### Address Navigation
- `/addresses` accessed from:
  - HomeScreen bottom nav (lines 76-77)
  - CheckoutScreen "Change" button (line 191)
  - AddressScreen floating action button (line 104)

### Tab Navigation
- HomeScreen uses nested Navigators with `IndexedStack` (lines 65-86)
  - Tab 0: Home (products)
  - Tab 1: Profile
- Bottom nav in _FoodBottomNavigationBar (lines 87-91)

---

## 11. Dependencies (pubspec.yaml)

### Relevant Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `provider` | ^6.1.5+1 | State management (CartProvider) |
| `http` | ^1.6.0 | API calls |
| `firebase_core` | ^4.0.0 | Firebase initialization |
| `firebase_auth` | ^6.0.0 | Phone auth + OTP |
| `razorpay_flutter` | ^1.3.6 | Payment gateway (NOT INTEGRATED) |
| `google_maps_flutter` | ^2.17.1 | Map display in address picker |
| `geolocator` | ^14.0.2 | Device location |
| `url_launcher` | ^6.2.5 | Phone calls & URL handling |
| `flutter_secure_storage` | ^10.3.1 | Secure token storage |
| `flutter_dotenv` | ^6.0.0 | Environment variables |
| `google_fonts` | ^6.2.1 | Poppins font |

**Missing for notifications:** No `firebase_messaging`, `fcm_config`, etc.

---

## Complete Order Workflow Analysis

### FULL FLOW (Current State)

```
1. ADD TO CART
   ✓ Product card → CartProvider.addProduct()
   ✓ State updates → cart count in bottom nav
   ✓ Local state only (in-memory, no persistence)

2. VIEW CART
   ✓ CartScreen displays all items
   ✓ Quantity +/- buttons
   ✓ Remove item button
   ✓ "Proceed to Checkout" button

3. SELECT ADDRESS
   ✓ CheckoutScreen loads default address
   ✓ Address display with label, street, city
   ✓ "Change" button → AddressScreen
   ✓ Can add/edit/delete addresses with Google Maps picker
   ✓ Address saved to backend API
   ✓ Validation: required fields

4. PLACE ORDER
   ✓ CheckoutScreen shows order summary
   ✓ "Place Order" button validates address
   ✓ POST to /api/orders/ with:
     - address_id
     - items (product_id + quantity)
     - payment_method='cod' (hardcoded)
   ✓ Cart cleared on success

5. WAIT FOR CONFIRMATION (5-min window)
   ✓ WaitingRoomScreen displays
   ✓ 5-minute countdown timer (MM:SS format)
   ✓ Polling GET /api/orders/{id}/ every 10 seconds
   ✓ "Call Restaurant" button (phone URI)
   ✓ Status check: 'confirmed' or 'rejected'

6. PAYMENT
   ✗ NO IMPLEMENTATION
   ✗ WaitingRoom shows SnackBar "Proceeding to payment..." but no screen
   ✗ Razorpay package present but unused
   ✗ Order service defaults payment_method='cod'

7. ORDER TRACKING
   ✗ NO IMPLEMENTATION (placeholder only)
   ✗ OrdersScreen shows "Coming Soon"
   ✗ No order history fetching
   ✗ No real-time status updates
```

### WHAT EXISTS vs MISSING

| Feature | Status | Location | Notes |
|---------|--------|----------|-------|
| **Cart Management** | ✓ Complete | cart_provider.dart + cart_screen.dart | In-memory, no persistence |
| **Add to Cart** | ✓ Complete | cart_provider.dart | Works from product cards |
| **Address Selection** | ✓ Complete | checkout_screen.dart | Default auto-loads |
| **Address CRUD** | ✓ Complete | address_service.dart + address_screen.dart | Full UI + API integration |
| **Address on Map** | ✓ Complete | location_picker_screen.dart | Google Maps integration |
| **Checkout Screen** | ✓ Complete | checkout_screen.dart | Summary + validation |
| **Order Creation** | ✓ Complete | order_service.dart | POST endpoint hit |
| **5-min Wait Window** | ✓ Complete | waiting_room_screen.dart | Countdown + polling |
| **Call Restaurant** | ✓ Implemented | waiting_room_screen.dart | Hard-coded number |
| **Order Status Polling** | ✓ Complete | waiting_room_screen.dart | Checks confirmed/rejected |
| **Payment Method Selection** | ✗ Missing | — | Hard-coded to 'cod' |
| **Razorpay Integration** | ✗ Missing | — | Package installed, no UI |
| **Payment Processing** | ✗ Missing | — | No screen after confirmation |
| **Order History** | ✗ Missing | orders_screen.dart | Placeholder only |
| **Order Tracking** | ✗ Missing | — | No real-time tracking |
| **Notifications** | ✗ Missing | — | No FCM setup |
| **Cart Persistence** | ✗ Missing | — | Clears on app restart |

---

## Summary

### Strengths
1. **Clean architecture** with clear feature separation
2. **Provider pattern** for state management (scalable)
3. **Complete address flow** with Google Maps integration
4. **5-minute confirmation window** with countdown + polling
5. **Proper API authentication** using Bearer tokens
6. **Modal bottom sheets** for address forms
7. **Comprehensive address validation** (lat/long, required fields)
8. **Call functionality** for customer-restaurant direct contact

### Gaps
1. **No payment flow** - Razorpay installed but unused
2. **No order tracking** - only placeholder
3. **No notifications** - no FCM integration
4. **Cart not persistent** - clears on app restart
5. **Hard-coded restaurant number** in waiting room
6. **No order history UI** - backend API may exist but not called
7. **No real-time updates** - only polling, no WebSocket

### Recommended Next Steps
1. Implement payment screen + Razorpay checkout
2. Build order tracking with status polling/WebSocket
3. Add cart persistence to local storage
4. Implement FCM for push notifications
5. Expand Order model with full details (items, total, delivery address, etc.)
6. Add order history API integration
