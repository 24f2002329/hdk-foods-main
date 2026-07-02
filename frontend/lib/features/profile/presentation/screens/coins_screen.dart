import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hdk_core/hdk_core.dart';
import '../../../accounts/data/repositories/user_service.dart';
import '../../../orders/presentation/screens/order_tracking_screen.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

class CoinsScreen extends StatefulWidget {
  const CoinsScreen({super.key});

  @override
  State<CoinsScreen> createState() => _CoinsScreenState();
}

class _CoinsScreenState extends State<CoinsScreen> {
  final UserService _userService = UserService();
  int _loyaltyCoins = 0;
  List<CoinTransaction> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _userService.getCoinTransactions();
      if (mounted) {
        setState(() {
          _loyaltyCoins = res['loyalty_coins'] ?? 0;
          _transactions = List<CoinTransaction>.from(res['transactions'] ?? []);
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

  String _fmtDate(DateTime date) {
    final local = date.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h24 = local.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = h24 < 12 ? 'AM' : 'PM';
    return '${local.day} ${months[local.month - 1]} ${local.year}, $h12:$mm $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'HDK Loyalty Coins',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _loadData)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: _brandRed,
                  backgroundColor: _panel,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── Coins Total Summary Header ────────────────────────
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 28,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFF8A00).withValues(alpha: 0.22),
                                  const Color(0xFFFF1E1E).withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFFF8A00).withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8A00).withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF8A00).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFF8A00),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF8A00).withValues(alpha: 0.2),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.stars_rounded,
                                    color: Color(0xFFFF8A00),
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'YOUR COIN BALANCE',
                                  style: TextStyle(
                                    color: _mutedText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                  Text(
                                    '$_loyaltyCoins',
                                    style: const TextStyle(
                                      color: Color(0xFFFF8A00),
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  '1 Coin = ₹1. Use loyalty coins to get discounts on checkout.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _mutedText.withValues(alpha: 0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Transactions Section Title ────────────────────────
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: const [
                              Icon(Icons.history_rounded, color: _brandRed, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Transaction History',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      // ── Transactions List ────────────────────────
                      _transactions.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_rounded,
                                        size: 64,
                                        color: _mutedText.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No Transactions Yet',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Coins earned and redeemed on your orders will show up here.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _mutedText.withValues(alpha: 0.6),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final tx = _transactions[index];
                                    final isPositive = tx.amount > 0;
                                    final displayAmount = '${isPositive ? '+' : ''}${tx.amount}';
                                    
                                    IconData iconData;
                                    Color iconColor;
                                    Color amountColor;

                                    if (tx.type == 'earned') {
                                      iconData = Icons.add_circle_outline_rounded;
                                      iconColor = const Color(0xFF2ECC71);
                                      amountColor = const Color(0xFF2ECC71);
                                    } else if (tx.type == 'refunded') {
                                      iconData = Icons.settings_backup_restore_rounded;
                                      iconColor = const Color(0xFF3B9DFF);
                                      amountColor = const Color(0xFF3B9DFF);
                                    } else {
                                      iconData = Icons.remove_circle_outline_rounded;
                                      iconColor = const Color(0xFFFF5252);
                                      amountColor = const Color(0xFFFF5252);
                                    }

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
                                        child: InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => OrderTrackingScreen(orderId: tx.orderId),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: iconColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    iconData,
                                                    color: iconColor,
                                                    size: 24,
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        tx.description,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _fmtDate(tx.createdAt),
                                                        style: const TextStyle(
                                                          color: _mutedText,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      displayAmount,
                                                      style: TextStyle(
                                                        color: amountColor,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          'View Order',
                                                          style: TextStyle(
                                                            color: _mutedText.withValues(alpha: 0.5),
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 2),
                                                        Icon(
                                                          Icons.chevron_right_rounded,
                                                          color: _mutedText.withValues(alpha: 0.5),
                                                          size: 12,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: _transactions.length,
                                ),
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                ),
    );
  }
}
