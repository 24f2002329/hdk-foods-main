import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:hdk_core/hdk_core.dart';

abstract class AuthRepository {
  static AuthRepository? _instance;
  static AuthRepository get instance => _instance ??= HttpAuthRepository();
  static set instance(AuthRepository value) => _instance = value;

  Future<String?> sendOtp({required String phoneNumber});
  Future<Map<String, dynamic>?> verifyOtp({
    required String verificationId,
    required String otp,
  });
}

class HttpAuthRepository implements AuthRepository {
  @override
  Future<String?> sendOtp({required String phoneNumber}) async {
    final completer = Completer<String?>();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verified by Firebase — codeSent will still fire, so don't
          // complete here; let codeSent handle it.
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) completer.complete(null);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
      );

      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

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
