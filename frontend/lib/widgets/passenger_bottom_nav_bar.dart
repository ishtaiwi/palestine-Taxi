import 'package:flutter/material.dart';
import '../pages/passenger/passenger_home.dart';
import '../pages/passenger/passenger_trips_page.dart';
import '../pages/passenger/passenger_reservations_page.dart';
import '../pages/passenger/passenger_wallet_page.dart';
import '../pages/passenger/passenger_profile_page.dart';

class PassengerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isDarkMode;
  final bool isArabic;
  final Function(int) onTap;

  const PassengerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.isDarkMode,
    required this.isArabic,
    required this.onTap,
  });

  String t(String key) {
    final texts = {
      'ar': {
        'home': 'الرئيسية',
        'viewTrips': 'استعرض الرحلات',
        'myReservations': 'حجوزاتي',
        'myWallet': 'محفظتي',
        'profile': 'الملف الشخصي',
      },
      'en': {
        'home': 'Home',
        'viewTrips': 'View Trips',
        'myReservations': 'My Reservations',
        'myWallet': 'My Wallet',
        'profile': 'Profile',
      },
    };
    return texts[isArabic ? 'ar' : 'en']![key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    final textSecondaryColor = isDarkMode
        ? const Color(0xFFB0BEC5)
        : const Color(0xFF546E7A);
    const accentColor = Color(0xFFF57C00);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(
            color: isDarkMode 
                ? Colors.white.withOpacity(0.1) 
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // View Trips (index 0)
              _buildNavItem(
                context: context,
                icon: Icons.directions_bus_rounded,
                label: t('viewTrips'),
                index: 0,
                textSecondaryColor: textSecondaryColor,
                accentColor: accentColor,
              ),
              // My Reservations (index 1)
              _buildNavItem(
                context: context,
                icon: Icons.book_online_rounded,
                label: t('myReservations'),
                index: 1,
                textSecondaryColor: textSecondaryColor,
                accentColor: accentColor,
              ),
              // Home - Center item with special design (index 2)
              _buildCenterNavItem(
                context: context,
                icon: Icons.home_rounded,
                label: t('home'),
                index: 2,
                accentColor: accentColor,
                cardColor: cardColor,
              ),
              // My Wallet (index 3)
              _buildNavItem(
                context: context,
                icon: Icons.account_balance_wallet_rounded,
                label: t('myWallet'),
                index: 3,
                textSecondaryColor: textSecondaryColor,
                accentColor: accentColor,
              ),
              // Profile (index 4)
              _buildNavItem(
                context: context,
                icon: Icons.person_rounded,
                label: t('profile'),
                index: 4,
                textSecondaryColor: textSecondaryColor,
                accentColor: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required Color textSecondaryColor,
    required Color accentColor,
  }) {
    final isSelected = currentIndex == index;
    
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? accentColor : textSecondaryColor,
                  size: isSelected ? 24 : 22,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  color: isSelected ? accentColor : textSecondaryColor,
                  fontSize: isSelected ? 10.5 : 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.2,
                  height: 1.2,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required Color accentColor,
    required Color cardColor,
  }) {
    final isSelected = currentIndex == index;
    final textSecondaryColor = isDarkMode
        ? const Color(0xFFB0BEC5)
        : const Color(0xFF546E7A);
    
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              width: isSelected ? 52 : 48,
              height: isSelected ? 52 : 48,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor,
                          accentColor.withOpacity(0.8),
                        ],
                      )
                    : null,
                color: isSelected ? null : cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accentColor.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade300),
                  width: isSelected ? 0 : 1,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : accentColor,
                size: isSelected ? 26 : 22,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              color: isSelected ? accentColor : textSecondaryColor,
              fontSize: isSelected ? 10.5 : 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
              height: 1.2,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static void navigateToPage(BuildContext context, int index) {
    switch (index) {
      case 0:
        // View Trips
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PassengerTripsPage(),
          ),
        );
        break;
      case 1:
        // My Reservations
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PassengerReservationsPage(),
          ),
        );
        break;
      case 2:
        // Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PassengerHomePage(),
          ),
        );
        break;
      case 3:
        // My Wallet
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PassengerWalletPage(),
          ),
        );
        break;
      case 4:
        // Profile - Navigate to profile page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PassengerProfilePage(),
          ),
        );
        break;
    }
  }
}

