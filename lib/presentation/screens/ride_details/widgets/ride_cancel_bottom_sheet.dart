import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';

import 'package:ovoride_driver/data/controller/ride/ride_details/ride_details_controller.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/bottom_sheet_header_row.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';

class RideCancelBottomSheet extends StatelessWidget {
  final RideModel ride;
  const RideCancelBottomSheet({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideDetailsController>(
      builder: (controller) {
        return Column(
          children: [
            const BottomSheetHeaderRow(),
            const SizedBox(height: Dimensions.space10),
            CustomTextField(
              fillColor: MyColor.colorGrey.withValues(alpha: 0.1),
              hintText: MyStrings.cancelationReason.tr,
              labelText: MyStrings.cancelReason.tr,
              maxLines: 6,
              controller: controller.cancelReasonController,
              onChanged: (c) {},
            ),
            const SizedBox(height: Dimensions.space20),
            const SizedBox(height: Dimensions.space20),
            RoundedButton(
              text: MyStrings.submit.tr,
              isLoading: controller.isCancelBtnLoading,
              press: () {
                if (controller.cancelReasonController.text.isNotEmpty) {
                  controller.cancelRide(ride.id ?? '-1');
                } else {
                  CustomSnackBar.error(errorList: [MyStrings.rideCancelMsg.tr]);
                }
              },
            ),
            const SizedBox(height: Dimensions.space10),
          ],
        );
      },
    );
  }
}
