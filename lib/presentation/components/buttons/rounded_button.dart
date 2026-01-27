import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import '../../../core/utils/style.dart';

class RoundedButton extends StatefulWidget {
  final bool isColorChange;
  final String text;
  final VoidCallback press;
  final Color? bgColor;
  final Color? textColor;
  final double width;
  final double height;
  final double cornerRadius;
  final bool isOutlined;
  final Widget? child;
  final TextStyle? textStyle;
  final bool isLoading;
  final Color borderColor; // Added for outlined button border color
  final bool isDisabled; // Added to handle disabled state
  const RoundedButton({
    super.key,
    this.isColorChange = false,
    this.width = 1,
    this.child,
    this.cornerRadius = 14,
    this.height = 56,
    required this.text,
    required this.press,
    this.isOutlined = false,
    this.bgColor,
    this.textColor = MyColor.colorWhite,
    this.textStyle,
    this.isLoading = false,
    this.borderColor = MyColor.primaryButtonColor, // Default border color
    this.isDisabled = false,
  });

  @override
  State<RoundedButton> createState() => _RoundedButtonState();
}

class _RoundedButtonState extends State<RoundedButton> {
  bool _isPressed = false;

  void _onPointerDown(PointerDownEvent event) {
    // printX("_onPointerDown");
    if (widget.isDisabled || widget.isLoading) return;
    setState(() => _isPressed = true);
  }

  void _onPointerUp(PointerUpEvent event) {
    // printX("_onPointerUp");
    if (widget.isDisabled || widget.isLoading) return;
    setState(() => _isPressed = false);
    // widget.press();
  }

  @override
  Widget build(BuildContext context) {
    final double buttonScale = _isPressed ? 0.95 : 1.0;
    final double buttonOpacity = widget.isDisabled ? 0.6 : 1.0;

    // Define the text style for the button
    final effectiveTextStyle = widget.textStyle ??
        regularDefault.copyWith(
          color: widget.isOutlined ? widget.textColor ?? widget.bgColor ?? MyColor.primaryButtonColor : widget.textColor ?? MyColor.colorWhite,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
        );

    // Define the main content of the button (text or loading indicator)
    Widget buttonContent = widget.isLoading
        ? SpinKitFadingCircle(
            color: widget.isOutlined ? widget.textColor ?? widget.bgColor ?? MyColor.primaryButtonColor : widget.textColor ?? MyColor.colorWhite,
            size: 25.0,
          )
        : widget.child ?? Text(widget.text.tr, style: effectiveTextStyle);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: AnimatedScale(
        scale: buttonScale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: buttonOpacity,
          duration: const Duration(milliseconds: 150),
          child: widget.isOutlined ? buildOutLineButtonStyleWidget(buttonContent) : buildButtonStyleWidget(buttonContent),
        ),
      ),
    );
  }

  Widget buildButtonStyleWidget(Widget buttonContent) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.cornerRadius),
        border: Border.all(
          color: (widget.bgColor ?? MyColor.primaryButtonColor).withValues(
            alpha: 0.5,
          ), // border color
          width: 1.5,
        ),
        color: (widget.bgColor ?? MyColor.primaryButtonColor), // primary background
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.cornerRadius),
                gradient: LinearGradient(
                  colors: [
                    MyColor.secondaryButtonColor.withValues(alpha: 0.2),
                    Color.fromRGBO(255, 255, 255, 0.0),
                  ],
                  begin: Alignment(0.0, -1.0),
                  end: Alignment(0.0, -0.7),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.cornerRadius),
                gradient: LinearGradient(
                  colors: [
                    MyColor.secondaryButtonColor.withValues(alpha: 0.2),
                    Color.fromRGBO(255, 255, 255, 0.0),
                  ],
                  begin: Alignment(1.0, 0.0),
                  end: Alignment(0.97, 0.0),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.cornerRadius),
                gradient: LinearGradient(
                  colors: [
                    MyColor.secondaryButtonColor.withValues(alpha: 0.2),
                    Color.fromRGBO(255, 255, 255, 0.0),
                  ],
                  begin: Alignment(-1.0, 0.0), // left center (far left)
                  end: Alignment(-0.97, 0.0), // slightly right of left center
                ),
              ),
            ),
          ),

          // Button Content
          InkWell(
            borderRadius: BorderRadius.circular(widget.cornerRadius),
            onTap: widget.press,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: buttonContent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOutLineButtonStyleWidget(Widget buttonContent) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.cornerRadius),
        border: Border.all(
          color: MyColor.colorBlack.withValues(alpha: 0.06),
          width: 1,
        ),
        color: (widget.bgColor ?? MyColor.secondaryButtonColor), // primary background
        boxShadow: [
          BoxShadow(
            color: MyColor.colorBlack.withValues(alpha: 0.02),
            offset: const Offset(0, 3),
            blurRadius: 0,
            spreadRadius: 1.5,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.cornerRadius),
                gradient: LinearGradient(
                  colors: [
                    MyColor.colorBlack.withValues(alpha: 0.04),
                    Color.fromRGBO(255, 255, 255, 0.0),
                  ],
                  begin: Alignment(0.0, 1.0),
                  end: Alignment(0.0, 0.7),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.cornerRadius),
                gradient: LinearGradient(
                  colors: [
                    MyColor.colorBlack.withValues(alpha: 0.04),
                    Color.fromRGBO(255, 255, 255, 0.0),
                  ],
                  begin: Alignment(1.0, 0.0),
                  end: Alignment(0.97, 0.0),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.cornerRadius),
                gradient: LinearGradient(
                  colors: [
                    MyColor.colorBlack.withValues(alpha: 0.04),
                    Color.fromRGBO(255, 255, 255, 0.0),
                  ],
                  begin: Alignment(-1.0, 0.0), // left center (far left)
                  end: Alignment(-0.97, 0.0), // slightly right of left center
                ),
              ),
            ),
          ),

          // Button Content
          InkWell(
            borderRadius: BorderRadius.circular(widget.cornerRadius),
            onTap: widget.press,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: buttonContent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
