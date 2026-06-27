import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../shared/widgets/login_prompt_widget.dart';
import '../../accounts/models/user.dart';
import '../../accounts/services/user_service.dart';
import '../../orders/screens/orders_screen.dart';
import '../../address/screens/address_screen.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

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
      setState(() {
        _isLoggedIn = false;
        _loading = false;
      });
      return;
    }
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _userService.getCurrentUser();
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _logout() async {
    await TokenStorage.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _user?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Edit Name',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Full name',
            labelStyle: TextStyle(color: _mutedText),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(color: _brandRed)),
          ),
        ],
      ),
    );
    // Defer dispose until after the dialog's closing animation has finished
    // (one post-frame is enough). Calling dispose() synchronously here lets
    // the still-animating TextField rebuild with an already-disposed controller
    // which triggers "_dependents.isEmpty" assertion failures.
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result == null || result.isEmpty || result == _user?.name) return;
    try {
      final updated = await _userService.updateName(result);
      if (mounted) setState(() => _user = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Help & Support',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Reach us any time',
                  style: TextStyle(color: _mutedText, fontSize: 13)),
              const SizedBox(height: 20),
              _HelpTile(
                icon: Icons.call_rounded,
                color: Colors.greenAccent,
                label: 'Call Us',
                subtitle: '+91 98765 43210',
                onTap: () => launchUrl(Uri.parse('tel:+919876543210')),
              ),
              const SizedBox(height: 12),
              _HelpTile(
                icon: Icons.chat_rounded,
                color: const Color(0xFF25D366),
                label: 'WhatsApp',
                subtitle: 'Chat with support',
                onTap: () => launchUrl(Uri.parse('https://wa.me/919876543210')),
              ),
              const SizedBox(height: 12),
              _HelpTile(
                icon: Icons.mail_outline_rounded,
                color: Colors.blueAccent,
                label: 'Email',
                subtitle: 'support@hdkfoods.com',
                onTap: () =>
                    launchUrl(Uri.parse('mailto:support@hdkfoods.com')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: Colors.white,
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _brandRed))
          : !_isLoggedIn
              ? const LoginPromptWidget(
                  icon: Icons.person_outline_rounded,
                  title: 'Your Profile',
                  subtitle:
                      'Login to view your profile, orders, and saved addresses.',
                )
              : _error != null
                  ? ErrorRetryWidget(error: _error!, onRetry: _loadUser)
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // ── Avatar + name ─────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _panel,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _stroke),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _brandRed,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    (_user?.name.isNotEmpty == true)
                                        ? _user!.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _user?.name.isNotEmpty == true
                                          ? _user!.name
                                          : 'Set your name',
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
                                        color: _mutedText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _editName,
                                icon: const Icon(Icons.edit_rounded,
                                    color: _mutedText, size: 20),
                                tooltip: 'Edit name',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Navigation tiles ───────────────────────────────
                        _ProfileTile(
                          icon: Icons.receipt_long_rounded,
                          label: 'My Orders',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const OrdersScreen()),
                          ),
                        ),
                        _ProfileTile(
                          icon: Icons.location_on_rounded,
                          label: 'Saved Addresses',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddressScreen()),
                          ),
                        ),
                        _ProfileTile(
                          icon: Icons.help_outline_rounded,
                          label: 'Help & Support',
                          onTap: _showHelp,
                        ),
                        const SizedBox(height: 20),

                        // ── Logout ─────────────────────────────────────────
                        OutlinedButton.icon(
                          onPressed: _logout,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: _brandRed),
                            foregroundColor: _brandRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Logout',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: _brandRed),
          title: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: _mutedText),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _stroke),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: const TextStyle(color: _mutedText, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _mutedText),
          ]),
        ),
      ),
    );
  }
}
