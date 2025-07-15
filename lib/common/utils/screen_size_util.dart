import 'package:flutter/material.dart';

class ScreenSizeUtil {
  /// init in the MaterialApp
  static late BuildContext context;

  /// Get screen width
  static double get screenWidth => MediaQuery.of(context).size.width;

  /// Get screen height
  static double get screenHeight => MediaQuery.of(context).size.height;

  /// Get status bar height
  static double get statusBarHeight => MediaQuery.of(context).padding.top;

  /// Get bottom padding (safe area)
  static double get bottomPadding => MediaQuery.of(context).padding.bottom;

  /// Get device pixel ratio
  static double get pixelRatio => MediaQuery.of(context).devicePixelRatio;

  /// Check if screen is small (width < 600)
  static bool get isSmallScreen => screenWidth < 600;

  /// Check if screen is medium (width >= 600 && width < 900)
  static bool get isMediumScreen => screenWidth >= 600 && screenWidth < 900;

  /// Check if screen is large (width >= 900)
  static bool get isLargeScreen => screenWidth >= 900;

  /// Check if device is in landscape mode
  static bool get isLandscape => screenWidth > screenHeight;

  /// Check if device is in portrait mode
  static bool get isPortrait => screenHeight > screenWidth;

  /// Get safe area height (screen height - status bar - bottom padding)
  static double get safeHeight => screenHeight - statusBarHeight - bottomPadding;

  /// Get safe area width (usually same as screen width)
  static double get safeWidth => screenWidth;

  /// Get text scale factor
  static double get textScaleFactor => MediaQuery.of(context).textScaleFactor;

  /// Get keyboard height
  static double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;

  /// Check if keyboard is visible
  static bool get isKeyboardVisible => keyboardHeight > 0;

  /// Initialize the utility with context
  static void init(BuildContext ctx) {
    context = ctx;
  }

  /// Get responsive width based on design width (e.g., 375 for iPhone X)
  static double getResponsiveWidth(double width, {double designWidth = 375}) {
    return (width / designWidth) * screenWidth;
  }

  /// Get responsive height based on design height (e.g., 812 for iPhone X)
  static double getResponsiveHeight(double height, {double designHeight = 812}) {
    return (height / designHeight) * screenHeight;
  }

  /// Get responsive font size
  static double getResponsiveFontSize(double fontSize, {double designWidth = 375}) {
    return (fontSize / designWidth) * screenWidth;
  }

  /// Get minimum of width and height for square elements
  static double get minDimension => screenWidth < screenHeight ? screenWidth : screenHeight;

  /// Get maximum of width and height
  static double get maxDimension => screenWidth > screenHeight ? screenWidth : screenHeight;

