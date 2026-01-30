import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/model/authorization/authorization_response_model.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:ovoride_driver/data/model/dashboard/dashboard_response_model.dart';
import 'package:ovoride_driver/data/model/global/user/global_driver_model.dart';
import 'package:ovoride_driver/data/repo/dashboard/dashboard_repo.dart';
import 'package:ovoride_driver/environment.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:ovoride_driver/presentation/screens/dashboard/forground_task_widget.dart';

import '../../../core/utils/url_container.dart';

class DashBoardController extends GetxController {
  DashBoardRepo repo;
  DashBoardController({required this.repo});
  TextEditingController bidAmountController = TextEditingController();

  String? profileImageUrl;
  bool isLoading = true;
  Position? currentPosition;
  String currentAddress = "${MyStrings.loading.tr}...";
  bool userOnline = false;
  String? nextPageUrl;
  int page = 0;
  bool isDriverVerified = true;
  bool isVehicleVerified = true;

  bool isVehicleVerificationPending = false;
  bool isDriverVerificationPending = false;

  String currency = '';
  String currencySym = '';
  String userImagePath = '';

  Future<void> initialData({bool shouldLoad = true}) async {
    isLoading = shouldLoad;
    page = 0;
    nextPageUrl;
    bidAmountController.text = '';
    currency = repo.apiClient.getCurrency();
    currencySym = repo.apiClient.getCurrency(isSymbol: true);
    update();
    await Future.wait([fetchLocation(), loadData(shouldLoad: shouldLoad)]);
    isLoading = false;
    update();
  }

  GlobalDriverInfoModel driver = GlobalDriverInfoModel(id: '-1');

  // Start location permission check but don't await yet
  Future<void> fetchLocation() async {
    bool hasPermission = await MyUtils.checkAppLocationPermission(
      onsuccess: () {
        initialData();
      },
    );
    printX(hasPermission);
    if (hasPermission) {
      getCurrentLocationAddress();
      update(); // Ensure UI reflects added location
    }
  }

