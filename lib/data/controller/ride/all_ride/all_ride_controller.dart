import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/app_status.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:ovoride_driver/data/model/ride/complete_ride_response_model.dart';
import 'package:ovoride_driver/data/repo/ride/ride_repo.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

class AllRideController extends GetxController {
  RideRepo repo;
  AllRideController({required this.repo});

  late TabController tabController;
  int selectedTab = 0;

  bool isLoading = true;
  String userImagePath = "";
  String defaultCurrency = "";
  String defaultCurrencySymbol = "";
  String username = "";
  int page = 0;

  void changeTab(int tab) async {
    selectedTab = tab;
    if (tabController.index != tab) {
      tabController.animateTo(tab);
    }
    await initialData(shouldLoading: true, tabID: tab, rideType: "");
    update();
  }

  Future<void> initialData({
    bool shouldLoading = true,
    int tabID = 0,
    String rideType = "",
  }) async {
    page = 0;
    defaultCurrency = repo.apiClient.getCurrency();
    defaultCurrencySymbol = repo.apiClient.getCurrency(isSymbol: true);
    username = repo.apiClient.getUserName();
    update();

    String status = tabID == 0
        ? "all"
        : tabID == 1
            ? "accept"
            : tabID == 2
                ? AppStatus.RIDE_ACTIVE
                : tabID == 3
                    ? AppStatus.RIDE_RUNNING
                    : tabID == 4
                        ? AppStatus.RIDE_COMPLETED
                        : AppStatus.RIDE_CANCELED;
    await getAllRide(
      shouldLoading: shouldLoading,
      status: status,
      rideType: rideType,
    );
  }

  List<RideModel> rideList = [];
  String? nextPageUrl;
  Future<void> getAllRide({
    bool shouldLoading = true,
    String status = "",
    String rideType = "",
  }) async {
    try {
      page = page + 1;
      if (page == 1) {
        isLoading = shouldLoading;
        update();
      }

      ResponseModel responseModel = await repo.getRideList(
        page: page.toString(),
        rideType: rideType,
        status: status,
      );
      if (responseModel.statusCode == 200) {
        AllRideResponseModel model = AllRideResponseModel.fromJson(
          (responseModel.responseJson),
        );
        if (model.status == MyStrings.success) {
          if (page == 1) {
            rideList.clear();
          }
          userImagePath = model.data?.userImagePath ?? "";
          nextPageUrl = model.data?.allRides?.nextPageUrl;
          rideList.addAll(model.data?.allRides?.data ?? []);

          update();
        } else {
          CustomSnackBar.error(
            errorList: model.message ?? [MyStrings.somethingWentWrong],
          );
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
    } finally {
      isLoading = false;
      update();
    }
  }

  bool hasNext() {
    return nextPageUrl != null && nextPageUrl!.isNotEmpty && nextPageUrl != 'null' ? true : false;
  }
}