  /// Get screen diagonal
  static double get screenDiagonal {
    return (screenWidth * screenWidth + screenHeight * screenHeight) / 
           (screenWidth + screenHeight);
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding({
    double left = 16,
    double top = 16,
    double right = 16,
    double bottom = 16,
  }) {
    double multiplier = isSmallScreen ? 0.8 : (isLargeScreen ? 1.2 : 1.0);
    return EdgeInsets.only(
      left: left * multiplier,
      top: top * multiplier,
      right: right * multiplier,
      bottom: bottom * multiplier,
    );
  }

  /// Get responsive margin based on screen size
  static EdgeInsets getResponsiveMargin({
    double left = 8,
    double top = 8,
    double right = 8,
    double bottom = 8,
  }) {
    double multiplier = isSmallScreen ? 0.8 : (isLargeScreen ? 1.2 : 1.0);
    return EdgeInsets.only(
      left: left * multiplier,
      top: top * multiplier,
      right: right * multiplier,
      bottom: bottom * multiplier,
    );
  }

  /// Get responsive border radius
  static BorderRadius getResponsiveBorderRadius(double radius) {
    double multiplier = isSmallScreen ? 0.8 : (isLargeScreen ? 1.2 : 1.0);
    return BorderRadius.circular(radius * multiplier);
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(double size) {
    double multiplier = isSmallScreen ? 0.9 : (isLargeScreen ? 1.1 : 1.0);
    return size * multiplier;
  }

  /// Get responsive button height
  static double getResponsiveButtonHeight(double height) {
    double multiplier = isSmallScreen ? 0.9 : (isLargeScreen ? 1.1 : 1.0);
    return height * multiplier;
  }

  /// Get orientation specific value
  static T getOrientationValue<T>({
    required T portrait,
    required T landscape,
  }) {
    return isPortrait ? portrait : landscape;
  }

  /// Get device type specific value
  static T getDeviceValue<T>({
    required T mobile,
    required T tablet,
    T? desktop,
  }) {
    if (isSmallScreen) return mobile;
    if (isMediumScreen) return tablet;
    return desktop ?? tablet;
  }

  /// Get responsive columns count for grid
  static int getResponsiveColumns({
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    if (isSmallScreen) return mobile;
    if (isMediumScreen) return tablet;
    return desktop;
  }

  /// Get responsive spacing
  static double getResponsiveSpacing(double spacing) {
    double multiplier = isSmallScreen ? 0.8 : (isLargeScreen ? 1.2 : 1.0);
    return spacing * multiplier;
  }

  /// Get responsive elevation
  static double getResponsiveElevation(double elevation) {
    double multiplier = isSmallScreen ? 0.7 : (isLargeScreen ? 1.3 : 1.0);
    return elevation * multiplier;
  }

  /// Check if device is tablet
  static bool get isTablet => screenWidth >= 600 && screenWidth < 900;

  /// Check if device is phone
  static bool get isPhone => screenWidth < 600;

  /// Check if device is desktop/large screen
  static bool get isDesktop => screenWidth >= 900;

  /// Get app bar height
  static double get appBarHeight => kToolbarHeight;

  /// Get bottom navigation bar height
  static double get bottomNavHeight => kBottomNavigationBarHeight;

  /// Get floating action button size
  static double get fabSize => 56.0;

  /// Get responsive aspect ratio
  static double getResponsiveAspectRatio({
    double mobile = 16/9,
    double tablet = 4/3,
    double desktop = 16/10,
  }) {
    if (isSmallScreen) return mobile;
    if (isMediumScreen) return tablet;
    return desktop;
  }

  /// Get responsive max width for content
  static double getResponsiveMaxWidth({
    double mobile = double.infinity,
    double tablet = 600,
    double desktop = 800,
  }) {
    if (isSmallScreen) return mobile;
    if (isMediumScreen) return tablet;
    return desktop;
  }

  /// Get responsive grid cross axis count
  static int getResponsiveGridCount({
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    if (isSmallScreen) return mobile;
    if (isMediumScreen) return tablet;
    return desktop;
  }

  /// Get responsive text theme scale
  static double get textThemeScale {
    if (isSmallScreen) return 0.9;
    if (isLargeScreen) return 1.1;
    return 1.0;
  }

  /// Get responsive animation duration
  static Duration getResponsiveAnimationDuration({
    Duration mobile = const Duration(milliseconds: 200),
    Duration tablet = const Duration(milliseconds: 250),
    Duration desktop = const Duration(milliseconds: 300),
  }) {
    if (isSmallScreen) return mobile;
    if (isMediumScreen) return tablet;
    return desktop;
  }

  /// Debug information
  static Map<String, dynamic> get debugInfo => {
    'screenWidth': screenWidth,
    'screenHeight': screenHeight,
    'isSmallScreen': isSmallScreen,
    'isMediumScreen': isMediumScreen,
    'isLargeScreen': isLargeScreen,
    'isPortrait': isPortrait,
    'isLandscape': isLandscape,
    'pixelRatio': pixelRatio,
    'textScaleFactor': textScaleFactor,
    'statusBarHeight': statusBarHeight,
    'bottomPadding': bottomPadding,
    'safeHeight': safeHeight,
    'keyboardHeight': keyboardHeight,
    'isKeyboardVisible': isKeyboardVisible,
  };
}