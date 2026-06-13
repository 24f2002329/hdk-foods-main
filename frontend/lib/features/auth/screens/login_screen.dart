import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../services/auth_service.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();

  final otpController = TextEditingController();

  final authService = AuthService();

  String? verificationId;

  bool otpSent = false;
  bool loading = false;

  Future<void> sendOtp() async {
    setState(() {
      loading = true;
    });

    final success = await authService.sendOtp(
      phoneNumber: "+91${phoneController.text.trim()}",
      onCodeSent: (id) {
        verificationId = id;
      },
    );

    setState(() {
      loading = false;
      otpSent = success;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("OTP Sent")));
    }
  }

  Future<void> verifyOtp() async {
    if (verificationId == null) {
      return;
    }

    setState(() {
      loading = true;
    });

    final result = await authService.verifyOtp(
      verificationId: verificationId!,
      otp: otpController.text.trim(),
    );

    setState(() {
      loading = false;
    });

    if (result == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login Failed")));

      return;
    }

    await TokenStorage.saveTokens(
      access: result["access"],
      refresh: result["refresh"],
    );

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, "/home");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            const _LoginBrand(),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _stroke),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome Back!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Login to continue",
                    style: TextStyle(
                      color: _mutedText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_rounded, color: _brandRed),
                prefixText: "+91  ",
                prefixStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                labelText: "Mobile number",
                filled: true,
                fillColor: _panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _brandRed),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: loading ? null : sendOtp,
              style: FilledButton.styleFrom(
                backgroundColor: _brandRed,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: loading && !otpSent
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Continue",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
            if (otpSent) ...[
              const SizedBox(height: 26),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_rounded, color: _brandRed),
                  labelText: "OTP",
                  filled: true,
                  fillColor: _panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _stroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _brandRed),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: loading ? null : verifyOtp,
                style: FilledButton.styleFrom(
                  backgroundColor: _brandRed,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Verify OTP",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ],
            const SizedBox(height: 30),
            const Divider(color: _stroke),
            const SizedBox(height: 18),
            TextButton(
              onPressed: loading
                  ? null
                  : () {
                      Navigator.pushReplacementNamed(context, "/home");
                    },
              child: const Text(
                "Skip for now",
                style: TextStyle(
                  color: _mutedText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 62,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _brandRed,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _brandRed.withValues(alpha: 0.24),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Text(
            "HDK",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "HDK FOODS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Fresh. Fast. Homemade.",
              style: TextStyle(
                color: _mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
