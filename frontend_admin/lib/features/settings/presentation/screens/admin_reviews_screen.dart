import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:hdk_core/hdk_core.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);
const _textPrimary = Colors.white;
const _textSecondary = Colors.grey;

class AdminReviewModel {
  final int id;
  final int orderId;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final int rating;
  final String comment;
  final DateTime createdAt;

  AdminReviewModel({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory AdminReviewModel.fromJson(Map<String, dynamic> json) {
    return AdminReviewModel(
      id: json['id'],
      orderId: json['order'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      customerName: json['customer_name'] ?? 'Guest Customer',
      customerPhone: json['customer_phone'] ?? '',
      rating: json['rating'] ?? 5,
      comment: json['comment'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final _scrollController = ScrollController();
  List<AdminReviewModel> _reviews = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _reviews.clear();
      _page = 1;
      _hasMore = true;
      _loading = true;
      _error = null;
    });

    try {
      final res = await _loadPage(1);
      final list = (res['results'] as List)
          .map((e) => AdminReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _reviews = list;
          _hasMore = res['next'] != null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final nextPage = _page + 1;
      final res = await _loadPage(nextPage);
      final list = (res['results'] as List)
          .map((e) => AdminReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _reviews.addAll(list);
          _page = nextPage;
          _hasMore = res['next'] != null;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<Map<String, dynamic>> _loadPage(int page) async {
    final url = '${ApiConfig.baseUrl}/orders/admin/reviews/?page=$page';
    final response = await ApiClient().get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load reviews');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: Text(
          'Customer Reviews',
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
          : _error != null
          ? ErrorRetryWidget(error: _error!, onRetry: _fetch)
          : _reviews.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    color: Colors.grey[800],
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reviews yet',
                    style: GoogleFonts.poppins(
                      color: _textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Customer reviews will appear here once submitted.',
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: _red,
              onRefresh: _fetch,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _reviews.length + (_hasMore ? 1 : 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemBuilder: (context, index) {
                  if (index == _reviews.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: HdkPreloader(width: 50, height: 50)),
                    );
                  }

                  final item = _reviews[index];
                  return Card(
                    color: _card,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: _stroke),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.customerName,
                                      style: GoogleFonts.poppins(
                                        color: _textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (item.customerPhone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item.customerPhone,
                                        style: const TextStyle(
                                          color: _textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Order #${item.orderNumber}',
                                    style: GoogleFonts.poppins(
                                      color: _red,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat(
                                      'MMM d, yyyy',
                                    ).format(item.createdAt.toLocal()),
                                    style: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: List.generate(5, (starIdx) {
                              final isFilled = starIdx < item.rating;
                              return Icon(
                                isFilled
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: isFilled
                                    ? Colors.amber
                                    : Colors.grey[800],
                                size: 18,
                              );
                            }),
                          ),
                          if (item.comment.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              item.comment,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
