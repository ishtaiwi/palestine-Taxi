import 'package:flutter/material.dart';
import '../pages/driver/driver_home.dart';
import '../pages/driver/driver_trips_page.dart';
import '../pages/driver/driver_queue_page.dart';
import '../pages/driver/driver_vehicle_page.dart';
import '../pages/driver/driver_profile_page.dart';

class DriverBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isDarkMode;
  final bool isArabic;
  final Function(int) onTap;

  const DriverBottomNavBar({
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
        'myTrips': 'رحلاتي',
        'checkIn': 'Check-in',
        'myVehicle': 'مركبتي',
        'profile': 'الملف الشخصي',
      },
      'en': {
        'home': 'Home',
        'myTrips': 'My Trips',
        'checkIn': 'Check-in',
        'myVehicle': 'My Vehicle',
        'profile': 'Profile',
      },
    };
    return texts[isArabic ? 'ar' : 'en']![key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
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
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 2.0 : 4.0, 
            vertical: isSmallScreen ? 4.0 : 6.0
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // My Trips (index 0)
              _buildNavItem(
                context: context,
                icon: Icons.list_alt_rounded,
                label: t('myTrips'),
                index: 0,
                textSecondaryColor: textSecondaryColor,
                accentColor: accentColor,
                isSmallScreen: isSmallScreen,
                isMediumScreen: isMediumScreen,
              ),
              // Check-in (index 1)
              _buildNavItem(
                context: context,
                icon: Icons.check_circle_rounded,
                label: t('checkIn'),
                index: 1,
                textSecondaryColor: textSecondaryColor,
                accentColor: accentColor,
                isSmallScreen: isSmallScreen,
                isMediumScreen: isMediumScreen,
              ),
              // Home - Center item with special design (index 2)
              _buildCenterNavItem(
                context: context,
                icon: Icons.home_rounded,
                label: t('home'),
                index: 2,
                accentColor: accentColor,
                cardColor: cardColor,
                isSmallScreen: isSmallScreen,
                isMediumScreen: isMediumScreen,
              ),
              // My Vehicle (index 3)
              _buildNavItem(
                context: context,
                icon: Icons.directions_car_rounded,
                label: t('myVehicle'),
                index: 3,
                textSecondaryColor: textSecondaryColor,
                accentColor: accentColor,
                isSmallScreen: isSmallScreen,
                isMediumScreen: isMediumScreen,
              ),
              // Profile (index 4)
              _buildNavItem(
                context: context,
                icon: Icons.person_rounded,
                label: t('profile'),
                index: 4,
                textSecondaryColor: textSecondaryColor,
                accentColor: accentColor,
                isSmallScreen: isSmallScreen,
                isMediumScreen: isMediumScreen,
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
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    final isSelected = currentIndex == index;
    
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 2.0 : 4.0, 
            horizontal: isSmallScreen ? 2.0 : 4.0
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 14.0),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? accentColor : textSecondaryColor,
                  size: isSelected 
                      ? (isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0))
                      : (isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0)),
                ),
              ),
              SizedBox(height: isSmallScreen ? 2.0 : 4.0),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  color: isSelected ? accentColor : textSecondaryColor,
                  fontSize: isSelected 
                      ? (isSmallScreen ? 9.0 : (isMediumScreen ? 9.5 : 10.5))
                      : (isSmallScreen ? 8.5 : (isMediumScreen ? 9.0 : 10.0)),
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
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    final isSelected = currentIndex == index;
    final textSecondaryColor = isDarkMode
        ? const Color(0xFFB0BEC5)
        : const Color(0xFF546E7A);
    
    final centerItemSize = isSelected 
        ? (isSmallScreen ? 44.0 : (isMediumScreen ? 48.0 : 52.0))
        : (isSmallScreen ? 40.0 : (isMediumScreen ? 44.0 : 48.0));
    final centerIconSize = isSelected
        ? (isSmallScreen ? 22.0 : (isMediumScreen ? 24.0 : 26.0))
        : (isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0));
    
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(isSmallScreen ? 18.0 : 20.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              width: centerItemSize,
              height: centerItemSize,
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
                borderRadius: BorderRadius.circular(isSmallScreen ? 18.0 : 20.0),
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
                size: centerIconSize,
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 2.0 : 4.0),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              color: isSelected ? accentColor : textSecondaryColor,
              fontSize: isSelected 
                  ? (isSmallScreen ? 9.0 : (isMediumScreen ? 9.5 : 10.5))
                  : (isSmallScreen ? 8.5 : (isMediumScreen ? 9.0 : 10.0)),
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
        // My Trips
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverTripsPage(),
          ),
        );
        break;
      case 1:
        // Check-in (Queue)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverQueuePage(embedded: false),
          ),
        );
        break;
      case 2:
        // Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverHomePage(),
          ),
        );
        break;
      case 3:
        // My Vehicle
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverVehiclePage(),
          ),
        );
        break;
      case 4:
        // Profile
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverProfilePage(),
          ),
        );
        break;
    }
  }
}

