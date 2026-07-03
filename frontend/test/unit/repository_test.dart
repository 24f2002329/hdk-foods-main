import 'package:flutter_test/flutter_test.dart';
import 'package:hdk_core/hdk_core.dart';
import 'package:frontend/features/accounts/domain/repositories/user_repository.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/address/domain/repositories/address_repository.dart';
import 'package:frontend/features/address/data/models/customer_address.dart';
import 'package:frontend/features/orders/domain/repositories/order_repository.dart';

// Mocks
class MockUserRepository implements UserRepository {
  @override
  Future<User> getCurrentUser({bool fromCache = false}) async {
    return User(
      id: 1,
      name: 'Mock User',
      phoneNumber: '1234567890',
      role: 'customer',
    );
  }

  @override
  Future<User> updateName(String name) async {
    return User(id: 1, name: name, phoneNumber: '1234567890', role: 'customer');
  }

  @override
  Future<Map<String, dynamic>> getCoinTransactions() async => {
    'loyalty_coins': 150,
    'transactions': <CoinTransaction>[],
  };
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<String?> sendOtp({required String phoneNumber}) async {
    return 'mock-verification-id';
  }

  @override
  Future<Map<String, dynamic>?> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    return {
      'token': 'mock-session-token',
      'user': {'id': 1, 'name': 'Mock User'},
    };
  }
}

class MockAddressRepository implements AddressRepository {
  @override
  Future<List<CustomerAddress>> getAddresses() async => [];

  @override
  Future<CustomerAddress> createAddress(CustomerAddress address) async {
    return address;
  }

  @override
  Future<CustomerAddress> updateAddress(CustomerAddress address) async {
    return address;
  }

  @override
  Future<void> deleteAddress(CustomerAddress address) async {}
}

class MockOrderRepository implements OrderRepository {
  @override
  Future<Order> getOrder(int orderId) async {
    return Order(
      id: orderId,
      orderNumber: 'ORD-101',
      status: 'pending',
      totalAmount: 100.0,
      items: const [],
      paymentMethod: 'cod',
      paymentStatus: 'pending',
    );
  }

  @override
  Future<Order> createOrder({
    required int addressId,
    required List<Map<String, dynamic>> items,
    String paymentMethod = 'cod',
    String deliveryNotes = '',
    String couponCode = '',
    bool redeemCoins = false,
  }) async {
    return Order(
      id: 1,
      orderNumber: 'ORD-101',
      status: 'pending',
      totalAmount: 100.0,
      items: const [],
      paymentMethod: paymentMethod,
      paymentStatus: 'pending',
    );
  }

  @override
  Future<Map<String, dynamic>?> validateCoupon({
    required String code,
    required double orderTotal,
  }) async => null;

  @override
  Future<List<Map<String, dynamic>>> getActiveCoupons() async => [];

  @override
  Future<Map<String, dynamic>> getMyOrdersPaged({int page = 1}) async => {};

  @override
  Future<List<Order>> getMyOrders() async => [];

  @override
  Future<Map<String, dynamic>> selectPayment({
    required int orderId,
    required String method,
  }) async => {};

  @override
  Future<Order> acknowledgeChanges({
    required int orderId,
    required bool accepted,
  }) async {
    return getOrder(orderId);
  }

  @override
  Future<Order> verifyPayment({required int orderId}) async {
    return getOrder(orderId);
  }

  @override
  Future<int?> getQueuePosition(int orderId) async => null;

  @override
  Future<bool> hasReview(int orderId) async => false;

  @override
  Future<void> submitReview({
    required int orderId,
    required int rating,
    String comment = '',
    List<Map<String, dynamic>> items = const [],
  }) async {}

  @override
  Future<Order> requestCancellation({
    required int orderId,
    required String reason,
  }) async {
    return getOrder(orderId);
  }

  @override
  Future<List<Map<String, dynamic>>> getOrderMessages(int orderId) async => [];

  @override
  Future<Map<String, dynamic>> sendOrderMessage(
    int orderId,
    String message,
  ) async => {};

  @override
  Future<Order> reportNotReceived(int orderId) async {
    return getOrder(orderId);
  }
}

void main() {
  group('Repository Injection Tests', () {
    test('UserRepository supports injection and mock overrides', () async {
      expect(UserRepository.instance, isA<HttpUserRepository>());

      final mockRepo = MockUserRepository();
      UserRepository.instance = mockRepo;

      expect(UserRepository.instance, isA<MockUserRepository>());
      final user = await UserRepository.instance.getCurrentUser();
      expect(user.name, 'Mock User');

      final coinsData = await UserRepository.instance.getCoinTransactions();
      expect(coinsData['loyalty_coins'], 150);
    });

    test('AuthRepository supports injection and mock overrides', () async {
      expect(AuthRepository.instance, isA<HttpAuthRepository>());

      final mockRepo = MockAuthRepository();
      AuthRepository.instance = mockRepo;

      expect(AuthRepository.instance, isA<MockAuthRepository>());
      final verId = await AuthRepository.instance.sendOtp(
        phoneNumber: '+919999999999',
      );
      expect(verId, 'mock-verification-id');
    });

    test('AddressRepository supports injection and mock overrides', () async {
      expect(AddressRepository.instance, isA<HttpAddressRepository>());

      final mockRepo = MockAddressRepository();
      AddressRepository.instance = mockRepo;

      expect(AddressRepository.instance, isA<MockAddressRepository>());
      final addr = await AddressRepository.instance.getAddresses();
      expect(addr, isEmpty);
    });

    test('OrderRepository supports injection and mock overrides', () async {
      expect(OrderRepository.instance, isA<HttpOrderRepository>());

      final mockRepo = MockOrderRepository();
      OrderRepository.instance = mockRepo;

      expect(OrderRepository.instance, isA<MockOrderRepository>());
      final order = await OrderRepository.instance.getOrder(42);
      expect(order.orderNumber, 'ORD-101');
    });
  });
}