  Future<void> getCurrentLocationAddress() async {
    try {
      final GeolocatorPlatform geolocator = GeolocatorPlatform.instance;
      currentPosition = await geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );

      if (currentPosition != null) {
        if (Environment.addressPickerFromGoogleMapApi) {
          currentAddress = await repo.getActualAddress(currentPosition!.latitude, currentPosition!.longitude) ?? 'Unknown location..';
        } else {
          // Use local reverse geocoding
          final placemarks = await placemarkFromCoordinates(currentPosition!.latitude, currentPosition!.longitude);
          if (placemarks.isNotEmpty) {
            currentAddress = _formatAddress(placemarks.first);
          } else {
            currentAddress = 'Unknown location..';
          }
        }
      }
      update();
    } catch (e) {
      printX("Error: $e");
      CustomSnackBar.error(
        errorList: [MyStrings.somethingWentWrongWhileTakingLocation],
      );
    }
  }

  /// Format address from placemark components
  String _formatAddress(Placemark placemark) {
    // Safely format address components, checking for nulls
    final street = placemark.street ?? '';
    final subLocality = placemark.subLocality ?? '';
    final locality = placemark.locality ?? '';
    final country = placemark.country ?? '';

    return [
      street,
      subLocality,
      locality,
      country,
    ].where((part) => part.isNotEmpty).join(', ');
  }

  List<RideModel> rideList = [];
  List<RideModel> pendingRidesList = [];
  RideModel? runningRide;

  Future<void> loadData({bool shouldLoad = true}) async {
    try {
      page = page + 1;
      if (page == 1) {
        isLoading = shouldLoad;
        update();
      }

      ResponseModel responseModel = await repo.getDashboardData(
        page: page.toString(),
      );

      if (responseModel.statusCode == 200) {
        DashBoardRideResponseModel model = DashBoardRideResponseModel.fromJson(
          (responseModel.responseJson),
        );
        if (model.status == MyStrings.success) {
          nextPageUrl = model.data?.ride?.nextPageUrl;
          userImagePath = '${UrlContainer.domainUrl}/${model.data?.userImagePath}';
          if (page == 1) {
            rideList.clear();
          }
          rideList.addAll(model.data?.ride?.data ?? []);

          pendingRidesList = model.data?.pendingRides ?? [];

          isDriverVerified = model.data?.driverInfo?.dv == "1" ? true : false;
          isVehicleVerified = model.data?.driverInfo?.vv == "1" ? true : false;

          isVehicleVerificationPending = model.data?.driverInfo?.vv == "2" ? true : false;
          isDriverVerificationPending = model.data?.driverInfo?.dv == "2" ? true : false;

          userOnline = model.data?.driverInfo?.onlineStatus == "1" ? true : false;
          startForegroundTask();
          repo.apiClient.setOnlineStatus(userOnline);
          driver = model.data?.driverInfo ?? GlobalDriverInfoModel(id: '-1');
          runningRide = model.data?.runningRide;
          repo.apiClient.sharedPreferences.setString(
            SharedPreferenceHelper.userProfileKey,
            model.data?.driverInfo?.imageWithPath ?? '',
          );

          profileImageUrl = "${UrlContainer.domainUrl}/${model.data?.driverImagePath}/${model.data?.driverInfo?.image}";

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
      printE(e);
    } finally {
      isLoading = false;
      update();
    }
  }

  bool hasNext() {
    return nextPageUrl != null && nextPageUrl!.isNotEmpty && nextPageUrl != 'null' ? true : false;
  }

  // 🔥🔥🔥 تم تحديث دالة sendBid لتنقلك مباشرة لإدخال OTP 🔥🔥🔥
  bool isSendBidLoading = false;
  Future<void> sendBid(
      String rideId, {
        String? amount,
        VoidCallback? onActon,
      }) async {
    isSendBidLoading = true;
    update();

    try {
      ResponseModel responseModel = await repo.createBid(
        amount: amount?.toString() ?? "",
        id: rideId,
      );
      if (responseModel.statusCode == 200) {
        AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
          (responseModel.responseJson),
        );

        if (model.status == "success") {
          // 1. إغلاق النافذة المنبثقة لتقديم العرض إذا كانت مفتوحة
          if (onActon != null) {
            onActon();
          }

          // 2. الانتقال المباشر والفوري لصفحة تفاصيل الرحلة
          // (حيث سيتمكن السائق من رؤية الخريطة وإدخال OTP)
          Get.toNamed(RouteHelper.rideDetailsScreen, arguments: rideId);

          // 3. تحديث البيانات في الخلفية لتكون جاهزة عند العودة
          initialData(shouldLoad: false);

        } else {
          CustomSnackBar.error(
            errorList: model.message ?? [MyStrings.somethingWentWrong],
            dismissAll: false,
          );
        }
      } else {
        CustomSnackBar.error(
          errorList: [responseModel.message],
          dismissAll: false,
        );
      }
    } catch (e) {
      printX(e);
    } finally {
      isSendBidLoading = false;
      update();
    }
  }

  void updateMainAmount(double amount) {
    bidAmountController.text = StringConverter.formatNumber(amount.toString());
    update();
  }

  //Driver Online Status Change
  bool isChangingOnlineStatusLoading = false;
  Future<void> onlineStatusSubmit({bool isFromRideDetails = false}) async {
    try {
      ResponseModel responseModel = await repo.onlineStatus(
        lat: currentPosition?.latitude.toString() ?? "",
        long: currentPosition?.longitude.toString() ?? "",
      );
      if (responseModel.statusCode == 200) {
        AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
          (responseModel.responseJson),
        );
        if (model.status == MyStrings.success) {
          repo.apiClient.setOnlineStatus(
            model.data?.online.toString() == 'true',
          );
          if (model.data?.online.toString() == 'true') {
            userOnline = true;
          } else {
            userOnline = false;
          }
          startForegroundTask();
          isChangingOnlineStatusLoading = false;
          await loadData(shouldLoad: true);
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
      printE(e);
    } finally {
      isChangingOnlineStatusLoading = false;
      update();
    }
  }

  Future<void> startForegroundTask() async {
    try {
      if (userOnline) {
        await foregroundTaskKey.currentState?.startForegroundTask();
      } else {
        await foregroundTaskKey.currentState?.stopForegroundTask();
      }
    } catch (e) {
      printE(e);
    }
  }

  Future<void> changeOnlineStatus(bool value) async {
    bool hasPermission = await MyUtils.checkAppLocationPermission(
      onsuccess: () async {
        await onlineStatusSubmit();
      },
    );
    printX(hasPermission);
    if (hasPermission) {
      userOnline = value;
      update();
      await onlineStatusSubmit();
      update(); // Ensure UI reflects added location
    }
  }
}