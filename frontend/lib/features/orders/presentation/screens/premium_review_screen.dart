import 'package:flutter/material.dart';
import 'package:hdk_core/hdk_core.dart';
import '../../data/repositories/order_service.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

class PremiumReviewScreen extends StatefulWidget {
  final Order order;

  const PremiumReviewScreen({super.key, required this.order});

  @override
  State<PremiumReviewScreen> createState() => _PremiumReviewScreenState();
}

class _PremiumReviewScreenState extends State<PremiumReviewScreen> {
  final OrderService _orderService = OrderService();
  bool _loading = false;

  // Overall review state
  int _overallRating = 0;
  final _overallCommentController = TextEditingController();

  // Dish review state: Map of productId -> rating (1-5)
  final Map<int, int> _dishRatings = {};
  // Dish review state: Map of productId -> comment controller
  final Map<int, TextEditingController> _dishCommentControllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize controller for each item
    for (var item in widget.order.items) {
      if (item.productId != null) {
        _dishRatings[item.productId!] = 0;
        _dishCommentControllers[item.productId!] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _overallCommentController.dispose();
    for (var controller in _dishCommentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitReviews() async {
    if (_overallRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an overall rating.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final List<Map<String, dynamic>> itemsReviews = [];
      _dishRatings.forEach((productId, rating) {
        if (rating > 0) {
          itemsReviews.add({
            'product_id': productId,
            'rating': rating,
            'comment': _dishCommentControllers[productId]?.text.trim() ?? '',
          });
        }
      });

      await _orderService.submitReview(
        orderId: widget.order.id,
        rating: _overallRating,
        comment: _overallCommentController.text.trim(),
        items: itemsReviews,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for your review! ⭐')),
        );
        Navigator.pop(
          context,
          true,
        ); // Return true indicating review was submitted
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _panel,
        title: const Text(
          'Review',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header Lottie ---
                  Center(
                    child: Column(
                      children: [
                        const LottieOr(
                          asset: 'assets/animations/star_rating.json',
                          width: 100,
                          height: 100,
                          repeat: true,
                          fallback: Icon(
                            Icons.stars_rounded,
                            color: Colors.amber,
                            size: 70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Share Your Feedback!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your review helps us improve our kitchen and service.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _mutedText, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // --- Overall Order Review ---
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall Experience 🍽️',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'How was your overall experience with the delivery and service?',
                          style: TextStyle(color: _mutedText, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (index) => GestureDetector(
                              onTap: () =>
                                  setState(() => _overallRating = index + 1),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: index < _overallRating
                                        ? Colors.amber
                                        : const Color(0xFF3A3A3A),
                                    size: 42,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _overallCommentController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Add an overall comment (optional)...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _stroke),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _stroke),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _brandRed),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Dish Ratings Subheading ---
                  const Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu_rounded,
                        color: _brandRed,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Rate Your Dishes Separately',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- Dish List ---
                  ...widget.order.items.map((item) {
                    final pId = item.productId;
                    if (pId == null) return const SizedBox.shrink();

                    final rating = _dishRatings[pId] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                'Qty: ${item.quantity}',
                                style: const TextStyle(
                                  color: _mutedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: List.generate(
                              5,
                              (index) => GestureDetector(
                                onTap: () => setState(
                                  () => _dishRatings[pId] = index + 1,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: Icon(
                                      Icons.star_rounded,
                                      color: index < rating
                                          ? Colors.amber
                                          : const Color(0xFF3A3A3A),
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _dishCommentControllers[pId],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Comment for ${item.productName} (optional)...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF555555),
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1E1E1E),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
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
                                borderSide: const BorderSide(color: _brandRed),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // --- Submit Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _overallRating == 0 ? null : _submitReviews,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF222222),
                        disabledForegroundColor: const Color(0xFF555555),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Submit Reviews',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
