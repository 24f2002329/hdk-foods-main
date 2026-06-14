import 'package:flutter/material.dart';

import '../../features/auth/screens/login_screen.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _mutedText = Color(0xFFB8B8B8);

class LoginPromptWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const LoginPromptWidget({
    super.key,
    this.icon = Icons.lock_outline_rounded,
    this.title = 'Login Required',
    this.subtitle = 'Please login to continue.',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _panel,
                shape: BoxShape.circle,
                border: Border.all(color: _brandRed.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: _brandRed, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _mutedText, fontSize: 14),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text(
                'Login / Sign Up',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _brandRed,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim banner shown at the bottom of the cart for guests.
class GuestCartBanner extends StatelessWidget {
  const GuestCartBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _panel,
      child: Row(children: [
        const Icon(Icons.info_outline, color: _mutedText, size: 16),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Login to place your order',
            style: TextStyle(color: _mutedText, fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _brandRed,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
          ),
          child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
