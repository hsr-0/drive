import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../../core/utils/dimensions.dart';
import '../../../../../../core/utils/my_color.dart';
import '../../../../../../core/utils/my_strings.dart';
import '../../../../../../core/utils/style.dart';

class EnableQRCodeWidget extends StatelessWidget {
  final String qrImage;
  final String secret;
  const EnableQRCodeWidget({
    super.key,
    required this.qrImage,
    required this.secret,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: CustomAppCard(
            borderWidth: 1,
            borderColor: MyColor.borderColor,
            child: MyImageWidget(
              imageUrl: qrImage,
              width: 220,
              height: 220,
              boxFit: BoxFit.contain,
            ),
          ),
        ),
        spaceDown(Dimensions.space20),
        Text(
          MyStrings.setupKey.tr,
          style: boldExtraLarge.copyWith(color: MyColor.getHeadingTextColor()),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: Dimensions.space10),
          child: InkWell(
            onTap: () {
              MyUtils.copy(text: secret);
            },
            child: InnerShadowContainer(
              width: double.infinity,
              backgroundColor: MyColor.neutral50,
              borderRadius: Dimensions.largeRadius,
              blur: 6,
              offset: Offset(3, 3),
              shadowColor: MyColor.colorBlack.withValues(alpha: 0.04),
              isShadowTopLeft: true,
              isShadowBottomRight: true,
              padding: EdgeInsetsGeometry.symmetric(
                vertical: Dimensions.space5,
                horizontal: Dimensions.space5,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    Dimensions.defaultRadius - 1,
                  ),
                ),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.space15,
                  vertical: 4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        secret,
                        style: boldExtraLarge.copyWith(
                          fontSize: Dimensions.fontDefault + 5,
                          color: MyColor.colorBlack,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(Dimensions.space5),
                          child: Icon(
                            Icons.copy,
                            color: MyColor.colorGrey.withValues(alpha: 0.5),
                            size: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Center(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: MyStrings.useQRCODETips2.tr,
                  style: regularDefault.copyWith(
                    color: MyColor.getBodyTextColor(),
                  ),
                ),
                TextSpan(
                  text: ' ${MyStrings.download}',
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      final Uri url = Uri.parse(
                        "https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2&hl=en",
                      );

                      if (!await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      )) {
                        throw Exception('Could not launch $url');
                      }
                    },
                  style: boldLarge.copyWith(color: MyColor.getPrimaryColor()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
