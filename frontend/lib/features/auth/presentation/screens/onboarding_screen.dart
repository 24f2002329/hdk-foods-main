import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../../core/navigation/app_routes.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

const _imgSandwich =
    'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=800';
const _imgWaffle =
    'https://images.unsplash.com/photo-1562376552-0d160a2f238d?w=800';
const _imgFries =
    'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=800';
const _imgBurger =
    'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800';
const _imgDelivery =
    'https://images.unsplash.com/photo-1617347454431-f49d7ff5c3b1?w=800';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _animCtrl;

  // Entrance animation intervals
  late final Animation<double> _heroBgAnim;
  late final Animation<double> _heroAnim;
  late final Animation<double> _headlineAnim;
  late final Animation<double> _subtitleAnim;

  int _currentPage = 0;
  static const int _totalPages = 6;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _heroBgAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _heroAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
    );
    _headlineAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _subtitleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _animCtrl.forward(from: 0);
  }

  Future<void> _completeOnboarding({bool goToLogin = false}) async {
    await TokenStorage.setOnboardingComplete();
    if (!mounted) return;
    if (goToLogin) {
      AppRoutes.pushReplacementLogin(context);
    } else {
      AppRoutes.pushReplacementHome(context);
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              _Screen1(
                heroAnim: _heroAnim,
                headlineAnim: _headlineAnim,
                subtitleAnim: _subtitleAnim,
                heroBgAnim: _heroBgAnim,
              ),
              _Screen2(
                heroAnim: _heroAnim,
                headlineAnim: _headlineAnim,
                subtitleAnim: _subtitleAnim,
                heroBgAnim: _heroBgAnim,
              ),
              _Screen3(
                heroAnim: _heroAnim,
                headlineAnim: _headlineAnim,
                subtitleAnim: _subtitleAnim,
                heroBgAnim: _heroBgAnim,
              ),
              _Screen4(
                heroAnim: _heroAnim,
                headlineAnim: _headlineAnim,
                subtitleAnim: _subtitleAnim,
                heroBgAnim: _heroBgAnim,
              ),
              _Screen5(
                heroAnim: _heroAnim,
                headlineAnim: _headlineAnim,
                subtitleAnim: _subtitleAnim,
                onNext: _nextPage,
              ),
              _Screen6(
                heroAnim: _heroAnim,
                headlineAnim: _headlineAnim,
                onComplete: _completeOnboarding,
              ),
            ],
          ),
          // Skip button — hidden on location screen and final CTA
          if (_currentPage < _totalPages - 2)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: TextButton(
                    onPressed: () => _completeOnboarding(goToLogin: false),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Bottom nav bar — progress + Next button (screens 1–4 only)
          if (_currentPage < _totalPages - 2)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SegmentedProgress(
                        current: _currentPage,
                        total: _totalPages - 1,
                      ),
                      FilledButton(
                        onPressed: _nextPage,
                        style: FilledButton.styleFrom(
                          backgroundColor: _brandRed,
                          minimumSize: const Size(100, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Segmented progress indicator ────────────────────────────────────────────

class _SegmentedProgress extends StatelessWidget {
  final int current;
  final int total;

  const _SegmentedProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 6),
          height: 4,
          width: i <= current ? 28 : 14,
          decoration: BoxDecoration(
            color: i <= current ? _brandRed : _stroke,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Widget _fadeSlideUp({required Animation<double> anim, required Widget child}) {
  return FadeTransition(
    opacity: anim,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(anim),
      child: child,
    ),
  );
}

Widget _networkImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  double? height,
  double? width,
}) {
  return Image.network(
    url,
    fit: fit,
    height: height,
    width: width,
    loadingBuilder: (_, child, progress) {
      if (progress == null) return child;
      return Container(color: _panel, height: height, width: width);
    },
    errorBuilder: (_, e, s) =>
        Container(color: _panel, height: height, width: width),
  );
}

// Dark-to-transparent gradient overlay at the bottom of full-bleed images
Widget _bottomGradient() {
  return Positioned.fill(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.35, 1.0],
          colors: [_surface.withValues(alpha: 0.0), _surface],
        ),
      ),
    ),
  );
}

