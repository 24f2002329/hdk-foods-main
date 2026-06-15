import 'package:flutter/material.dart';
import 'package:smart_auth/smart_auth.dart';

import '../services/auth_service.dart';
import 'otp_screen.dart';

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
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _authService = AuthService();
  final _smartAuth = SmartAuth.instance;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() {
      if (_phoneFocus.hasFocus && _phoneController.text.isEmpty) {
        _fillPhoneFromGoogle();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _fillPhoneFromGoogle() async {
    try {
      final result = await _smartAuth.requestPhoneNumberHint();
      if (result.hasData) {
        final digits = result.requireData.replaceAll(RegExp(r'\D'), '');
        _phoneController.text =
            digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
      }
    } catch (_) {}
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid 10-digit mobile number")),
      );
      return;
    }

    setState(() => _loading = true);

    final verificationId = await _authService.sendOtp(
      phoneNumber: "+91$phone",
    );

    setState(() => _loading = false);
    if (!mounted) return;

    if (verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send OTP. Please try again.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          verificationId: verificationId,
          phoneNumber: phone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large centered logo with red glow
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _brandRed.withValues(alpha: 0.35),
                        blurRadius: 56,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/hdk-logo.png',
                      width: 130,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "HDK FOODS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  "Fresh. Fast. Homemade.",
                  style: TextStyle(
                    color: _mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              // Heading
              const Text(
                "Login / Sign Up",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Enter your mobile number to continue",
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              // Phone field — Google hint fires automatically on focus
              TextField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon:
                      const Icon(Icons.phone_rounded, color: _brandRed),
                  prefixText: "+91  ",
                  prefixStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  labelText: "Mobile number",
                  labelStyle: const TextStyle(color: _mutedText),
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
                    borderSide: const BorderSide(color: _brandRed, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Continue button
              FilledButton(
                onPressed: _loading ? null : _sendOtp,
                style: FilledButton.styleFrom(
                  backgroundColor: _brandRed,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor: _brandRed.withValues(alpha: 0.4),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Continue",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(height: 36),
              Row(
                children: [
                  const Expanded(child: Divider(color: _stroke)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "or",
                      style: TextStyle(
                        color: _mutedText.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: _stroke)),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.pushReplacementNamed(context, "/home"),
                  child: const Text(
                    "Skip for now",
                    style: TextStyle(
                      color: _mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
