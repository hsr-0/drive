import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/date_converter.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/review/review_controller.dart';
import 'package:ovoride_driver/data/repo/review/review_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/custom_svg_picture.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/no_data.dart';
import 'package:ovoride_driver/presentation/components/shimmer/transaction_card_shimmer.dart';

class UserReviewHistory extends StatefulWidget {
  const UserReviewHistory({super.key});

  @override
  State<UserReviewHistory> createState() => _UserReviewHistoryState();
}

class _UserReviewHistoryState extends State<UserReviewHistory> {
  @override
  void initState() {
    Get.put(ReviewRepo(apiClient: Get.find()));
    final controller = Get.put(ReviewController(repo: Get.find()));
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((t) {
      if (Get.arguments != null) {
        controller.getReviewByUserId(Get.arguments.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegionWidget(
      child: GetBuilder<ReviewController>(
        builder: (controller) {
          return Scaffold(
            backgroundColor: MyColor.secondaryScreenBgColor,
            appBar: CustomAppBar(
              title: controller.rider?.getFullName() ?? MyStrings.rider.tr,
            ),
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: Dimensions.space16),
              child: Column(
                children: [
                  spaceDown(Dimensions.space20),
                  Container(
                    decoration: BoxDecoration(
                      color: MyColor.getCardBgColor(),
                      boxShadow: MyUtils.getCardShadow(),
                      borderRadius: BorderRadius.circular(
                        Dimensions.moreRadius,
                      ),
                    ),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.space16,
                      vertical: Dimensions.space16,
                    ),
                    child: controller.isLoading
                        ? TransactionCardShimmer()
                        : Row(
                            children: [
                              MyImageWidget(
                                imageUrl: '${controller.userImagePath}/${controller.rider?.avatar}',
                                height: Dimensions.space50,
                                width: Dimensions.space50,
                                radius: Dimensions.radiusHuge,
                                isProfile: true,
                              ),
                              spaceSide(Dimensions.space10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${controller.rider?.getFullName()}',
                                      style: semiBoldDefault.copyWith(
                                        color: MyColor.getHeadingTextColor(),
                                        fontSize: Dimensions.fontTitleLarge,
                                      ),
                                    ),
                                    spaceDown(Dimensions.space3),
                                    Row(
                                      children: [
                                        CustomSvgPicture(
                                          image: MyIcons.email,
                                          fit: BoxFit.contain,
                                          color: MyColor.primaryColor,
                                          height: Dimensions.fontLarge,
                                        ),
                                        spaceSide(Dimensions.space5),
                                        Expanded(
                                          child: Text(
                                            controller.rider?.email ?? "",
                                            style: regularDefault.copyWith(
                                              color: MyColor.getBodyTextColor(),
                                              fontSize: Dimensions.fontDefault,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  RatingBar.builder(
                                    initialRating: double.tryParse(
                                          controller.rider?.avgRating ?? "0",
                                        ) ??
                                        0,
                                    minRating: 1,
                                    direction: Axis.horizontal,
                                    allowHalfRating: true,
                                    itemCount: 5,
                                    itemPadding: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                    ),
                                    itemSize: Dimensions.fontOverLarge,
                                    itemBuilder: (context, _) => const Icon(
                                      Icons.star_rate_rounded,
                                      color: MyColor.colorOrange,
                                    ),
                                    ignoreGestures: true,
                                    onRatingUpdate: (v) {},
                                  ),
                                  spaceDown(Dimensions.space5),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${MyStrings.avgRating.tr} ',
                                          style: regularDefault.copyWith(
                                            color: MyColor.getBodyTextColor().withValues(alpha: 0.8),
                                            fontSize: Dimensions.fontDefault,
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' ${(double.tryParse(controller.rider?.avgRating ?? "0") ?? 0)}'.toCapitalized(),
                                          style: boldDefault.copyWith(
                                            color: MyColor.getHeadingTextColor(),
                                            fontSize: Dimensions.fontLarge,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  spaceDown(Dimensions.space15),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      MyStrings.reviews.tr.toUpperCase(),
                      style: boldOverLarge.copyWith(
                        color: MyColor.bodyMutedTextColor,
                      ),
                    ),
                  ),
                  spaceDown(Dimensions.space10),
                  Expanded(
                    child: controller.isLoading
                        ? ListView.separated(
                            itemCount: 20,
                            separatorBuilder: (context, index) => const SizedBox(height: Dimensions.space10),
                            itemBuilder: (context, index) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: MyColor.getCardBgColor(),
                                  boxShadow: MyUtils.getCardShadow(),
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.moreRadius,
                                  ),
                                ),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Dimensions.space16,
                                  vertical: Dimensions.space16,
                                ),
                                child: TransactionCardShimmer(),
                              );
                            },
                          )
                        : (controller.reviews.isEmpty && controller.isLoading == false)
                            ? NoDataWidget(margin: 6)
                            : ListView.builder(
                                itemCount: controller.reviews.length,
                                itemBuilder: (context, index) {
                                  final review = controller.reviews[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: MyColor.getCardBgColor(),
                                      boxShadow: MyUtils.getCardShadow(),
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.moreRadius,
                                      ),
                                    ),
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Dimensions.space16,
                                      vertical: Dimensions.space16,
                                    ),
                                    margin: EdgeInsets.only(
                                      bottom: Dimensions.space16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            MyImageWidget(
                                              imageUrl: '${controller.driverImagePath}/${review.ride?.driver?.avatar}',
                                              height: Dimensions.space50,
                                              width: Dimensions.space50,
                                              radius: Dimensions.radiusHuge,
                                              isProfile: true,
                                            ),
                                            SizedBox(width: Dimensions.space10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '${review.ride?.driver?.getFullName().toCapitalized()}',
                                                          style: boldMediumLarge.copyWith(
                                                            color: MyColor.getHeadingTextColor(),
                                                            fontSize: Dimensions.fontTitleLarge,
                                                          ),
                                                        ),
                                                      ),
                                                      spaceSide(Dimensions.space10),
                                                      Text(
                                                        DateConverter.estimatedDate(
                                                          DateTime.tryParse(
                                                                '${review.createdAt}',
                                                              ) ??
                                                              DateTime.now(),
                                                          formatType: DateFormatType.onlyDate,
                                                        ),
                                                        style: boldLarge.copyWith(
                                                          color: MyColor.getBodyTextColor(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(
                                                    height: Dimensions.space5,
                                                  ),
                                                  RatingBar.builder(
                                                    initialRating: StringConverter.formatDouble(
                                                      review.rating ?? '0',
                                                    ),
                                                    minRating: 1,
                                                    direction: Axis.horizontal,
                                                    allowHalfRating: false,
                                                    itemCount: 5,
                                                    itemPadding: const EdgeInsets.symmetric(
                                                      horizontal: 0,
                                                    ),
                                                    itemSize: Dimensions.fontExtraLarge,
                                                    itemBuilder: (context, _) => const Icon(
                                                      Icons.star_rate_rounded,
                                                      color: MyColor.colorOrange,
                                                    ),
                                                    ignoreGestures: true,
                                                    onRatingUpdate: (v) {},
                                                  ),
                                                  SizedBox(
                                                    height: Dimensions.space5,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        spaceDown(Dimensions.space10),
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
                                            vertical: Dimensions.space16,
                                            horizontal: Dimensions.space16,
                                          ),
                                          child: Align(
                                            alignment: AlignmentDirectional.centerStart,
                                            child: Text(
                                              review.review ?? '',
                                              style: lightDefault.copyWith(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
