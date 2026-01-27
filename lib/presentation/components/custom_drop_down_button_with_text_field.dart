import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';

class CustomDropDownWithTextField extends StatefulWidget {
  final String? title, selectedValue;
  final List<String>? list;
  final ValueChanged? onChanged;

  const CustomDropDownWithTextField({
    super.key,
    this.title,
    this.selectedValue,
    this.list,
    this.onChanged,
  });

  @override
  State<CustomDropDownWithTextField> createState() => _CustomDropDownWithTextFieldState();
}

class _CustomDropDownWithTextFieldState extends State<CustomDropDownWithTextField> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    widget.list?.removeWhere((element) => element.isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InnerShadowContainer(
          width: double.infinity,
          backgroundColor: MyColor.neutral50,
          borderRadius: Dimensions.largeRadius,
          blur: 6,
          offset: Offset(3, 3),
          shadowColor: MyColor.colorBlack.withValues(alpha: 0.04),
          isShadowTopLeft: true,
          isShadowBottomRight: true,
          padding: EdgeInsetsGeometry.symmetric(
            vertical: Dimensions.space10,
            horizontal: Dimensions.space16,
          ),
          child: DropdownButton(
            isExpanded: true,
            underline: Container(),
            hint: Text(
              widget.selectedValue?.tr ?? '',
              style: regularDefault.copyWith(color: MyColor.colorBlack),
            ), // Not necessary for Option 1
            value: widget.selectedValue,
            dropdownColor: MyColor.colorWhite,
            onChanged: widget.onChanged,
            items: widget.list!.map((value) {
              return DropdownMenuItem(
                value: value,
                child: Text(
                  value.tr,
                  style: regularDefault.copyWith(color: MyColor.colorBlack),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
