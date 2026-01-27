import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:pinput/pinput.dart';
import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';

class OTPFieldWidget extends StatelessWidget {
  const OTPFieldWidget({super.key, required this.onChanged});

  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 64,
      textStyle: boldMediumLarge.copyWith(
        fontSize: Dimensions.fontOverLarge,
        color: MyColor.getHeadingTextColor(),
      ),
      decoration: BoxDecoration(
        color: MyColor.textFieldBgColor,
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
      ),
    );
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Pinput(
          length: 6,
          defaultPinTheme: defaultPinTheme,
          separatorBuilder: (index) => const SizedBox(width: 16),
          focusedPinTheme: defaultPinTheme.copyWith(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Dimensions.largeRadius),
              boxShadow: [
                BoxShadow(
                  color: MyColor.getTextFieldDisableBorder(),
                  offset: Offset(0, 3),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          onClipboardFound: (value) {
            if (onChanged != null) {
              onChanged!(value);
            }
          },
          showCursor: true,
          onChanged: (value) {
            if (onChanged != null) {
              onChanged!(value);
            }
          },
        ),
      ),
    );
  }
}
