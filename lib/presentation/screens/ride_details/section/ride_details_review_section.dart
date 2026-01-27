import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/ride/ride_details/ride_details_controller.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/bottom_sheet_header_row.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_divider.dart';
import 'package:ovoride_driver/presentation/components/image/custom_svg_picture.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';

class RideDetailsReviewSection extends StatelessWidget {
  const RideDetailsReviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideDetailsController>(
      builder: (controller) {
        return AnnotatedRegionWidget(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const BottomSheetHeaderRow(),
              Align(
                alignment: Alignment.center,
                child: Text(
                  MyStrings.reviewForUser.tr,
                  style: regularDefault.copyWith(
                    fontSize: Dimensions.fontOverLarge - 1,
                  ),
                ),
              ),
              const SizedBox(height: Dimensions.space20),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: MyColor.colorWhite,
                  border: Border.all(color: MyColor.borderColor),
                  shape: BoxShape.circle,
                ),
                child: MyImageWidget(
                  imageUrl: '${UrlContainer.domainUrl}/${controller.userImageUrl}/${controller.ride.user?.avatar}',
                  height: 85,
                  width: 85,
                  radius: 50,
                  isProfile: true,
                  errorWidget: MyLocalImageWidget(
                    imagePath: MyImages.defaultAvatar,
                    radius: 100,
                    height: 85,
                    width: 85,
                  ),
                ),
              ),
              const SizedBox(height: Dimensions.space8),
              Text(
                "${controller.ride.user?.getFullName()}",
                style: regularDefault.copyWith(fontSize: 16),
              ),
              const SizedBox(height: Dimensions.space8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 14,
                        color: MyColor.colorYellow,
                      ),
                      Text(
                        StringConverter.formatNumber(
                          controller.ride.user?.avgRating ?? '0.0',
                        ),
                        style: boldDefault.copyWith(
                          color: MyColor.colorGrey,
                          fontSize: Dimensions.fontDefault,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: MyColor.colorGrey, width: .5),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => MyUtils.launchPhone(controller.ride.user?.mobile ?? ""),
                    child: Row(
                      children: [
                        CustomSvgPicture(
                          image: MyIcons.callIcon,
                          color: MyColor.getBodyTextColor(),
                          height: 15,
                          width: 15,
                        ),
                        const SizedBox(width: Dimensions.space5 - 1),
                        Text(
                          "+${controller.ride.user?.mobile}",
                          style: boldDefault.copyWith(
                            color: MyColor.colorGrey,
                            fontSize: Dimensions.fontDefault,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              CustomDivider(
                space: Dimensions.space10,
                color: MyColor.getBodyTextColor(),
              ),
              const SizedBox(height: Dimensions.space30),
              Text(
                MyStrings.ratingRider.tr,
                style: semiBoldDefault.copyWith(
                  fontSize: Dimensions.fontOverLarge + 2,
                ),
              ),
              const SizedBox(height: Dimensions.space20),
              RatingBar.builder(
                initialRating: controller.rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (rating) {
                  controller.updateRating(rating);
                },
              ),
              const SizedBox(height: Dimensions.space25 - 1),
              Text(
                MyStrings.whatCouldBetter.tr,
                style: mediumDefault.copyWith(
                  fontSize: Dimensions.fontOverLarge - 1,
                ),
              ),
              const SizedBox(height: Dimensions.space12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.space12,
                ),
                child: CustomTextField(
                  onChanged: (v) {},
                  controller: controller.reviewMsgController,
                  hintText: MyStrings.reviewMsgHintText.tr,
                  maxLines: 5,
                ),
              ),
              const SizedBox(height: Dimensions.space30 + 2),
              RoundedButton(
                text: MyStrings.submit,
                textColor: MyColor.colorWhite,
                press: () {
                  if (controller.rating > 0 && controller.reviewMsgController.text.isNotEmpty) {
                    controller.reviewRide(controller.ride.id.toString());
                  } else {
                    CustomSnackBar.error(errorList: [MyStrings.reviewRequired]);
                  }
                },
                isLoading: controller.isReviewLoading,
              ),
            ],
          ),
        );
      },
    );
  }
}
