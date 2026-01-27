import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';

class StatusWidget extends StatelessWidget {
  final String status;
  final Color color;

  const StatusWidget({super.key, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomAppCard(
      radius: Dimensions.largeRadius,
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.space6,
        horizontal: Dimensions.space10,
      ),
      backgroundColor: color.withValues(alpha: .1),
      borderColor: color,
      child: Text(status.tr, style: boldLarge.copyWith(color: color)),
    );
  }
}
