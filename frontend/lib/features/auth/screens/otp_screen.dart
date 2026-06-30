import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smart_auth/smart_auth.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../accounts/services/user_service.dart';
import '../screens/name_collection_screen.dart';
import '../services/auth_service.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _authService = AuthService();
  final _smartAuth = SmartAuth.instance;

  late String _verificationId;
  bool _loading = false;
  int _resendSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _otpController.addListener(() => setState(() {}));
    _startResendTimer();
    _listenForOtpSms();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    _smartAuth.removeUserConsentApiListener();
    super.dispose();
  }

  // ── OTP auto-read ──────────────────────────────────────────────────────────
  // Run both APIs simultaneously: getSmsWithRetrieverApi (silent, needs app
  // hash in SMS — works when SHA-1 is registered in Firebase) and
  // getSmsWithUserConsentApi (shows a one-tap system prompt, works without
  // hash). Whichever delivers a code first wins.
  void _listenForOtpSms() {
    _trySmsRetriever();
    _trySmsUserConsent();
  }

  Future<void> _trySmsRetriever() async {
    try {
      final res = await _smartAuth.getSmsWithRetrieverApi();
      _handleSmsResult(res);
    } catch (_) {}
  }

  Future<void> _trySmsUserConsent() async {
    try {
      final res = await _smartAuth.getSmsWithUserConsentApi();
      _handleSmsResult(res);
    } catch (_) {}
  }

  void _handleSmsResult(SmartAuthResult<SmartAuthSms> res) {
    if (!mounted) return;
    // Ignore if the user already typed the OTP manually.
    if (_otpController.text.length == 6) return;
    if (!res.hasData) return;
    final sms = res.requireData;
    // Use the code extracted by smart_auth's built-in regex (\d{4,8}).
    // Fall back to a strict 6-digit word-boundary search on the raw SMS text.
    final code = sms.code ?? _extractSixDigits(sms.sms);
    if (code != null && code.length == 6) {
      _otpController.text = code;
      _verifyOtp();
    }
  }

  String? _extractSixDigits(String sms) {
    // Match exactly 6 consecutive digits, not adjacent to other digits.
    return RegExp(r'(?<!\d)(\d{6})(?!\d)').firstMatch(sms)?.group(1);
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _resendOtp() async {
    setState(() => _loading = true);
    final verificationId = await _authService.sendOtp(
      phoneNumber: "+91${widget.phoneNumber}",
    );
    setState(() => _loading = false);
    if (!mounted) return;

    if (verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to resend OTP. Try again.")),
      );
      return;
    }

    _verificationId = verificationId;
    _otpController.clear();
    _startResendTimer();
    _listenForOtpSms();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("OTP resent successfully")),
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) return;

    setState(() => _loading = true);

    final result = await _authService.verifyOtp(
      verificationId: _verificationId,
      otp: _otpController.text.trim(),
    );

    setState(() => _loading = false);
    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid OTP. Please try again.")),
      );
      _otpController.clear();
      return;
    }

    await TokenStorage.saveTokens(
      access: result["access"],
      refresh: result["refresh"],
    );

    if (!mounted) return;

    try {
      final user = await UserService().getCurrentUser();
      if (!mounted) return;
      if (user.name.trim().isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NameCollectionScreen()),
        );
        return;
      }
    } catch (_) {}

    Navigator.pushReplacementNamed(context, "/home");
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = !_loading && _otpController.text.length == 6;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter OTP",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: _mutedText, fontSize: 14),
                  children: [
                    const TextSpan(text: "Code sent to "),
                    TextSpan(
                      text: "+91 ${widget.phoneNumber}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              _PinInput(
                controller: _otpController,
                onCompleted: _verifyOtp,
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: canVerify ? _verifyOtp : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _brandRed,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor: _brandRed.withValues(alpha: 0.35),
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
                        "Verify OTP",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        "Resend OTP in ${_resendSeconds}s",
                        style: const TextStyle(color: _mutedText, fontSize: 14),
                      )
                    : TextButton(
                        onPressed: _loading ? null : _resendOtp,
                        child: const Text(
                          "Resend OTP",
                          style: TextStyle(
                            color: _brandRed,
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

class _PinInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onCompleted;

  const _PinInput({required this.controller, required this.onCompleted});

  @override
  State<_PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<_PinInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;

    return GestureDetector(
      onTap: _focusNode.requestFocus,
      child: SizedBox(
        height: 62,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Visible digit boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = text.length > i;
                final isCurrent = _focusNode.hasFocus && text.length == i;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 46,
                  height: 58,
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? _brandRed
                          : (filled
                              ? _brandRed.withValues(alpha: 0.45)
                              : _stroke),
                      width: isCurrent ? 2.0 : 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: filled
                      ? Text(
                          text[i],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                );
              }),
            ),
            // Invisible TextField that captures input
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    setState(() {});
                    if (v.length == 6) widget.onCompleted();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
