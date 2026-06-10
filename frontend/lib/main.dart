import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            "HDK Foods",
          ),
        ),
        body: const OtpScreen(),
      ),
    );
  }
}


class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final otpController = TextEditingController();

  String? verificationId;

  Future<void> sendOtp() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: "+919999999999",

      verificationCompleted: (credential) async {
        print("AUTO VERIFIED");
      },

      verificationFailed: (e) {
        print("FAILED");
        print(e.code);
        print(e.message);
      },

      codeSent: (id, token) {
        verificationId = id;

        print("OTP SENT");
        print(id);
      },

      codeAutoRetrievalTimeout: (id) {},
    );
  }

  Future<void> verifyOtp() async {
    try {
      final credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpController.text.trim(),
      );

      final userCredential =
          await FirebaseAuth.instance
              .signInWithCredential(
        credential,
      );

      final firebaseToken =
          await userCredential.user!
              .getIdToken();

      print("FIREBASE TOKEN:");
      print(firebaseToken);

      final response = await http.post(
        Uri.parse(
          "http://10.53.14.18:8000/api/auth/verify-otp/",
        ),
        headers: {
          "Content-Type":
              "application/json",
        },
        body: jsonEncode({
          "firebase_token":
              firebaseToken,
        }),
      );

      print(
        "DJANGO STATUS: ${response.statusCode}",
      );

      print(
        "DJANGO RESPONSE: ${response.body}",
      );
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.all(20),

      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          ElevatedButton(
            onPressed: sendOtp,
            child:
                const Text("Send OTP"),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: otpController,
            decoration:
                const InputDecoration(
              labelText: "OTP",
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: verifyOtp,
            child:
                const Text("Verify OTP"),
          ),
        ],
      ),
    );
  }
}