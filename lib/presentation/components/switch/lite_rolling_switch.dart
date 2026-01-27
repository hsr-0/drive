import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';

class LiteRollingSwitch extends StatefulWidget {
  final bool tValue;
  final double width;
  final String textOff;
  final Color textOffColor;
  final String textOn;
  final Color textOnColor;
  final Color colorOn;
  final Color colorOff;
  final double textSize;
  final Duration animationDuration;
  final IconData iconOn;
  final IconData iconOff;

  /// Async callback that runs when user toggles the switch.
  /// You'll get the **new current status** (true/false).
  /// Return true to confirm the change, false to revert.
  final Future<bool> Function(bool newValue)? onToggle;

  const LiteRollingSwitch({
    super.key,
    this.tValue = false,
    this.width = 130,
    this.textOff = "Offline",
    this.textOn = "Online",
    this.textSize = 14.0,
    this.colorOn = Colors.green,
    this.colorOff = Colors.red,
    this.iconOff = Icons.signal_wifi_off,
    this.iconOn = Icons.network_check,
    this.animationDuration = const Duration(milliseconds: 400),
    this.textOffColor = Colors.white,
    this.textOnColor = Colors.black,
    this.onToggle,
  });

  @override
  State<LiteRollingSwitch> createState() => _RollingSwitchState();
}

class _RollingSwitchState extends State<LiteRollingSwitch> with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> animation;
  late bool turnState;
  double value = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    turnState = widget.tValue;
    animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: turnState ? 1.0 : 0.0,
    );
    animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );
    animation.addListener(() => setState(() => value = animation.value));
  }

  @override
  void didUpdateWidget(LiteRollingSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update state when tValue changes from parent
    if (oldWidget.tValue != widget.tValue && turnState != widget.tValue) {
      setState(() {
        turnState = widget.tValue;
        if (turnState) {
          animationController.forward();
        } else {
          animationController.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleSwitch() async {
    if (_isLoading) return; // prevent double taps

    setState(() => _isLoading = true);

    final bool newValue = !turnState;
    bool success = true;

    // call async callback first if provided
    if (widget.onToggle != null) {
      try {
        success = await widget.onToggle!(newValue);
      } catch (e) {
        printE("Error in onToggle: $e");
        success = false;
      }
    }

    // Only change UI state if callback succeeded
    if (success) {
      setState(() {
        turnState = newValue;
        if (turnState) {
          animationController.forward();
        } else {
          animationController.reverse();
        }
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final Color transitionColor = Color.lerp(
      widget.colorOff,
      widget.colorOn,
      value,
    )!;

    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: _toggleSwitch,
      child: InnerShadowContainer(
        padding: const EdgeInsets.all(5),
        width: widget.width,
        backgroundColor: transitionColor,
        borderRadius: Dimensions.radiusHuge,
        blur: 6,
        offset: const Offset(3, 3),
        shadowColor: MyColor.colorBlack.withValues(alpha: 0.04),
        isShadowTopLeft: true,
        isShadowBottomRight: true,
        child: Stack(
          children: <Widget>[
            // OFF text
            Opacity(
              opacity: (1 - value).clamp(0.0, 1.0),
              child: Align(
                alignment: isRTL(context) ? Alignment.centerLeft : Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    widget.textOff,
                    style: TextStyle(
                      color: widget.textOffColor,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.textSize,
                    ),
                  ),
                ),
              ),
            ),
            // ON text
            Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Align(
                alignment: isRTL(context) ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    widget.textOn,
                    style: TextStyle(
                      color: widget.textOnColor,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.textSize,
                    ),
                  ),
                ),
              ),
            ),
            // Handle (circle)
            Transform.translate(
              offset: isRTL(context) ? Offset((-widget.width + 50) * value, 0) : Offset((widget.width - 50) * value, 0),
              child: Container(
                height: 40,
                width: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: transitionColor,
                        ),
                      )
                    : Stack(
                        children: <Widget>[
                          Center(
                            child: Opacity(
                              opacity: (1 - value).clamp(0.0, 1.0),
                              child: Icon(
                                widget.iconOff,
                                size: 22,
                                color: transitionColor,
                              ),
                            ),
                          ),
                          Center(
                            child: Opacity(
                              opacity: value.clamp(0.0, 1.0),
                              child: Icon(
                                widget.iconOn,
                                size: 22,
                                color: transitionColor,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool isRTL(BuildContext context) {
  return Bidi.isRtlLanguage(Localizations.localeOf(context).languageCode);
}
