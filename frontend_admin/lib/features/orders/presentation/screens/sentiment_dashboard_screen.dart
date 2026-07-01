import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:hdk_core/hdk_core.dart';
import '../models/review.dart';
import '../services/order_service.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class SentimentDashboardScreen extends StatefulWidget {
  final bool isEmbedded;
  const SentimentDashboardScreen({super.key, this.isEmbedded = false});

  @override
  State<SentimentDashboardScreen> createState() => _SentimentDashboardScreenState();
}

class _SentimentDashboardScreenState extends State<SentimentDashboardScreen> {
  final OrderService _orderSvc = OrderService();

  List<OrderReviewModel> _orderReviews = [];
  List<ProductReviewModel> _productReviews = [];
  bool _loading = true;
  String? _error;

  // Search & Filters
  String _searchQuery = '';
  int _selectedRatingFilter = 0; // 0 = All, 1-5 = specific star rating
  bool _showDishReviews = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ordersReviews = await _orderSvc.getOrderReviews();
      final productsReviews = await _orderSvc.getProductReviews();

      setState(() {
        _orderReviews = ordersReviews;
        _productReviews = productsReviews;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Issue Coupon Dialog
  void _showIssueCouponDialog(String customerName, int customerId) {
    final codeController = TextEditingController(text: 'SORRY${math.Random().nextInt(900) + 100}');
    final amountController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: _card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _stroke),
              ),
              title: Text(
                'Issue Coupon to $customerName',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Promo Code',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _stroke)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Discount Amount (₹)',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _stroke)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _red),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    try {
                      final discount = double.tryParse(amountController.text) ?? 100.0;
                      // Register this coupon on the backend
                      await _orderSvc.createCoupon({
                        'code': codeController.text,
                        'discount_type': 'flat',
                        'discount_value': discount.toString(),
                        'min_order_amount': '300.00',
                        'max_discount_amount': discount.toString(),
                        'is_active': true,
                        'valid_from': DateTime.now().toIso8601String(),
                        'valid_until': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                        'usage_limit': 1,
                      });

                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Coupon ${codeController.text} successfully issued to $customerName!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: _red),
                      );
                    }
                  },
                  child: const Text('Issue Coupon'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Consecutive alerts calculation
  List<String> _getConsecutiveLowRatingAlerts() {
    final alerts = <String>[];
    final Map<String, List<int>> dishRatings = {};

    // Group ratings by dish name ordered by date oldest to newest
    final sortedReviews = List<ProductReviewModel>.from(_productReviews)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (var r in sortedReviews) {
      dishRatings.putIfAbsent(r.productName, () => []).add(r.rating);
    }

    dishRatings.forEach((dish, ratings) {
      int consecutiveLow = 0;
      for (var rating in ratings) {
        if (rating <= 2) {
          consecutiveLow++;
          if (consecutiveLow >= 3) {
            alerts.add('🚨 Critical: "$dish" has received 3 consecutive low ratings ($rating★). Check recipe!');
            break;
          }
        } else {
          consecutiveLow = 0;
        }
      }
    });

    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      if (widget.isEmbedded) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: HdkPreloader(),
          ),
        );
      }
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: HdkPreloader()),
      );
    }

    if (_error != null) {
      if (widget.isEmbedded) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: ErrorRetryWidget(error: _error!, onRetry: _loadData),
          ),
        );
      }
      return Scaffold(
        backgroundColor: _surface,
        body: ErrorRetryWidget(error: _error!, onRetry: _loadData),
      );
    }

    final isNarrow = MediaQuery.of(context).size.width < 600;

    // Filter reviews
    final filteredDishReviews = _productReviews.where((r) {
      final matchesSearch = r.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.comment.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRating = _selectedRatingFilter == 0 || r.rating == _selectedRatingFilter;
      return matchesSearch && matchesRating;
    }).toList();

    final filteredOrderReviews = _orderReviews.where((r) {
      final matchesSearch = r.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.comment.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRating = _selectedRatingFilter == 0 || r.rating == _selectedRatingFilter;
      return matchesSearch && matchesRating;
    }).toList();

    // Summary calculations
    final avgRating = _productReviews.isEmpty
        ? 0.0
        : _productReviews.map((r) => r.rating).reduce((a, b) => a + b) / _productReviews.length;

    final positiveCount = _productReviews.where((r) => r.rating >= 4).length;
    final neutralCount = _productReviews.where((r) => r.rating == 3).length;
    final negativeCount = _productReviews.where((r) => r.rating <= 2).length;

    final positivePct = _productReviews.isEmpty ? 0 : (positiveCount / _productReviews.length * 100).round();
    final neutralPct = _productReviews.isEmpty ? 0 : (neutralCount / _productReviews.length * 100).round();
    final negativePct = _productReviews.isEmpty ? 0 : (negativeCount / _productReviews.length * 100).round();

    final alerts = _getConsecutiveLowRatingAlerts();

    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        if (!widget.isEmbedded) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Sentiment Analytics',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monitor customer satisfaction trends and culinary quality signals',
                      style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.grey),
                onPressed: _loadData,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ] else ...[
          // Header / Title for Embedded Dashboard Section
          Text(
            'Review Sentiment Analytics',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 16),
        ],

            // Consecutive alerts panel
            if (alerts.isNotEmpty) ...[
              ...alerts.map((alert) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.15),
                      border: Border.all(color: _red),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: _red, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            alert,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            // Top Stats Grid (responsive 2x2 on phone, 4-col on tablet)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                if (isNarrow) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          _buildStatCard('Avg Rating', '${avgRating.toStringAsFixed(1)} ★', Icons.star, Colors.amber),
                          const SizedBox(width: 12),
                          _buildStatCard('Total Reviews', '${_productReviews.length}', Icons.rate_review, Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatCard('Positive', '$positivePct%', Icons.sentiment_satisfied, Colors.green),
                          const SizedBox(width: 12),
                          _buildStatCard('Action Req.', '$negativeCount', Icons.assignment_late, _red),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    _buildStatCard('Average Rating', '${avgRating.toStringAsFixed(1)} ★', Icons.star, Colors.amber),
                    const SizedBox(width: 16),
                    _buildStatCard('Total Reviews', '${_productReviews.length}', Icons.rate_review, Colors.blue),
                    const SizedBox(width: 16),
                    _buildStatCard('Positive Sentiment', '$positivePct%', Icons.sentiment_satisfied, Colors.green),
                    const SizedBox(width: 16),
                    _buildStatCard('Action Required', '$negativeCount', Icons.assignment_late, _red),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Charts Section
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;

                final lineChart = Container(
                  height: 280,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _card,
                    border: Border.all(color: _stroke),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rating Trend (Last 7 Days)',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      Expanded(child: _buildTrendLineChart()),
                    ],
                  ),
                );

                final donutChart = Container(
                  height: 280,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _card,
                    border: Border.all(color: _stroke),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sentiment Breakout',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 50,
                            sections: [
                              PieChartSectionData(
                                color: Colors.green,
                                value: positivePct.toDouble(),
                                title: '$positivePct%',
                                radius: 20,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              PieChartSectionData(
                                color: Colors.amber,
                                value: neutralPct.toDouble(),
                                title: '$neutralPct%',
                                radius: 20,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              PieChartSectionData(
                                color: _red,
                                value: negativePct.toDouble(),
                                title: '$negativePct%',
                                radius: 20,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _buildLegendItem('Positive', Colors.green),
                          _buildLegendItem('Neutral', Colors.amber),
                          _buildLegendItem('Negative', _red),
                        ],
                      ),
                    ],
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      lineChart,
                      const SizedBox(height: 16),
                      donutChart,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: lineChart),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: donutChart),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Dish Review Feed & Filter Controls
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _card,
                border: Border.all(color: _stroke),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Filters
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tab Buttons Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _showDishReviews = true),
                            child: Text(
                              'Dish Feedback (${filteredDishReviews.length})',
                              style: GoogleFonts.poppins(
                                color: _showDishReviews ? _red : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: isNarrow ? 14 : 16,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _showDishReviews = false),
                            child: Text(
                              'Order Feedback (${filteredOrderReviews.length})',
                              style: GoogleFonts.poppins(
                                color: !_showDishReviews ? _red : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: isNarrow ? 14 : 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Search & Filter Section
                      if (isNarrow)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 40,
                              child: TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: _showDishReviews
                                      ? 'Search dish name, comments...'
                                      : 'Search order ID, comments...',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                  prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: _stroke),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: _red),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: _stroke),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedRatingFilter,
                                  dropdownColor: _card,
                                  style: const TextStyle(color: Colors.white),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 0, child: Text('All Ratings')),
                                    DropdownMenuItem(value: 5, child: Text('5 ★')),
                                    DropdownMenuItem(value: 4, child: Text('4 ★')),
                                    DropdownMenuItem(value: 3, child: Text('3 ★')),
                                    DropdownMenuItem(value: 2, child: Text('2 ★')),
                                    DropdownMenuItem(value: 1, child: Text('1 ★')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedRatingFilter = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            // Search Bar
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: TextField(
                                  onChanged: (v) => setState(() => _searchQuery = v),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: _showDishReviews
                                        ? 'Search dish name, comments...'
                                        : 'Search order ID, comments...',
                                    hintStyle: const TextStyle(color: Colors.grey),
                                    prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: _stroke),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: _red),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Star Rating filter dropdown
                            Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: _stroke),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedRatingFilter,
                                  dropdownColor: _card,
                                  style: const TextStyle(color: Colors.white),
                                  items: const [
                                    DropdownMenuItem(value: 0, child: Text('All Ratings')),
                                    DropdownMenuItem(value: 5, child: Text('5 ★')),
                                    DropdownMenuItem(value: 4, child: Text('4 ★')),
                                    DropdownMenuItem(value: 3, child: Text('3 ★')),
                                    DropdownMenuItem(value: 2, child: Text('2 ★')),
                                    DropdownMenuItem(value: 1, child: Text('1 ★')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedRatingFilter = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Review list
                  if (_showDishReviews ? filteredDishReviews.isEmpty : filteredOrderReviews.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No matching feedback logs found.',
                          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _showDishReviews ? filteredDishReviews.length : filteredOrderReviews.length,
                      separatorBuilder: (ctx, idx) => const Divider(color: _stroke),
                      itemBuilder: (context, index) {
                        final rating = _showDishReviews ? filteredDishReviews[index].rating : filteredOrderReviews[index].rating;
                        final comment = _showDishReviews ? filteredDishReviews[index].comment : filteredOrderReviews[index].comment;
                        final customerName = _showDishReviews ? filteredDishReviews[index].customerName : filteredOrderReviews[index].customerName;
                        final customerPhone = _showDishReviews ? filteredDishReviews[index].customerPhone : filteredOrderReviews[index].customerPhone;
                        final customerId = _showDishReviews ? filteredDishReviews[index].customerId : filteredOrderReviews[index].customerId;
                        final orderNumber = _showDishReviews ? filteredDishReviews[index].orderNumber : filteredOrderReviews[index].orderNumber;
                        final createdAt = _showDishReviews ? filteredDishReviews[index].createdAt : filteredOrderReviews[index].createdAt;
                        final titleText = _showDishReviews ? filteredDishReviews[index].productName : 'Order Review';

                        final isAlert = rating <= 2;

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: isNarrow
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: isAlert ? _red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                                          radius: 20,
                                          child: Icon(
                                            isAlert ? Icons.warning_amber_rounded : Icons.thumb_up_alt_outlined,
                                            color: isAlert ? _red : Colors.green,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      titleText,
                                                      style: GoogleFonts.poppins(
                                                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      'Order #$orderNumber',
                                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (starIndex) => Icon(
                                                    Icons.star,
                                                    size: 12,
                                                    color: starIndex < rating ? Colors.amber : Colors.grey.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      comment.isEmpty ? 'No comment text provided' : comment,
                                      style: TextStyle(
                                          color: comment.isEmpty ? Colors.grey.shade600 : Colors.white70,
                                          fontSize: 13,
                                          fontStyle: comment.isEmpty ? FontStyle.italic : FontStyle.normal),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Submitted by: $customerName ($customerPhone) on ${DateFormat('MMM dd, yyyy HH:mm').format(createdAt)}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                    if (isAlert) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: _red),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.card_giftcard, color: _red, size: 14),
                                            label: const Text('Issue Coupon', style: TextStyle(color: _red, fontSize: 11)),
                                            onPressed: () => _showIssueCouponDialog(customerName, customerId),
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.grey.shade900,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                side: const BorderSide(color: _stroke),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.phone, color: Colors.white, size: 14),
                                            label: const Text('Contact', style: TextStyle(color: Colors.white, fontSize: 11)),
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Opening chat with phone: $customerPhone')),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Avatar/Status Badge
                                    CircleAvatar(
                                      backgroundColor: isAlert ? _red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                                      radius: 22,
                                      child: Icon(
                                        isAlert ? Icons.warning_amber_rounded : Icons.thumb_up_alt_outlined,
                                        color: isAlert ? _red : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Review Main Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  titleText,
                                                  style: GoogleFonts.poppins(
                                                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Flexible(
                                                child: Text(
                                                  'Order #$orderNumber',
                                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: List.generate(
                                              5,
                                              (starIndex) => Icon(
                                                Icons.star,
                                                size: 14,
                                                color: starIndex < rating ? Colors.amber : Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            comment.isEmpty ? 'No comment text provided' : comment,
                                            style: TextStyle(
                                                color: comment.isEmpty ? Colors.grey.shade600 : Colors.white70,
                                                fontSize: 13,
                                                fontStyle: comment.isEmpty ? FontStyle.italic : FontStyle.normal),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Submitted by: $customerName ($customerPhone) on ${DateFormat('MMM dd, yyyy HH:mm').format(createdAt)}',
                                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Actions Side
                                    if (isAlert) ...[
                                      const SizedBox(width: 16),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: _red),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.card_giftcard, color: _red, size: 16),
                                            label: const Text('Issue Coupon', style: TextStyle(color: _red, fontSize: 12)),
                                            onPressed: () => _showIssueCouponDialog(customerName, customerId),
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.grey.shade900,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                side: const BorderSide(color: _stroke),
                                              ),
                                            ),
                                            icon: const Icon(Icons.phone, color: Colors.white, size: 16),
                                            label: const Text('Contact', style: TextStyle(color: Colors.white, fontSize: 12)),
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Opening chat with phone: $customerPhone')),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                        );
                      },
                    ),
                ],
              ),
            ),
        ],
      );

      if (widget.isEmbedded) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: mainContent,
        );
      }

      return Scaffold(
        backgroundColor: _surface,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: mainContent,
        ),
      );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          border: Border.all(color: _stroke),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  // fl_chart Trend line builder
  Widget _buildTrendLineChart() {
    if (_productReviews.isEmpty) {
      return const Center(child: Text('No data for trend chart', style: TextStyle(color: Colors.grey)));
    }

    // Group ratings by date for the last 7 days
    final Map<String, List<int>> dailyRatings = {};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final dateStr = DateFormat('MM/dd').format(now.subtract(Duration(days: i)));
      dailyRatings[dateStr] = [];
    }

    for (var r in _productReviews) {
      final dateStr = DateFormat('MM/dd').format(r.createdAt);
      if (dailyRatings.containsKey(dateStr)) {
        dailyRatings[dateStr]!.add(r.rating);
      }
    }

    final List<FlSpot> spots = [];
    final List<String> dates = dailyRatings.keys.toList();
    for (int i = 0; i < dates.length; i++) {
      final ratings = dailyRatings[dates[i]]!;
      final avg = ratings.isEmpty ? 4.0 : ratings.reduce((a, b) => a + b) / ratings.length;
      spots.add(FlSpot(i.toDouble(), avg));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => const FlLine(color: _stroke, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1.0,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}★',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
              reservedSize: 28,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < dates.length) {
                  return Text(dates[index], style: const TextStyle(color: Colors.grey, fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 1,
        maxY: 5,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _red,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: _red.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
