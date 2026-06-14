import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../shared/widgets/login_prompt_widget.dart';
import '../../accounts/models/user.dart';
import '../../accounts/services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  User? _user;
  bool _loading = true;
  String? _error;
  bool _isLoggedIn = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final loggedIn = await TokenStorage.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      setState(() { _isLoggedIn = false; _loading = false; });
      return;
    }
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _userService.getCurrentUser();
      if (mounted) {
        setState(() { _user = user; _loading = false; _error = null; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = e.toString(); });
      }
    }
  }

  Future<void> _logout() async {
    await TokenStorage.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        foregroundColor: Colors.white,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF1E1E)))
          : !_isLoggedIn
              ? const LoginPromptWidget(
                  icon: Icons.person_outline_rounded,
                  title: 'Your Profile',
                  subtitle: 'Login to view your profile, orders, and saved addresses.',
                )
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _loadUser)
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF1E1E),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.person_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _user?.name ?? 'User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _user?.phoneNumber ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFFB8B8B8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ProfileTile(icon: Icons.receipt_long_rounded, label: 'My Orders'),
                    _ProfileTile(
                      icon: Icons.location_on_rounded,
                      label: 'Saved Addresses',
                      onTap: () => Navigator.pushNamed(context, '/addresses'),
                    ),
                    _ProfileTile(icon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
                    _ProfileTile(icon: Icons.local_offer_rounded, label: 'Coupons'),
                    _ProfileTile(icon: Icons.help_outline_rounded, label: 'Help & Support'),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: Color(0xFFFF1E1E)),
                        foregroundColor: const Color(0xFFFF1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text(
                        'Logout',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;

  final VoidCallback? onTap;

  const _ProfileTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFFFF1E1E)),
          title: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFB8B8B8)),
          onTap: onTap,
        ),
      ),
    );
  }
}