import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/buttons/circle_icon_button.dart';

class AttachmentPreviewWidget extends StatelessWidget {
  final String path;
  final Function() onTap;
  final File? file;
  final bool isShowCloseButton;
  final bool isFileImg;

  const AttachmentPreviewWidget({
    super.key,
    required this.path,
    required this.onTap,
    required this.file,
    this.isShowCloseButton = false,
    this.isFileImg = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(Dimensions.space5),
          decoration: const BoxDecoration(),
          child: isFileImg
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      Dimensions.mediumRadius,
                    ),
                    border: Border.all(color: MyColor.borderColor, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.mediumRadius,
                    ),
                    child: Image.file(
                      file!,
                      width: context.width / 5,
                      height: context.width / 5,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : MyUtils.isImage(path)
                  ? MyImageWidget(imageUrl: path, height: 45, width: 45)
                  : MyUtils.isXlsx(path)
                      ? Container(
                          width: context.width / 5,
                          height: context.width / 5,
                          decoration: BoxDecoration(
                            color: MyColor.colorWhite,
                            borderRadius: BorderRadius.circular(
                              Dimensions.mediumRadius,
                            ),
                            border: Border.all(color: MyColor.borderColor, width: 1),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              MyIcons.xlsx,
                              height: 45,
                              width: 45,
                            ),
                          ),
                        )
                      : MyUtils.isDoc(path)
                          ? Container(
                              width: context.width / 5,
                              height: context.width / 5,
                              decoration: BoxDecoration(
                                color: MyColor.colorWhite,
                                borderRadius: BorderRadius.circular(
                                  Dimensions.mediumRadius,
                                ),
                                border: Border.all(color: MyColor.borderColor, width: 1),
                              ),
                              child: Center(
                                child: SvgPicture.asset(MyIcons.doc, height: 45, width: 45),
                              ),
                            )
                          : Container(
                              width: context.width / 5,
                              height: context.width / 5,
                              decoration: BoxDecoration(
                                color: MyColor.colorWhite,
                                borderRadius: BorderRadius.circular(
                                  Dimensions.mediumRadius,
                                ),
                                border: Border.all(color: MyColor.borderColor, width: 1),
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  MyIcons.pdfFile,
                                  height: 45,
                                  width: 45,
                                ),
                              ),
                            ),
        ),
        isShowCloseButton
            ? Positioned(
                right: 0,
                child: CircleIconButton(
                  onTap: onTap,
                  height: Dimensions.space20 + 5,
                  width: Dimensions.space20 + 5,
                  backgroundColor: MyColor.redCancelTextColor,
                  child: const Icon(
                    Icons.close,
                    color: MyColor.colorWhite,
                    size: Dimensions.space15,
                  ),
                ),
              )
            : const SizedBox(),
      ],
    );
  }
}
