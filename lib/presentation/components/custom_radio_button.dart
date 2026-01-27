import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/style.dart';

class CustomRadioButton extends StatefulWidget {
  final String? title;
  final String? selectedValue;
  final int selectedIndex;
  final List<String> list;
  final ValueChanged? onChanged;

  const CustomRadioButton({
    super.key,
    this.title,
    this.selectedIndex = 0,
    this.selectedValue,
    required this.list,
    this.onChanged,
  });

  @override
  State<CustomRadioButton> createState() => _CustomRadioButtonState();
}

class _CustomRadioButtonState extends State<CustomRadioButton> {
  @override
  Widget build(BuildContext context) {
    if (widget.list.isEmpty) {
      return Container();
    }

    return Column(
      children: [
        RadioGroup<int>(
          groupValue: widget.selectedIndex,
          onChanged: (int? newValue) {
            setState(() {
              if (newValue != null) {
                widget.onChanged!(newValue);
              }
            });
          },
          child: Column(
            children: List<RadioListTile<int>>.generate(widget.list.length, (
              int index,
            ) {
              return RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                value: index,
                radioSide: BorderSide(color: MyColor.borderColor, width: 1.5),
                activeColor: MyColor.getPrimaryColor(),
                title: Text(
                  widget.list[index].tr,
                  style: regularDefault.copyWith(
                    color: MyColor.getHeadingTextColor(),
                  ),
                ),
                selected: index == widget.selectedIndex,
              );
            }),
          ),
        ),
      ],
    );
  }
}
