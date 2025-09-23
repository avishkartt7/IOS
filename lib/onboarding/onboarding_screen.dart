// lib/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/pin_entry/pin_entry_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 3;
  bool _isNavigating = false;

  // Animation controller for page transitions and elements
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Welcome to Phoenician',
      'subtitle': 'Technical Services',
      'description': 'Secure workplace authentication powered by advanced facial recognition technology',
      'image': 'assets/images/onboarding_welcome.svg',
    },
    {
      'title': 'Positive Team',
      'subtitle': 'Environment',
      'description': 'Join our positive and collaborative workplace culture',
      'image': 'assets/images/onboarding_positive.svg',
    },
    {
      'title': 'Teamwork Makes',
      'subtitle': 'the Dream Work',
      'description': 'Together we achieve more with secure and efficient authentication',
      'image': 'assets/images/onboarding_teamwork.svg',
    },
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('OnboardingScreen: initState called');

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start animation
    _animationController.forward();

    // Listen for page changes to restart animation
    _pageController.addListener(() {
      if (_pageController.page != null && _pageController.page!.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
        _animationController.reset();
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _markOnboardingComplete() async {
    try {
      debugPrint('Marking onboarding as complete...');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboardingComplete', true);
      debugPrint('Onboarding marked as complete in SharedPreferences');
    } catch (e) {
      debugPrint('Error saving onboarding completion status: $e');
    }
  }

  Future<void> _navigateToPinEntry() async {
    if (_isNavigating) {
      debugPrint('Already navigating, ignoring duplicate call');
      return;
    }

    debugPrint('Navigation initiated - Get Started pressed');

    setState(() {
      _isNavigating = true;
    });

    try {
      // Mark onboarding as complete
      await _markOnboardingComplete();

      // Small delay to ensure state is saved
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) {
        debugPrint('Widget not mounted, canceling navigation');
        return;
      }

      debugPrint('Navigating to PIN Entry View...');

      // Use Navigator.pushAndRemoveUntil to completely replace the stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const PinEntryView(),
          settings: const RouteSettings(name: '/pin_entry'),
        ),
            (Route<dynamic> route) => false, // Remove all previous routes
      );

      debugPrint('Navigation to PIN Entry completed');

    } catch (e) {
      debugPrint('Error during navigation: $e');

      // Reset navigation flag
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });

        // Try simple navigation as fallback
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const PinEntryView()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('OnboardingScreen: build called, currentPage: $_currentPage');

    // Get screen size for responsive design
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF7C4DFF).withOpacity(0.8),
              const Color(0xFF5E72E4),
              const Color(0xFF4FB0FF),
            ],
            stops: const [0.1, 0.5, 0.9],
          ),
        ),
        child: Stack(
          children: [
            // Decorative background elements
            _buildBackgroundElements(screenSize),

            // Main page content
            _buildPageView(),

            // Bottom dots indicator
            _buildDotsIndicator(),

            // Get Started button (only on last page)
            if (_currentPage == _numPages - 1) _buildGetStartedButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundElements(Size screenSize) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -screenSize.height * 0.08,
            left: -screenSize.width * 0.08,
            child: Container(
              width: screenSize.width * 0.4,
              height: screenSize.width * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: screenSize.height * 0.15,
            right: -screenSize.width * 0.1,
            child: Container(
              width: screenSize.width * 0.3,
              height: screenSize.width * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageView() {
    return Positioned.fill(
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) {
          debugPrint('Page changed to: $page');
          setState(() {
            _currentPage = page;
          });
        },
        itemCount: _numPages,
        itemBuilder: (context, index) {
          return _buildPageContent(index);
        },
      ),
    );
  }

  Widget _buildPageContent(int index) {
    final screenSize = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40), // Top spacing

              // Image container
              Container(
                height: screenSize.height * 0.35,
                margin: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SvgPicture.asset(
                          _pages[index]['image']!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenSize.height * 0.05),

              // Title
              Text(
                _pages[index]['title']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              // Subtitle
              Text(
                _pages[index]['subtitle']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: screenSize.height * 0.03),

              // Description
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  _pages[index]['description']!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    height: 1.5,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDotsIndicator() {
    return Positioned(
      bottom: 30.0,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _numPages,
              (index) => _buildDotIndicator(index),
        ),
      ),
    );
  }

  Widget _buildDotIndicator(int index) {
    bool isActive = _currentPage == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive
            ? [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ]
            : null,
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return Positioned(
      bottom: 80.0,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isNavigating ? null : () {
              debugPrint('Get Started button tapped!');
              _navigateToPinEntry();
            },
            borderRadius: BorderRadius.circular(25),
            splashColor: const Color(0xFF5E72E4).withOpacity(0.3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 200,
              height: 50,
              decoration: BoxDecoration(
                color: _isNavigating
                    ? Colors.white.withOpacity(0.7)
                    : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: _isNavigating
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF5E72E4),
                    ),
                  ),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Get Started",
                      style: TextStyle(
                        color: Color(0xFF5E72E4),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: Color(0xFF5E72E4),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



