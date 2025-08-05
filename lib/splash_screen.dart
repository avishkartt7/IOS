// lib/splash_screen.dart - CLEAN WHITE SPLASH SCREEN

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    Key? key,
    required this.nextScreen,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Set status bar to white
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    // Start animation and navigate after delay
    _startSplashSequence();
  }

  void _startSplashSequence() async {
    // Start animations
    _animationController.forward();

    // Wait for animation to complete + small delay
    await Future.delayed(const Duration(milliseconds: 2500));

    // Navigate to next screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Company Logo
                      Container(
                        width: isTablet ? 120 : 100,
                        height: isTablet ? 120 : 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D4B),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E7D4B).withOpacity(0.2),
                              spreadRadius: 0,
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "P",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 48 : 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: isTablet ? 32 : 24),

                      // Company Name
                      Text(
                        "PHOENICIAN TECHNICAL SERVICES",
                        style: TextStyle(
                          color: const Color(0xFF2E7D4B),
                          fontSize: isTablet ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: isTablet ? 16 : 12),

                      Text(
                        "Phoenician Technical Services LLC",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: isTablet ? 48 : 36),

                      // Loading indicator
                      SizedBox(
                        width: isTablet ? 32 : 28,
                        height: isTablet ? 32 : 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFF2E7D4B).withOpacity(0.8),
                          ),
                        ),
                      ),

                      SizedBox(height: isTablet ? 24 : 16),

                      Text(
                        "Loading...",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Alternative minimal splash screen without animations
class MinimalSplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final int delayMilliseconds;

  const MinimalSplashScreen({
    Key? key,
    required this.nextScreen,
    this.delayMilliseconds = 2000,
  }) : super(key: key);

  @override
  State<MinimalSplashScreen> createState() => _MinimalSplashScreenState();
}

class _MinimalSplashScreenState extends State<MinimalSplashScreen> {
  @override
  void initState() {
    super.initState();

    // Set white status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Navigate after delay
    Timer(Duration(milliseconds: widget.delayMilliseconds), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => widget.nextScreen),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Simple Logo
              Container(
                width: isTablet ? 100 : 80,
                height: isTablet ? 100 : 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D4B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    "P",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 40 : 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: isTablet ? 24 : 20),

              // Company Name
              Text(
                "PHOENICIAN TECHNICAL SERVICES",
                style: TextStyle(
                  color: const Color(0xFF2E7D4B),
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: isTablet ? 12 : 8),

              Text(
                "Phoenician Technical Services LLC",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
