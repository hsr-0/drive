import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';

class CustomTextField extends StatefulWidget {
  final bool isRequired;
  final String? hintText;
  final String? labelText;
  final Widget? labelWidget;
  final TextStyle? hintTextStyle;
  final TextStyle? textStyle;
  final Function? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final FormFieldValidator? validator;
  final TextInputType? textInputType;
  final bool isEnable;
  final bool isPassword;
  final bool isShowSuffixIcon;
  final bool isIcon;
  final VoidCallback? onSuffixTap;
  final VoidCallback? onTap;
  final bool isSearch;
  final bool isCountryPicker;
  final TextInputAction inputAction;
  final bool readOnly;
  final int maxLines;
  final Color fillColor;
  final Widget? prefixIcon;
  final Widget? suffixWidget;
  final BoxConstraints? suffixIconConstraints;
  final List<TextInputFormatter>? inputFormatters;
  final double? radius;
  final bool isShowInstructionWidget;
  final String? instructions;
  const CustomTextField({
    super.key,
    this.isRequired = false,
    this.hintText,
    this.labelText,
    this.labelWidget,
    this.hintTextStyle,
    this.textStyle,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.nextFocus,
    this.validator,
    this.textInputType,
    this.isEnable = true,
    this.isPassword = false,
    this.isShowSuffixIcon = false,
    this.isIcon = false,
    this.onSuffixTap,
    this.onTap,
    this.isSearch = false,
    this.isCountryPicker = false,
    this.inputAction = TextInputAction.next,
    this.readOnly = false,
    this.maxLines = 1,
    this.fillColor = MyColor.neutral50,
    this.prefixIcon,
    this.suffixWidget,
    this.suffixIconConstraints,
    this.inputFormatters,
    this.radius = Dimensions.mediumRadius,
    this.isShowInstructionWidget = false,
    this.instructions,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool obscureText = true;
  String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null && widget.labelText!.isNotEmpty) ...[
          if (widget.labelWidget != null) ...[
            widget.labelWidget!,
          ] else ...[
            HeaderText(
              text: (widget.labelText?.tr ?? ""),
              style: regularDefault.copyWith(
                color: MyColor.getHeadingTextColor(),
                fontSize: Dimensions.fontNormal,
              ),
            ),
            spaceDown(Dimensions.space10),
          ],
        ],
        InnerShadowContainer(
          width: double.infinity,
          backgroundColor: widget.fillColor,
          borderRadius: Dimensions.largeRadius,
          blur: 6,
          offset: Offset(3, 3),
          shadowColor: errorText != null && errorText!.isNotEmpty ? MyColor.colorRed.withValues(alpha: 0.2) : MyColor.colorBlack.withValues(alpha: 0.04),
          isShadowTopLeft: true,
          isShadowBottomRight: true,
          child: TextFormField(
            key: widget.key,
            maxLines: widget.maxLines,
            readOnly: widget.readOnly,
            style: widget.textStyle ?? regularLarge.copyWith(color: MyColor.getHeadingTextColor()),
            onTap: widget.onTap,
            cursorColor: MyColor.getTextColor(),
            controller: widget.controller,
            autofocus: false,
            enabled: widget.isEnable,
            focusNode: widget.focusNode,
            validator: (value) {
              final error = widget.validator?.call(value);
              setState(() => errorText = error);
              return error;
            },
            textInputAction: widget.inputAction,
            keyboardType: widget.textInputType,
            obscureText: widget.isPassword ? obscureText : false,
            inputFormatters: widget.inputFormatters,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 15,
              ),
              fillColor: Colors.transparent,
              filled: true,
              hintText: widget.hintText?.tr ?? '',
              hintStyle: widget.hintTextStyle ?? regularLarge.copyWith(color: MyColor.bodyMutedTextColor),
              border: InputBorder.none,
              isDense: true,
              errorMaxLines: 1,
              errorText: null,
              errorStyle: TextStyle(fontSize: 0),
              // prefixIconConstraints: BoxConstraints.loose(Size(50, 50)),
              prefixIcon: widget.prefixIcon,
              suffixIconConstraints: widget.suffixIconConstraints ??
                  const BoxConstraints(
                    maxHeight: 50,
                    maxWidth: 70,
                    minHeight: 40,
                    minWidth: 50,
                  ),
              suffixIcon: widget.isShowSuffixIcon
                  ? widget.isPassword
                      ? GestureDetector(
                          onTap: _toggle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 5.0),
                            child: Center(
                              child: Text(
                                obscureText ? MyStrings.show.tr : MyStrings.hide.tr,
                                style: boldDefault.copyWith(
                                  color: obscureText ? MyColor.primaryColor : MyColor.hintTextColor,
                                  fontSize: Dimensions.fontLarge,
                                ),
                              ),
                            ),
                          ),
                        )
                      : widget.isIcon
                          ? IconButton(
                              onPressed: widget.onSuffixTap,
                              icon: Icon(
                                widget.isSearch
                                    ? Icons.search_outlined
                                    : widget.isCountryPicker
                                        ? Icons.arrow_drop_down_outlined
                                        : Icons.camera_alt_outlined,
                                size: 25,
                                color: MyColor.getPrimaryColor(),
                              ),
                            )
                          : widget.suffixWidget
                  : null,
            ),
            onFieldSubmitted: (text) {
              if (widget.nextFocus != null) {
                FocusScope.of(context).requestFocus(widget.nextFocus);
              }
            },
            onChanged: (text) {
              widget.onChanged!(text);
              if (errorText != null) {
                setState(() => errorText = null);
              }
            },
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0),
            child: Text(
              errorText!,
              style: TextStyle(
                color: Colors.red,
                fontSize: Dimensions.fontSmall,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }

  void _toggle() {
    setState(() {
      obscureText = !obscureText;
    });
  }
}
