import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_enums.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/vehicle_verification/vehicle_verification_controller.dart';
import 'package:ovoride_driver/data/model/vehicle_verification/vehicle_verification_model.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/bottom_sheet_header_row.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/custom_bottom_sheet.dart';

class VehicleBottomSheet {
  // model
  static void vehicleModelBottomSheet(
    BuildContext context,
    VehicleVerificationController controller,
  ) {
    CustomBottomSheet(
      child: StatefulBuilder(
        builder: (BuildContext context, setState) {
          if (controller.filteredModelList.isEmpty) {
            controller.filteredModelList = controller.modelList;
          }

          void filterModel(String query) {
            if (query.isEmpty) {
              setState(() {
                // controller.filteredModelList = ["Add As New Model $query"];
                controller.filteredModelList = controller.modelList;
              });
            } else {
              setState(() {
                controller.filteredModelList = controller.modelList
                        .where(
                          (model) => model.name!.toLowerCase().contains(
                                query.toLowerCase(),
                              ),
                        )
                        .toList() +
                    [VerifyElement(name: "Add As New `$query`", id: query)];
              });
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * .8,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: MyColor.getCardBgColor(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const BottomSheetHeaderRow(header: '', bottomSpace: 15),
                const SizedBox(height: 15),
                TextField(
                  controller: controller.brandSearchController,
                  onChanged: filterModel,
                  decoration: InputDecoration(
                    hintText: MyStrings.searchModel.tr,
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MyColor.borderColor),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MyColor.primaryColor),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MyColor.borderColor),
                    ),
                  ),
                  cursorColor: MyColor.primaryColor,
                ),
                const SizedBox(height: 15),
                Flexible(
                  child: ListView.builder(
                    itemCount: controller.filteredModelList.length,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      var item = controller.filteredModelList[index];
                      return GestureDetector(
                        onTap: () {
                          if (item.name!.contains("`")) {
                            printX(item.name!.split('`')[1]);
                            // controller.changeModelColorYearValue(item.split('`')[1], type: VEHICLESELECTEDTYPE.MODEL);
                            controller.changeModelColorYearValue(
                              item,
                              type: VEHICLESELECTEDTYPE.MODEL,
                            );
                          } else {
                            controller.changeModelColorYearValue(
                              item,
                              type: VEHICLESELECTEDTYPE.MODEL,
                            );
                          }
                          // controller.changeModelColorYearValue(item, type: VEHICLESELECTEDTYPE.MODEL);
                          Navigator.pop(context);
                          FocusScopeNode currentFocus = FocusScope.of(context);
                          if (!currentFocus.hasPrimaryFocus) {
                            currentFocus.unfocus();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: MyColor.transparentColor,
                            border: Border(
                              bottom: BorderSide(
                                color: MyColor.colorGrey.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: item.name!.contains("`")
                              ? RichText(
                                  text: TextSpan(
                                    text: item.name!.split('`')[0],
                                    style: regularDefault.copyWith(
                                      color: MyColor.getTextColor(),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: item.name!.split('`')[1].toUpperCase(),
                                        style: semiBoldDefault.copyWith(
                                          color: MyColor.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Text(
                                  item.name ?? "",
                                  style: regularDefault.copyWith(
                                    color: MyColor.getTextColor(),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).customBottomSheet(context);
  }

  // year
  static void vehicleYearBottomSheet(
    BuildContext context,
    VehicleVerificationController controller,
  ) {
    CustomBottomSheet(
      child: StatefulBuilder(
        builder: (BuildContext context, setState) {
          if (controller.filteredYearList.isEmpty) {
            controller.filteredYearList = controller.yearList;
          }

          void filterYear(String query) {
            if (query.isEmpty) {
              setState(() {
                controller.filteredYearList = controller.yearList;
              });
            } else {
              setState(() {
                controller.filteredYearList = controller.yearList
                        .where(
                          (yr) =>
                              yr.name?.toLowerCase().contains(
                                    query.toLowerCase(),
                                  ) ??
                              false,
                        )
                        .toList() +
                    [VerifyElement(name: "Add As New `$query`", id: query)];
              });
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * .8,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: MyColor.getCardBgColor(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const BottomSheetHeaderRow(header: '', bottomSpace: 15),
                const SizedBox(height: 15),
                TextField(
                  controller: controller.brandSearchController,
                  onChanged: filterYear,
                  decoration: InputDecoration(
                    hintText: MyStrings.searchYear.tr,
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MyColor.borderColor),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MyColor.primaryColor),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MyColor.borderColor),
                    ),
                  ),
                  cursorColor: MyColor.primaryColor,
                ),
                const SizedBox(height: 15),
                Flexible(
                  child: ListView.builder(
                    itemCount: controller.filteredYearList.length,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      var item = controller.filteredYearList[index];

                      return GestureDetector(
                        onTap: () {
                          if (item.name?.contains("`") ?? false) {
                            controller.changeModelColorYearValue(
                              item,
                              type: VEHICLESELECTEDTYPE.YEAR,
                            );
                          } else {
                            controller.changeModelColorYearValue(
                              item,
                              type: VEHICLESELECTEDTYPE.YEAR,
                            );
                          }
                          // controller.changeModelColorYearValue(item, type: VEHICLESELECTEDTYPE.MODEL);
                          Navigator.pop(context);
                          FocusScopeNode currentFocus = FocusScope.of(context);
                          if (!currentFocus.hasPrimaryFocus) {
                            currentFocus.unfocus();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: MyColor.transparentColor,
                            border: Border(
                              bottom: BorderSide(
                                color: MyColor.colorGrey.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: item.name?.contains("`") ?? false
                              ? RichText(
                                  text: TextSpan(
                                    text: item.name?.split('`')[0],
                                    style: regularDefault.copyWith(
                                      color: MyColor.getTextColor(),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: item.name?.split('`')[1].toUpperCase(),
                                        style: semiBoldDefault.copyWith(
                                          color: MyColor.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Text(
                                  item.name ?? "",
                                  style: regularDefault.copyWith(
                                    color: MyColor.getTextColor(),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).customBottomSheet(context);
  }

  // color
  static void vehicleColorBottomSheet(
    BuildContext context,
    VehicleVerificationController controller,
  ) {
    CustomBottomSheet(
      child: StatefulBuilder(
        builder: (BuildContext context, setState) {
          if (controller.filteredcolorList.isEmpty) {
            controller.filteredcolorList = controller.filteredcolorList;
          }

          void filterColors(String query) {
            if (query.isEmpty) {
              setState(() {
                controller.filteredcolorList = controller.filteredcolorList;
              });
            } else {
              setState(() {
                controller.filteredcolorList = controller.filteredcolorList
                        .where(
                          (color) =>
                              color.name?.toLowerCase().contains(
                                    query.toLowerCase(),
                                  ) ??
                              false,
                        )
                        .toList() +
                    [VerifyElement(name: "Add As New `$query`", id: query)];
              });
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * .8,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: MyColor.getCardBgColor(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const BottomSheetHeaderRow(header: '', bottomSpace: 15),
                const SizedBox(height: 15),
                TextField(
                  controller: controller.brandSearchController,
                  onChanged: filterColors,
                  decoration: InputDecoration(
                    hintText: MyStrings.searchColor.tr,
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MyColor.borderColor),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MyColor.primaryColor),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MyColor.borderColor),
                    ),
                  ),
                  cursorColor: MyColor.primaryColor,
                ),
                const SizedBox(height: 15),
                Flexible(
                  child: ListView.builder(
                    itemCount: controller.filteredcolorList.length,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      var item = controller.filteredcolorList[index];

                      return GestureDetector(
                        onTap: () {
                          if (item.name?.contains("`") ?? false) {
                            controller.changeModelColorYearValue(
                              item,
                              type: VEHICLESELECTEDTYPE.COLOR,
                            );
                          } else {
                            controller.changeModelColorYearValue(
                              item,
                              type: VEHICLESELECTEDTYPE.COLOR,
                            );
                          }
                          // controller.changeModelColorYearValue(item, type: VEHICLESELECTEDTYPE.MODEL);
                          Navigator.pop(context);
                          FocusScopeNode currentFocus = FocusScope.of(context);
                          if (!currentFocus.hasPrimaryFocus) {
                            currentFocus.unfocus();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: MyColor.transparentColor,
                            border: Border(
                              bottom: BorderSide(
                                color: MyColor.colorGrey.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: item.name?.contains("`") ?? false
                              ? RichText(
                                  text: TextSpan(
                                    text: item.name?.split('`')[0],
                                    style: regularDefault.copyWith(
                                      color: MyColor.getTextColor(),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: item.name?.split('`')[1].toUpperCase(),
                                        style: semiBoldDefault.copyWith(
                                          color: MyColor.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Text(
                                  item.name ?? "",
                                  style: regularDefault.copyWith(
                                    color: MyColor.getTextColor(),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).customBottomSheet(context);
  }
}
