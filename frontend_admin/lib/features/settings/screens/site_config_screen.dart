import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/token_storage.dart';
import '../../auth/screens/login_screen.dart';
import '../../coupons/screens/coupon_management_screen.dart';
import '../../orders/screens/admin_home.dart';
import '../../orders/services/order_service.dart';
import '../../users/screens/customer_management_screen.dart';
import '../services/config_service.dart';
import 'banners_screen.dart';
import 'send_notification_screen.dart';
import 'admin_reviews_screen.dart';

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
  final _closedMsg = TextEditingController();
  final _scheduledClosedMsg = TextEditingController();
  bool _isStoreOpen = true;
  bool _showRatings = true;
  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 22, minute: 0);
  DateTime? _scheduledStart;
  DateTime? _scheduledEnd;

  @override
  void initState() {
    super.initState();
    _load();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await OrderService().getMe();
      if (mounted) setState(() => _profile = data);
    } catch (_) {}
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
    _closedMsg.dispose();
    _scheduledClosedMsg.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _svc.getConfig();
      if (mounted) {
        setState(() {
          _announcement.text = data['announcement'] ?? '';
          _closedMsg.text = data['store_closed_msg'] ?? '';
          _isStoreOpen = data['is_store_open'] ?? true;
          _showRatings = data['show_ratings'] ?? true;
          final ot = (data['store_open_time'] as String? ?? '08:00:00').split(':');
          final ct = (data['store_close_time'] as String? ?? '22:00:00').split(':');
          _openTime = TimeOfDay(hour: int.parse(ot[0]), minute: int.parse(ot[1]));
          _closeTime = TimeOfDay(hour: int.parse(ct[0]), minute: int.parse(ct[1]));
          
          _scheduledClosedMsg.text = data['scheduled_closed_msg'] ?? '';
          _scheduledStart = data['scheduled_close_start'] != null
              ? DateTime.parse(data['scheduled_close_start']).toLocal()
              : null;
          _scheduledEnd = data['scheduled_close_end'] != null
              ? DateTime.parse(data['scheduled_close_end']).toLocal()
              : null;
          
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _svc.updateConfig({
        'announcement': _announcement.text.trim(),
        'store_closed_msg': _closedMsg.text.trim(),
        'is_store_open': _isStoreOpen,
        'show_ratings': _showRatings,
        'store_open_time': '${_openTime.hour.toString().padLeft(2, '0')}:${_openTime.minute.toString().padLeft(2, '0')}:00',
        'store_close_time': '${_closeTime.hour.toString().padLeft(2, '0')}:${_closeTime.minute.toString().padLeft(2, '0')}:00',
        'scheduled_closed_msg': _scheduledClosedMsg.text.trim(),
        'scheduled_close_start': _scheduledStart?.toUtc().toIso8601String(),
        'scheduled_close_end': _scheduledEnd?.toUtc().toIso8601String(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved ✅')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? _openTime : _closeTime,
    );
    if (picked != null) setState(() => isOpen ? _openTime = picked : _closeTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Settings', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          _saving
              ? const Padding(padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _red)))
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save', style: TextStyle(color: _red, fontWeight: FontWeight.bold)),
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: Colors.grey)),
                  TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: _red))),
                ]))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Quick links
                    _sectionHeader('Quick Actions'),
                    Row(children: [
                      Expanded(
                        child: _actionCard(
                          icon: Icons.image_outlined,
                          label: 'Manage Banners',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const BannersScreen())),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionCard(
                          icon: Icons.notifications_outlined,
                          label: 'Send Notification',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const SendNotificationScreen())),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.delivery_dining_outlined,
                      label: 'Delivery Staff',
                      subtitle: 'Manage drivers & set default',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const DeliveryStaffManagementScreen())),
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
                              builder: (_) =>
                                  const CustomerManagementScreen())),
                    ),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.local_offer_outlined,
                      label: 'Coupon Management',
                      subtitle: 'Create and manage promo codes',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const CouponManagementScreen())),
                    ),
                    const SizedBox(height: 24),

                    // Store status
                    _sectionHeader('Store Status'),
                    _toggleTile('Store Open', _isStoreOpen, (v) => setState(() => _isStoreOpen = v)),
                    const SizedBox(height: 12),
                    _timeTile('Open Time', _openTime, () => _pickTime(true)),
                    const SizedBox(height: 8),
                    _timeTile('Close Time', _closeTime, () => _pickTime(false)),
                    const SizedBox(height: 12),
                    _inputField('Closed Message', _closedMsg,
                        hint: 'e.g. We\'re closed. Back at 10 AM!'),
                    const SizedBox(height: 24),

                    // Scheduled closure
                    _sectionHeader('Scheduled Kitchen Closure'),
                    Text(
                      'Set a date & time range to temporarily close the kitchen for holidays or maintenance.',
                      style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    _dateTimeTile('Closure Start Time', _scheduledStart, () async {
                      final picked = await _pickDateTime(context, _scheduledStart);
                      if (picked != null) setState(() => _scheduledStart = picked);
                    }, onClear: _scheduledStart != null ? () => setState(() => _scheduledStart = null) : null),
                    const SizedBox(height: 8),
                    _dateTimeTile('Closure End Time', _scheduledEnd, () async {
                      final picked = await _pickDateTime(context, _scheduledEnd);
                      if (picked != null) setState(() => _scheduledEnd = picked);
                    }, onClear: _scheduledEnd != null ? () => setState(() => _scheduledEnd = null) : null),
                    const SizedBox(height: 12),
                    _inputField('Scheduled Closed Message', _scheduledClosedMsg,
                        hint: 'e.g. Closed for scheduled maintenance. Back on Tuesday at 9 AM!'),
                    const SizedBox(height: 24),

                    // Announcement
                    _sectionHeader('Announcement Ribbon'),
                    _inputField('Announcement', _announcement,
                        hint: 'e.g. 🎉 Free delivery this weekend! (leave blank to hide)'),
                    const SizedBox(height: 24),

                    // Ratings & Feedback
                    _sectionHeader('Ratings & Feedback'),
                    _toggleTile('Show ratings on product cards', _showRatings,
                        (v) => setState(() => _showRatings = v)),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.rate_review_outlined,
                      label: 'Customer Reviews',
                      subtitle: 'View and monitor customer ratings & comments',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AdminReviewsScreen())),
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
                        child: Row(children: [
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
                                size: 24),
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
                                      fontSize: 15),
                                ),
                                Text(
                                  _profile?['phone_number'] ?? '',
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ADMIN',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded, color: _red),
                        label: const Text('Logout',
                            style: TextStyle(
                                color: _red, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _red),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
        child: Text(title,
            style: GoogleFonts.poppins(
                color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      );

  Widget _toggleTile(String label, bool value, ValueChanged<bool> onChanged) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _stroke),
        ),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          Switch(value: value, onChanged: onChanged, activeThumbColor: _red, activeTrackColor: _red.withValues(alpha: 0.3)),
        ]),
      );

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _stroke)),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
            Text(time.format(context), style: const TextStyle(color: _red, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            const Icon(Icons.access_time, color: Colors.grey, size: 18),
          ]),
        ),
      );

  Widget _inputField(String label, TextEditingController ctrl, {String hint = ''}) => TextFormField(
        controller: ctrl,
        maxLines: 2,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.grey),
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          filled: true, fillColor: _card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _stroke)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _stroke)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _red)),
        ),
      );

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _stroke),
          ),
          child: subtitle != null
              ? Row(children: [
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text(subtitle,
                          style: GoogleFonts.poppins(
                              color: Colors.grey, fontSize: 11)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: _red, size: 28),
                  const SizedBox(height: 8),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
        ),
      );

  Widget _dateTimeTile(String label, DateTime? value, VoidCallback onTap, {VoidCallback? onClear}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _stroke)),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  value != null 
                      ? DateFormat('MMM d, yyyy - h:mm a').format(value) 
                      : 'Not Scheduled',
                  style: TextStyle(
                    color: value != null ? _red : Colors.grey[600], 
                    fontWeight: value != null ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
              onPressed: onClear,
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month, color: _red, size: 20),
            onPressed: onTap,
          ),
        ]),
      );

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;
    
    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return null;
    
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
