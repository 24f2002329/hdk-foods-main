import 'package:flutter/material.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../auth/data/repositories/auth_service.dart';
import '../../../auth/presentation/screens/login_screen.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class DeliveryProfileScreen extends StatefulWidget {
  const DeliveryProfileScreen({super.key});

  @override
  State<DeliveryProfileScreen> createState() => _DeliveryProfileScreenState();
}

class _DeliveryProfileScreenState extends State<DeliveryProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await AuthService().me();
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TokenStorage.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'delivery':
        return 'Delivery';
      default:
        return role ?? '—';
    }
  }

  Widget _infoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: _red, size: 16),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: _red, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: _red),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header Profile Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _stroke),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user?['name'] ?? 'Delivery Partner',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _user?['phone_number'] ?? '',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _roleLabel(_user?['role']),
                                style: const TextStyle(
                                  color: _red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Vehicle & Legal section
                _sectionHeader('Vehicle & Driver Details', Icons.two_wheeler),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _stroke),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Vehicle Model', 'Hero Splendor Plus',
                          icon: Icons.motorcycle_rounded),
                      _infoRow('Plate Number', 'MH-12-XY-4321',
                          icon: Icons.pin_rounded),
                      _infoRow('License No', 'DL-202493021948',
                          icon: Icons.badge_rounded),
                      _infoRow('Insurance status', 'Active (Dec 2026)',
                          icon: Icons.verified_user_rounded),
                    ],
                  ),
                ),

                // Bank details / Payout section
                _sectionHeader('Bank Payout Details', Icons.account_balance),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _stroke),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Bank Name', 'State Bank of India',
                          icon: Icons.account_balance_rounded),
                      _infoRow('Account Number', '•••• •••• 5678',
                          icon: Icons.numbers_rounded),
                      _infoRow('IFSC Code', 'SBIN0004321',
                          icon: Icons.code_rounded),
                      _infoRow('Salary UPI ID', 'devendra@okaxis',
                          icon: Icons.alternate_email_rounded),
                    ],
                  ),
                ),

                // Emergency Contacts
                _sectionHeader('Emergency Contacts', Icons.contact_phone),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _stroke),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Contact Name', 'Sunita (Wife)',
                          icon: Icons.person_outline_rounded),
                      _infoRow('Phone Number', '+91 98234 56789',
                          icon: Icons.phone_android_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
