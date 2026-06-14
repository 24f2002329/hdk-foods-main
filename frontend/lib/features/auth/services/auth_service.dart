import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';

class AuthService {
  Future<bool> sendOtp({
    required String phoneNumber,
    required Function(String) onCodeSent,
  }) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          throw Exception(e.message);
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final firebaseToken = await userCredential.user!.getIdToken();

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/auth/verify-otp/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"firebase_token": firebaseToken}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
