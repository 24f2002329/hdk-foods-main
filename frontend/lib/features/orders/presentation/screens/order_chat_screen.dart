import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/repositories/order_repository.dart';
import 'package:hdk_core/hdk_core.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _panelAlt = Color(0xFF1A1A1A);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

class OrderChatScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;

  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final OrderRepository _orderRepository = OrderRepository.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _loadMessages(silent: true);
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final msgs = await _orderRepository.getOrderMessages(widget.orderId);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading = false;
        });
        if (!silent) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _messageController.clear();

    // Optimistically add message
    final tempMsg = {
      'message': text,
      'is_admin': false,
      'sender_name': 'You',
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(tempMsg);
    });
    _scrollToBottom();

    try {
      await _orderRepository.sendOrderMessage(widget.orderId, text);
      _loadMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
        setState(() {
          _messages.remove(tempMsg);
        });
      }
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$min $period';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chat with Kitchen',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            Text(
              'Order Support',
              style: TextStyle(
                fontSize: 12,
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: HdkPreloader())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                : _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: _mutedText,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Need help with payment or items? Send a message to the kitchen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _mutedText, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isAdmin = msg['is_admin'] == true;
                      final senderName =
                          msg['sender_name'] ?? (isAdmin ? 'Kitchen' : 'User');
                      final time = msg['created_at'] != null
                          ? _formatTime(msg['created_at'])
                          : '';

                      return Align(
                        alignment: isAdmin
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? _panel
                                : _brandRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isAdmin
                                  ? Radius.zero
                                  : const Radius.circular(16),
                              bottomRight: isAdmin
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                            ),
                            border: Border.all(
                              color: isAdmin
                                  ? _stroke
                                  : _brandRed.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isAdmin) ...[
                                Text(
                                  senderName,
                                  style: const TextStyle(
                                    color: _brandRed,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                msg['message'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  time,
                                  style: const TextStyle(
                                    color: _mutedText,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: _panel,
              border: Border(top: BorderSide(color: _stroke)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: const TextStyle(
                        color: _mutedText,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: _panelAlt,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _stroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: _brandRed.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  backgroundColor: _brandRed,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
