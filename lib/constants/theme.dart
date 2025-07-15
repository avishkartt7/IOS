import 'package:flutter/material.dart';

// Main theme colors
const Color buttonColor = Color(0xffFFFFFF);
const Color scaffoldTopGradientClr = Color(0xff8D8AD3);
const Color scaffoldBottomGradientClr = Color(0xff454362);
const Color appBarColor = Colors.transparent;
const Color accentColor = Color(0xff55BD94);
const Color primaryBlack = Color(0xff000000);
const Color textColor = Color(0xffFFFFFF);
const Color primaryWhite = Color(0xffFFFFFF);
const Color overlayContainerClr = Color(0xff2E2E2E);

// Additional colors for enhanced UI
const Color successColor = Color(0xff4CAF50);
const Color errorColor = Color(0xffF44336);
const Color warningColor = Color(0xffFF9800);
const Color infoColor = Color(0xff2196F3);

// Gradient definitions
const LinearGradient primaryGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    scaffoldTopGradientClr,
    scaffoldBottomGradientClr,
  ],
);

const LinearGradient buttonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xff667eea),
    Color(0xff764ba2),
  ],
);

// Text styles
const TextStyle headingStyle = TextStyle(
  color: textColor,
  fontSize: 24,
  fontWeight: FontWeight.bold,
);

const TextStyle subheadingStyle = TextStyle(
  color: textColor,
  fontSize: 18,
  fontWeight: FontWeight.w600,
);

const TextStyle bodyStyle = TextStyle(
  color: textColor,
  fontSize: 16,
  fontWeight: FontWeight.normal,
);

const TextStyle captionStyle = TextStyle(
  color: textColor,
  fontSize: 14,
  fontWeight: FontWeight.w400,
);

// Border radius
const double defaultBorderRadius = 12.0;
const double cardBorderRadius = 16.0;
const double buttonBorderRadius = 8.0;

// Spacing
const double defaultPadding = 16.0;
const double smallPadding = 8.0;
const double largePadding = 24.0;

// Shadow definitions
const List<BoxShadow> defaultShadow = [
  BoxShadow(
    color: Colors.black26,
    blurRadius: 8,
    offset: Offset(0, 4),
  ),
];

const List<BoxShadow> cardShadow = [
  BoxShadow(
    color: Colors.black12,
    blurRadius: 12,
    offset: Offset(0, 6),
  ),
];

// Animation durations
const Duration fastAnimation = Duration(milliseconds: 200);
const Duration normalAnimation = Duration(milliseconds: 300);
const Duration slowAnimation = Duration(milliseconds: 500);

// Common decorations
BoxDecoration get cardDecoration => BoxDecoration(
  color: overlayContainerClr,
  borderRadius: BorderRadius.circular(cardBorderRadius),
  boxShadow: cardShadow,
);

BoxDecoration get buttonDecoration => BoxDecoration(
  color: buttonColor,
  borderRadius: BorderRadius.circular(buttonBorderRadius),
  boxShadow: defaultShadow,
);

InputDecoration get textFieldDecoration => InputDecoration(
  filled: true,
  fillColor: Colors.white.withOpacity(0.1),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(defaultBorderRadius),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(defaultBorderRadius),
    borderSide: const BorderSide(color: accentColor, width: 2),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(defaultBorderRadius),
    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
  ),
  contentPadding: const EdgeInsets.symmetric(
    horizontal: defaultPadding,
    vertical: defaultPadding,
  ),
);