Widget _screenText({
  required Animation<double> headlineAnim,
  required Animation<double> subtitleAnim,
  required String headline,
  required String sub,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(28, 0, 28, 140),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _fadeSlideUp(
          anim: headlineAnim,
          child: Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _fadeSlideUp(
          anim: subtitleAnim,
          child: Text(
            sub,
            style: const TextStyle(
              color: _mutedText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Screen 1: Brand Intro ────────────────────────────────────────────────────

class _Screen1 extends StatelessWidget {
  final Animation<double> heroBgAnim;
  final Animation<double> heroAnim;
  final Animation<double> headlineAnim;
  final Animation<double> subtitleAnim;

  const _Screen1({
    required this.heroBgAnim,
    required this.heroAnim,
    required this.headlineAnim,
    required this.subtitleAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Radial glow background
        FadeTransition(
          opacity: heroBgAnim,
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 0.85,
                colors: [Color(0xFF3A0000), _surface],
              ),
            ),
          ),
        ),
        // Centred logo hero
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 180,
          child: _fadeSlideUp(
            anim: heroAnim,
            child: const Center(child: _HdkLogo()),
          ),
        ),
        _bottomGradient(),
        _screenText(
          headlineAnim: headlineAnim,
          subtitleAnim: subtitleAnim,
          headline: 'Freshly Made.\nEvery Time.',
          sub: 'Not pre-packed. Prepared after you order.',
        ),
      ],
    );
  }
}

class _HdkLogo extends StatelessWidget {
  const _HdkLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _brandRed.withValues(alpha: 0.45),
                blurRadius: 56,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/hdk-logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'CLOUD KITCHEN',
          style: TextStyle(
            color: _mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}

// ─── Screen 2: Best Sellers ────────────────────────────────────────────────────

class _Screen2 extends StatelessWidget {
  final Animation<double> heroBgAnim;
  final Animation<double> heroAnim;
  final Animation<double> headlineAnim;
  final Animation<double> subtitleAnim;

  const _Screen2({
    required this.heroBgAnim,
    required this.heroAnim,
    required this.headlineAnim,
    required this.subtitleAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed sandwich background
        FadeTransition(opacity: heroBgAnim, child: _networkImage(_imgSandwich)),
        _bottomGradient(),
        // Food cards row
        Positioned(
          left: 20,
          right: 20,
          bottom: 270,
          child: _fadeSlideUp(anim: heroAnim, child: const _FoodCardRow()),
        ),
        _screenText(
          headlineAnim: headlineAnim,
          subtitleAnim: subtitleAnim,
          headline: 'Taste That Hits\nDifferent',
          sub: 'Sandwiches, waffles, fries and more.',
        ),
      ],
    );
  }
}

class _FoodCardRow extends StatelessWidget {
  const _FoodCardRow();

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Sandwich', _imgSandwich),
      ('Waffle', _imgWaffle),
      ('Fries', _imgFries),
      ('Burgers', _imgBurger),
    ];

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _networkImage(item.$2, height: 72),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── Screen 3: Delivery ───────────────────────────────────────────────────────

class _Screen3 extends StatelessWidget {
  final Animation<double> heroBgAnim;
  final Animation<double> heroAnim;
  final Animation<double> headlineAnim;
  final Animation<double> subtitleAnim;

  const _Screen3({
    required this.heroBgAnim,
    required this.heroAnim,
    required this.headlineAnim,
    required this.subtitleAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Delivery background image with dark overlay
        FadeTransition(
          opacity: heroBgAnim,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              _surface.withValues(alpha: 0.55),
              BlendMode.darken,
            ),
            child: _networkImage(_imgDelivery),
          ),
        ),
        // Scooter icon sliding in
        Positioned(
          top: 0,
          bottom: 220,
          left: 0,
          right: 0,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(-0.6, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: heroAnim, curve: Curves.easeOutCubic),
                ),
            child: FadeTransition(
              opacity: heroAnim,
              child: Center(
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    color: _brandRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _brandRed.withValues(alpha: 0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.delivery_dining,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        _screenText(
          headlineAnim: headlineAnim,
          subtitleAnim: subtitleAnim,
          headline: 'Delivered While\nIt\'s Hot',
          sub: 'Track your order from kitchen to doorstep.',
        ),
      ],
    );
  }
}

// ─── Screen 4: Exclusive Offers ───────────────────────────────────────────────

class _Screen4 extends StatefulWidget {
  final Animation<double> heroBgAnim;
  final Animation<double> heroAnim;
  final Animation<double> headlineAnim;
  final Animation<double> subtitleAnim;

  const _Screen4({
    required this.heroBgAnim,
    required this.heroAnim,
    required this.headlineAnim,
    required this.subtitleAnim,
  });

  @override
  State<_Screen4> createState() => _Screen4State();
}

class _Screen4State extends State<_Screen4>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: widget.heroBgAnim,
          child: _networkImage(_imgBurger),
        ),
        _bottomGradient(),
        Positioned(
          top: 100,
          left: 32,
          right: 32,
          child: _fadeSlideUp(
            anim: widget.heroAnim,
            child: _CouponCard(shimmerAnim: _shimmerAnim),
          ),
        ),
        _screenText(
          headlineAnim: widget.headlineAnim,
          subtitleAnim: widget.subtitleAnim,
          headline: 'Rewards For\nEvery Order',
          sub: 'Exclusive app-only deals and loyalty points.',
        ),
      ],
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Animation<double> shimmerAnim;

  const _CouponCard({required this.shimmerAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnim,
      builder: (_, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFFFF1E1E),
                  const Color(0xFFFF6B35),
                  shimmerAnim.value,
                )!,
                const Color(0xFF8D0000),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _brandRed.withValues(alpha: 0.45),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '20%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'OFF',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PillBadge('FIRST ORDER'),
                    SizedBox(height: 8),
                    Text(
                      'Use code HDK20 on your first order',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;

  const _PillBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _brandRed,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ─── Screen 5: Location Permission ───────────────────────────────────────────

class _Screen5 extends StatefulWidget {
  final Animation<double> heroAnim;
  final Animation<double> headlineAnim;
  final Animation<double> subtitleAnim;
  final VoidCallback onNext;

  const _Screen5({
    required this.heroAnim,
    required this.headlineAnim,
    required this.subtitleAnim,
    required this.onNext,
  });

  @override
  State<_Screen5> createState() => _Screen5State();
}

class _Screen5State extends State<_Screen5>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestNotifications() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
  }

  Future<void> _requestLocation() async {
    setState(() => _requesting = true);
    try {
      final status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
    await _requestNotifications();
    if (mounted) {
      setState(() => _requesting = false);
      widget.onNext();
    }
  }

  Future<void> _skipLocation() async {
    await _requestNotifications();
    if (mounted) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.3,
          child: Image.asset(
            'assets/images/hdk-locations.png',
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                ScaleTransition(
                  scale: _pulseAnim,
                  child: FadeTransition(
                    opacity: widget.heroAnim,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: _panel,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _brandRed.withValues(alpha: 0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _brandRed.withValues(alpha: 0.3),
                            blurRadius: 48,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 68,
                        color: _brandRed,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                _fadeSlideUp(
                  anim: widget.headlineAnim,
                  child: const Text(
                    'Delivering in Sojat Road\nand Nearby Areas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _fadeSlideUp(
                  anim: widget.subtitleAnim,
                  child: const Text(
                    'We need your location to show delivery availability and accurate delivery times.',
                    style: TextStyle(
                      color: _mutedText,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                FilledButton(
                  onPressed: _requesting ? null : _requestLocation,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandRed,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _requesting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Enable Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _requesting ? null : _skipLocation,
                  child: const Text(
                    'Not now',
                    style: TextStyle(
                      color: _mutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Screen 6: Final CTA ──────────────────────────────────────────────────────

class _Screen6 extends StatelessWidget {
  final Animation<double> heroAnim;
  final Animation<double> headlineAnim;
  final void Function({bool goToLogin}) onComplete;

  const _Screen6({
    required this.heroAnim,
    required this.headlineAnim,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            _fadeSlideUp(anim: heroAnim, child: const _FoodCollage()),
            const Spacer(),
            _fadeSlideUp(
              anim: headlineAnim,
              child: const Text(
                'Ready to order?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join thousands of happy customers.',
              style: TextStyle(
                color: _mutedText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => onComplete(goToLogin: true),
              style: FilledButton.styleFrom(
                backgroundColor: _brandRed,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Continue with Phone Number',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => onComplete(goToLogin: false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: _stroke, width: 1.5),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Browse Menu First',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodCollage extends StatelessWidget {
  const _FoodCollage();

  @override
  Widget build(BuildContext context) {
    final images = [_imgSandwich, _imgWaffle, _imgFries, _imgBurger];

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.42,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: images.length,
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _networkImage(images[i]),
        ),
      ),
    );
  }
}
