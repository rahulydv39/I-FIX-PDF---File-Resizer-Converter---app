import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/di/injection_container.dart';
import '../../data/services/walkthrough_service.dart';
import 'auth_wrapper.dart';

class AppTourScreen extends StatefulWidget {
  const AppTourScreen({super.key});

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.auto_fix_high_rounded,
      'title': 'Welcome to I FIX PDF',
      'description': 'Your all-in-one PDF toolkit. Convert, compress, and edit documents seamlessly.',
      'color': AppColors.primary,
    },
    {
      'icon': Icons.security_rounded,
      'title': '100% Private & Local',
      'description': 'Your files never leave your device. All conversions happen entirely on your phone.',
      'color': AppColors.success,
    },
    {
      'icon': Icons.auto_awesome_mosaic_rounded,
      'title': 'Powerful Features',
      'description': 'Convert photos to PDF, resize images, and merge multiple documents effortlessly.',
      'color': AppColors.secondary,
    },
    {
      'icon': Icons.document_scanner_rounded,
      'title': 'Built-in Scanner',
      'description': 'Scan physical documents directly from your camera and save them instantly.',
      'color': AppColors.accent,
    },
  ];

  void _finishTour() async {
    final walkthroughService = sl<WalkthroughService>();
    await walkthroughService.markWalkthroughComplete();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthWrapper(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar (Skip)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _finishTour,
                  child: const Text('Skip', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 16)),
                ),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: page['color'].withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page['icon'],
                            size: 80,
                            color: page['color'],
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          page['title'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page['description'],
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondaryDark,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Nav
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(_pages.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? AppColors.primary : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Let's Go
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finishTour();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      _currentPage < _pages.length - 1 ? 'Next' : "Let's Go!",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
