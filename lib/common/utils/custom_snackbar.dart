import 'package:face_auth/constants/theme.dart';
import 'package:flutter/material.dart';

class CustomSnackBar {
  // Keep the static context for backwards compatibility
  static BuildContext? context;

  // Method overloading for errorSnackBar - supports both formats
  static void errorSnackBar(dynamic contextOrMessage, [String? message]) {
    BuildContext? targetContext;
    String targetMessage;

    // Determine if first parameter is context or message
    if (contextOrMessage is BuildContext) {
      // Format: errorSnackBar(context, message)
      targetContext = contextOrMessage;
      targetMessage = message ?? '';
    } else if (contextOrMessage is String) {
      // Format: errorSnackBar(message) - use static context
      targetContext = context;
      targetMessage = contextOrMessage;
    } else {
      return; // Invalid parameters
    }

    if (targetContext != null && targetContext.mounted) {
      ScaffoldMessenger.of(targetContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  targetMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Method overloading for successSnackBar - supports both formats
  static void successSnackBar(dynamic contextOrMessage, [String? message]) {
    BuildContext? targetContext;
    String targetMessage;

    // Determine if first parameter is context or message
    if (contextOrMessage is BuildContext) {
      // Format: successSnackBar(context, message)
      targetContext = contextOrMessage;
      targetMessage = message ?? '';
    } else if (contextOrMessage is String) {
      // Format: successSnackBar(message) - use static context
      targetContext = context;
      targetMessage = contextOrMessage;
    } else {
      return; // Invalid parameters
    }

    if (targetContext != null && targetContext.mounted) {
      ScaffoldMessenger.of(targetContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  targetMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: successColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Method overloading for warningSnackBar - supports both formats
  static void warningSnackBar(dynamic contextOrMessage, [String? message]) {
    BuildContext? targetContext;
    String targetMessage;

    // Determine if first parameter is context or message
    if (contextOrMessage is BuildContext) {
      // Format: warningSnackBar(context, message)
      targetContext = contextOrMessage;
      targetMessage = message ?? '';
    } else if (contextOrMessage is String) {
      // Format: warningSnackBar(message) - use static context
      targetContext = context;
      targetMessage = contextOrMessage;
    } else {
      return; // Invalid parameters
    }

    if (targetContext != null && targetContext.mounted) {
      ScaffoldMessenger.of(targetContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  targetMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: warningColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Method overloading for infoSnackBar - supports both formats
  static void infoSnackBar(dynamic contextOrMessage, [String? message]) {
    BuildContext? targetContext;
    String targetMessage;

    // Determine if first parameter is context or message
    if (contextOrMessage is BuildContext) {
      // Format: infoSnackBar(context, message)
      targetContext = contextOrMessage;
      targetMessage = message ?? '';
    } else if (contextOrMessage is String) {
      // Format: infoSnackBar(message) - use static context
      targetContext = context;
      targetMessage = contextOrMessage;
    } else {
      return; // Invalid parameters
    }

    if (targetContext != null && targetContext.mounted) {
      ScaffoldMessenger.of(targetContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  targetMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: infoColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Flexible customSnackBar - supports both formats
  static void customSnackBar({
    BuildContext? context,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Use provided context or fall back to static context
    BuildContext? targetContext = context ?? CustomSnackBar.context;

    if (targetContext != null && targetContext.mounted) {
      ScaffoldMessenger.of(targetContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: duration,
        ),
      );
    }
  }

  // Helper method to set static context (optional, for convenience)
  static void setContext(BuildContext ctx) {
    context = ctx;
  }
}