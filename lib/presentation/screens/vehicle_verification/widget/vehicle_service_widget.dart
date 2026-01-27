import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';

class VehicleServiceWidget extends StatelessWidget {
  final bool isSelected;
  final String image, name;
  final VoidCallback onTap;

  const VehicleServiceWidget({
    super.key,
    this.isSelected = false,
    required this.image,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
        onTap: onTap,
        child: AnimatedContainer(
          margin: EdgeInsetsDirectional.only(end: Dimensions.space15),
          duration: const Duration(milliseconds: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: EdgeInsets.all(Dimensions.space8),
                decoration: BoxDecoration(
                  color: isSelected ? MyColor.primaryColor.withValues(alpha: 0.1) : MyColor.neutral50,
                  borderRadius: BorderRadius.circular(
                    Dimensions.largeRadius,
                  ),
                  border: isSelected ? Border.all(color: MyColor.primaryColor, width: 1.5) : Border.all(color: MyColor.neutral200, width: 1.2),
                ),
                child: MyImageWidget(
                  imageUrl: image,
                  height: Dimensions.space60,
                  width: Dimensions.space60,
                  radius: Dimensions.largeRadius,
                ),
              )
                  .animate(target: isSelected ? 1 : 0.5)
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                  )
                  .fadeIn(),
              spaceDown(Dimensions.space10),
              FittedBox(child: Text(name, style: boldDefault.copyWith())),
            ],
          ),
        ),
      ),
    );
  }
}
