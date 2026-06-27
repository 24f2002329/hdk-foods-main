import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF0D0D0D);
const _panel = Color(0xFF161616);
const _stroke = Color(0xFF2A2A2A);
const _textPrimary = Colors.white;
const _textSecondary = Color(0xFF9E9E9E);

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _service = NotificationService();
  bool _loading = true;
  List<NotificationModel> _list = [];
  int _unreadCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await _service.getNotifications();
      if (mounted) {
        setState(() {
          _list = res['notifications'] as List<NotificationModel>;
          _unreadCount = res['unread_count'] as int;
          _loading = false;
          _error = null;
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

  Future<void> _markAllRead() async {
    if (_unreadCount == 0) return;
    setState(() => _loading = true);
    try {
      await _service.markAllAsRead();
      await _fetch();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _viewNotification(NotificationModel item) async {
    // Show details sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _brandRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Notification',
                        style: GoogleFonts.poppins(color: _brandRed, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, h:mm a').format(item.createdAt.toLocal()),
                      style: const TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: GoogleFonts.poppins(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  item.body,
                  style: const TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandRed,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!item.isRead) {
      try {
        await _service.markAsRead(item.id);
        _fetch(); // Refresh list to update read status and counts
      } catch (_) {}
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final difference = DateTime.now().difference(dt);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(dt.toLocal());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: Text('Notifications',
            style: GoogleFonts.poppins(color: _textPrimary, fontWeight: FontWeight.w600)),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: _brandRed, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _brandRed))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: _textSecondary, size: 48),
                      const SizedBox(height: 12),
                      Text('Error loading notifications', style: GoogleFonts.poppins(color: _textPrimary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(_error!, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _loading = true);
                          _fetch();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _brandRed),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_rounded, color: Colors.grey[700], size: 64),
                          const SizedBox(height: 16),
                          Text('All caught up!',
                              style: GoogleFonts.poppins(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text('No notifications history to display.',
                              style: TextStyle(color: _textSecondary, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: _brandRed,
                      onRefresh: _fetch,
                      child: ListView.builder(
                        itemCount: _list.length,
                        itemBuilder: (context, index) {
                          final item = _list[index];
                          return Card(
                            color: _panel,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: item.isRead ? _stroke : _brandRed.withValues(alpha: 0.3),
                                width: item.isRead ? 1 : 1.5,
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _viewNotification(item),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: item.isRead ? _stroke : _brandRed.withValues(alpha: 0.1),
                                child: Icon(
                                  item.isRead ? Icons.drafts_outlined : Icons.mark_email_unread_outlined,
                                  color: item.isRead ? _textSecondary : _brandRed,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: _textPrimary,
                                        fontSize: 13,
                                        fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (!item.isRead) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: _brandRed, shape: BoxShape.circle),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: _textSecondary, fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _formatTimeAgo(item.createdAt),
                                      style: const TextStyle(color: _textSecondary, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
