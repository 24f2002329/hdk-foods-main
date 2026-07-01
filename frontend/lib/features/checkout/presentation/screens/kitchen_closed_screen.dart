import 'package:flutter/material.dart';

class KitchenClosedScreen extends StatelessWidget {
  final String closedMessage;
  final String? openTime;
  final String? closeTime;

  const KitchenClosedScreen({
    super.key,
    required this.closedMessage,
    this.openTime,
    this.closeTime,
  });

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFFFF1E1E);
    const surface = Color(0xFF050505);
    const panel = Color(0xFF111111);
    const stroke = Color(0xFF2A2A2A);

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Icon container with custom styled background
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: brandRed.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: brandRed.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.storefront_outlined,
                      color: brandRed,
                      size: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Kitchen is Closed",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  closedMessage.isNotEmpty 
                      ? closedMessage 
                      : "We are currently closed. We'll be happy to serve you during our business hours!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: stroke),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.schedule_outlined, color: brandRed, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Kitchen Operating Hours",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (openTime != null && closeTime != null)
                          ? "$openTime - $closeTime (IST)"
                          : "08:00 AM - 10:00 PM (IST)",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  // Go back to the main menu/home screen
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  "Back to Menu",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
