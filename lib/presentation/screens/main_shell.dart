/// Main Shell Screen
/// Shell with bottom navigation containing Converter, Scan, and Profile tabs
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'scanner/my_documents_screen.dart';

/// Main shell with 3-tab bottom navigation
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Global key for profile tab walkthrough
  final GlobalKey _profileTabKey = GlobalKey();

  final List<Widget> _screens = [
    const HomeScreen(),
    const MyDocumentsScreen(), // NEW – fully featured scan screen
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Home / Converter Tab
                Expanded(
                  child: _buildNavItem(
                    index: 0,
                    icon: Icons.transform_outlined,
                    activeIcon: Icons.transform_rounded,
                    label: 'Converter',
                  ),
                ),

                // ── CENTER SCAN BUTTON ──────────────────────────────
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = 1),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentIndex == 1
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.15),
                            boxShadow: _currentIndex == 1
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.5),
                                      blurRadius: 14,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            Icons.document_scanner,
                            color: _currentIndex == 1
                                ? Colors.white
                                : AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _currentIndex == 1
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: _currentIndex == 1
                                ? AppColors.primary
                                : AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Profile Tab
                Expanded(
                  child: _buildNavItem(
                    key: _profileTabKey,
                    index: 2,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    Key? key,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      key: key,
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondaryDark,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
