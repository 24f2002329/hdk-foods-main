import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../coupons/presentation/screens/coupon_management_screen.dart';
import '../../../orders/presentation/screens/admin_home.dart';
import '../../../orders/data/repositories/order_service.dart';
import '../../../users/presentation/screens/customer_management_screen.dart';
import '../../data/repositories/config_service.dart';
import 'banners_screen.dart';
import 'send_notification_screen.dart';
import 'admin_reviews_screen.dart';
import 'store_management_screen.dart';
import 'prep_predictor_config_screen.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class SiteConfigScreen extends StatefulWidget {
  const SiteConfigScreen({super.key});

  @override
  State<SiteConfigScreen> createState() => _SiteConfigScreenState();
}

class _SiteConfigScreenState extends State<SiteConfigScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final AdminConfigService _svc = AdminConfigService();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Profile
  Map<String, dynamic>? _profile;

  // Controllers
  final _announcement = TextEditingController();
  final _merchantUpiId = TextEditingController();
  final _loyaltyCoinsPercentage = TextEditingController();
  bool _showRatings = true;

  // System Health
  bool _checkingHealth = false;
  int? _apiLatencyMs;
  String _backendHealthStatus = 'Unknown';
  String _wsStatus = 'Unknown';

  @override
  void initState() {
    super.initState();
    _load();
    _loadProfile();
    _checkHealth();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await OrderService().getMe();
      if (mounted) setState(() => _profile = data);
    } catch (_) {}
  }

  Future<void> _checkHealth() async {
    if (_checkingHealth) return;
    setState(() {
      _checkingHealth = true;
      _backendHealthStatus = 'Checking...';
      _wsStatus = 'Checking...';
    });

    // 1. Check API Latency & Backend Health
    final stopwatch = Stopwatch()..start();
    try {
      await _svc.getConfig();
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _apiLatencyMs = stopwatch.elapsedMilliseconds;
          _backendHealthStatus = 'Healthy';
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _apiLatencyMs = null;
          _backendHealthStatus = 'Unreachable';
        });
      }
    }

    // 2. Check WebSocket Status
    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null) {
        if (mounted) setState(() => _wsStatus = 'Unauthorized');
      } else {
        final uri = Uri.parse('${ApiConfig.wsBaseUrl}/ws/admin/orders/?token=$token');
        final channel = WebSocketChannel.connect(uri);
        // Wait for connection with a 3-second timeout
        await channel.ready.timeout(const Duration(seconds: 3));
        if (mounted) {
          setState(() {
            _wsStatus = 'Operational';
          });
        }
        await channel.sink.close();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _wsStatus = 'Offline';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingHealth = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await TokenStorage.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _announcement.dispose();
    _merchantUpiId.dispose();
    _loyaltyCoinsPercentage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getConfig();
      if (mounted) {
        setState(() {
          _announcement.text = data['announcement'] ?? '';
          _showRatings = data['show_ratings'] ?? true;
          _merchantUpiId.text = data['merchant_upi_id'] ?? 'hdkfoods@axisbank';
          _loyaltyCoinsPercentage.text =
              (data['loyalty_coins_percentage'] ?? 10).toString();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _svc.updateConfig({
        'announcement': _announcement.text.trim(),
        'show_ratings': _showRatings,
        'merchant_upi_id': _merchantUpiId.text.trim(),
        'loyalty_coins_percentage':
            int.tryParse(_loyaltyCoinsPercentage.text.trim()) ?? 10,
      });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settings saved ✅')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: HdkPreloader(width: 20, height: 20)),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(color: _red, fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Retry', style: TextStyle(color: _red)),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionHeader('System Health'),
                _buildSystemHealthPanel(),
                const SizedBox(height: 24),

                // Quick links
                _sectionHeader('Quick Actions'),
                Row(
                  children: [
                    Expanded(
                      child: _actionCard(
                        icon: Icons.image_outlined,
                        label: 'Manage Banners',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BannersScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionCard(
                        icon: Icons.notifications_outlined,
                        label: 'Send Notification',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SendNotificationScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _actionCard(
                  icon: Icons.delivery_dining_outlined,
                  label: 'Delivery Staff',
                  subtitle: 'Manage drivers & set default',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeliveryStaffManagementScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Users
                _sectionHeader('Users'),
                _actionCard(
                  icon: Icons.people_outline,
                  label: 'Customer Management',
                  subtitle: 'View, block & manage customers',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerManagementScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _actionCard(
                  icon: Icons.local_offer_outlined,
                  label: 'Coupon Management',
                  subtitle: 'Create and manage promo codes',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CouponManagementScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Store Management
                _sectionHeader('Store Management'),
                _actionCard(
                  icon: Icons.storefront_outlined,
                  label: 'Store Operations',
                  subtitle: 'Store hours, closures & kitchen location',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoreManagementScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _actionCard(
                  icon: Icons.timer_outlined,
                  label: 'Smart Prep Time Predictor',
                  subtitle: 'Predictive algorithm modifiers & rush hour rules',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrepPredictorConfigScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Direct UPI Payments
                _sectionHeader('Direct UPI Payments'),
                _inputField(
                  'Merchant UPI ID',
                  _merchantUpiId,
                  hint: 'e.g. hdkfoods@axisbank',
                ),
                const SizedBox(height: 24),

                // Loyalty Coins
                _sectionHeader('Loyalty Coins Configuration'),
                _inputField(
                  'Loyalty Coins Percentage (%)',
                  _loyaltyCoinsPercentage,
                  hint: 'e.g. 10',
                  maxLines: 1,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),

                // Announcement
                _sectionHeader('Announcement Ribbon'),
                _inputField(
                  'Announcement',
                  _announcement,
                  hint:
                      'e.g. 🎉 Free delivery this weekend! (leave blank to hide)',
                ),
                const SizedBox(height: 24),

                // Ratings & Feedback
                _sectionHeader('Ratings & Feedback'),
                _toggleTile(
                  'Show ratings on product cards',
                  _showRatings,
                  (v) => setState(() => _showRatings = v),
                ),
                const SizedBox(height: 10),
                _actionCard(
                  icon: Icons.rate_review_outlined,
                  label: 'Customer Reviews',
                  subtitle: 'View and monitor customer ratings & comments',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminReviewsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Profile
                _sectionHeader('Account'),
                if (_profile != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _stroke),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _red,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profile?['name'] ?? 'Admin',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                _profile?['phone_number'] ?? '',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ADMIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, color: _red),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        color: _red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _red),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: GoogleFonts.poppins(
        color: Colors.grey,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _inputField(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    int maxLines = 2,
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.grey),
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
      filled: true,
      fillColor: _card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _red),
      ),
    ),
  );

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: subtitle != null
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _red, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: _red, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _toggleTile(String label, bool value, ValueChanged<bool> onChanged) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _stroke),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _red,
              activeTrackColor: _red.withValues(alpha: 0.3),
            ),
          ],
        ),
      );

  Widget _buildSystemHealthPanel() {
    Color getStatusColor(String status) {
      switch (status) {
        case 'Healthy':
        case 'Operational':
          return Colors.greenAccent;
        case 'Checking...':
          return Colors.amberAccent;
        case 'Unknown':
          return Colors.grey;
        default:
          return Colors.redAccent;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: _red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'System Health Monitor',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (_checkingHealth)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_red),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.grey, size: 18),
                  onPressed: _checkHealth,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _healthRow(
            label: 'Backend API Status',
            status: _backendHealthStatus,
            statusColor: getStatusColor(_backendHealthStatus),
            trailing: _apiLatencyMs != null ? '${_apiLatencyMs}ms' : null,
          ),
          const Divider(color: _stroke, height: 16),
          _healthRow(
            label: 'WebSocket Gateway',
            status: _wsStatus,
            statusColor: getStatusColor(_wsStatus),
          ),
        ],
      ),
    );
  }

  Widget _healthRow({
    required String label,
    required String status,
    required Color statusColor,
    String? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        Row(
          children: [
            if (trailing != null) ...[
              Text(
                trailing,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
