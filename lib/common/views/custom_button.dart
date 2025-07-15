import 'package:face_auth/constants/theme.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDisabled;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final IconData? icon;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  const CustomButton({
    Key? key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.icon,
    this.padding,
    this.borderRadius,
    this.boxShadow,
  }) : super(key: key);

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = !widget.isDisabled && !widget.isLoading && widget.onTap != null;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: GestureDetector(
              onTapDown: isInteractive ? _onTapDown : null,
              onTapUp: isInteractive ? _onTapUp : null,
              onTapCancel: isInteractive ? _onTapCancel : null,
              onTap: isInteractive ? _onTap : null,
              child: Container(
                width: widget.width,
                height: widget.height ?? 56,
                padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(),
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                  boxShadow: widget.boxShadow ?? (isInteractive ? _getDefaultShadow() : null),
                  border: widget.isDisabled 
                      ? Border.all(color: Colors.grey.withOpacity(0.3))
                      : null,
                ),
                child: _buildButtonContent(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonContent() {
    if (widget.isLoading) {
      return _buildLoadingContent();
    }

    if (widget.icon != null) {
      return _buildIconTextContent();
    }

    return _buildTextContent();
  }

  Widget _buildLoadingContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _getTextColor(),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          "Loading...",
          style: TextStyle(
            color: _getTextColor(),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildIconTextContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          widget.icon,
          color: _getTextColor(),
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          widget.text,
          style: TextStyle(
            color: _getTextColor(),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextContent() {
    return Text(
      widget.text,
      style: TextStyle(
        color: _getTextColor(),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
    );
  }

  Color _getBackgroundColor() {
    if (widget.isDisabled) {
      return Colors.grey.withOpacity(0.3);
    }
    
    if (widget.backgroundColor != null) {
      return widget.backgroundColor!;
    }
    
    return buttonColor;
  }

  Color _getTextColor() {
    if (widget.isDisabled) {
      return Colors.grey;
    }
    
    if (widget.textColor != null) {
      return widget.textColor!;
    }
    
    // Auto-detect text color based on background
    Color bgColor = _getBackgroundColor();
    if (bgColor == buttonColor) {
      return primaryBlack;
    }
    
    return primaryWhite;
  }

  List<BoxShadow> _getDefaultShadow() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: _getBackgroundColor().withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ];
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  void _onTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }
}

// Specialized button variations
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final IconData? icon;

  const PrimaryButton({
    Key? key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onTap: onTap,
      isLoading: isLoading,
      isDisabled: isDisabled,
      width: width,
      icon: icon,
      backgroundColor: accentColor,
      textColor: primaryWhite,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final IconData? icon;

  const SecondaryButton({
    Key? key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onTap: onTap,
      isLoading: isLoading,
      isDisabled: isDisabled,
      width: width,
      icon: icon,
      backgroundColor: Colors.transparent,
      textColor: accentColor,
      boxShadow: null,
    );
  }
}

class OutlinedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final IconData? icon;

  const OutlinedButton({
    Key? key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border.all(
          color: isDisabled ? Colors.grey.withOpacity(0.3) : accentColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomButton(
        text: text,
        onTap: onTap,
        isLoading: isLoading,
        isDisabled: isDisabled,
        width: width,
        icon: icon,
        backgroundColor: Colors.transparent,
        textColor: isDisabled ? Colors.grey : accentColor,
        boxShadow: null,
      ),
    );
  }
}

class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final IconData? icon;

  const DangerButton({
    Key? key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onTap: onTap,
      isLoading: isLoading,
      isDisabled: isDisabled,
      width: width,
      icon: icon,
      backgroundColor: errorColor,
      textColor: primaryWhite,
    );
  }
}