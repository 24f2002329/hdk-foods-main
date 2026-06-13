import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "Welcome to HDK Foods",
      "description": "Discover fresh, fast, and homemade cloud kitchen meals delivered right to your doorstep.",
      "icon": "restaurant",
    },
    {
      "title": "Fresh Ingredients",
      "description": "We use only the freshest and highest quality ingredients to prepare your daily meals.",
      "icon": "eco",
    },
    {
      "title": "Fast Delivery",
      "description": "Hot and delicious food delivered quickly to ensure the best dining experience at home.",
      "icon": "delivery_dining",
    },
    {
      "title": "Easy Ordering",
      "description": "Seamlessly browse our menu, place your order, and track your delivery in real-time.",
      "icon": "touch_app",
    },
  ];

  IconData _getIcon(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant;
      case 'eco':
        return Icons.eco;
      case 'delivery_dining':
        return Icons.delivery_dining;
      case 'touch_app':
        return Icons.touch_app;
      default:
        return Icons.fastfood;
    }
  }

  void _completeOnboarding() async {
    await TokenStorage.setOnboardingComplete();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text(
                  "Skip",
                  style: TextStyle(
                    color: Color(0xFF8F8F8F),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF1E1E).withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _getIcon(_onboardingData[index]["icon"]!),
                            size: 80,
                            color: const Color(0xFFFF1E1E),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          _onboardingData[index]["title"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _onboardingData[index]["description"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF8F8F8F),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFFFF1E1E)
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _onboardingData.length - 1) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF1E1E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _currentPage == _onboardingData.length - 1
                          ? "Get Started"
                          : "Next",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
