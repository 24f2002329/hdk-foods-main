import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static final String baseUrl =
      dotenv.env['API_BASE_URL']!;

  Future<void> loginWithFirebaseToken(
      String firebaseToken) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/auth/verify-otp/',
      ),
      headers: {
        'Content-Type':
            'application/json',
      },
      body: jsonEncode({
        'firebase_token':
            firebaseToken,
      }),
    );

    print(response.statusCode);
    print(response.body);
  }
}