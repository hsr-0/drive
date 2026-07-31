import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 إضافة ضرورية
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/ride/ride_details/ride_details_controller.dart';
import 'package:ovoride_driver/data/controller/ride/ride_meassage/ride_meassage_controller.dart';
import 'package:ovoride_driver/data/model/global/pusher/pusher_event_response_model.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/data/services/pusher_service.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../../../presentation/components/snack_bar/show_custom_snackbar.dart';

class PusherRideController extends GetxController {
  ApiClient apiClient;
  RideMessageController rideMessageController;
  RideDetailsController rideDetailsController;
  String rideID;

  PusherRideController({
    required this.apiClient,
    required this.rideMessageController,
    required this.rideDetailsController,
    required this.rideID,
  });

  @override
  void onInit() {
    super.onInit();
    PusherManager().addListener(onEvent);
  }

  void onEvent(PusherEvent event) {
    final eventName = event.eventName.toLowerCase().trim();
    printX('Received Event: $eventName ${event.data}');

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(event.data);
    } catch (e) {
      printX('Invalid JSON from Pusher: $e');
      return;
    }
    final model = PusherResponseModel.fromJson(data);
    final eventResponse = PusherResponseModel(
      eventName: eventName,
      channelName: event.channelName,
      data: model.data,
    );

    switch (eventName) {
      case "message_received":
        _handleMessageEvent(eventResponse);
        return;

      case "cash_payment_request":
        _handleCashPayment(eventResponse);
        break;

      case "online_payment_received":
        _handleOnlinePayment(eventResponse);
        break;

      default:
        updateEvent(eventResponse);
        break;
    }
  }

  void _handleMessageEvent(PusherResponseModel eventResponse) {
    if (eventResponse.data?.message != null) {
      if (eventResponse.data!.ride != null && eventResponse.data!.ride!.id != rideID) {
        printX('Message for different ride: ${eventResponse.data!.ride!.id}, current ride: $rideID');
        return;
      }
      if (isRideDetailsPage()) {
        if (rideDetailsController.repo.apiClient.isNotificationAudioEnable()) {
          MyUtils.vibrate();
        }
      }
      rideMessageController.addEventMessage(eventResponse.data!.message!);
    }
  }

  void _handleCashPayment(PusherResponseModel eventResponse) {
    if (isRideDetailsPage()) {
      printX('Showing payment dialog...');
      rideDetailsController.onShowPaymentDialog(Get.context!);
    }
  }

  void _handleOnlinePayment(PusherResponseModel eventResponse) {
    MyUtils.vibrate();
    if (isRideDetailsPage()) {
      if (eventResponse.data!.ride != null && eventResponse.data!.ride!.id != rideID) {
        printX('Message for different ride: ${eventResponse.data!.ride!.id}, current ride: $rideID');
        return;
      }
      rideDetailsController.updateRide(eventResponse.data!.ride!);
    }
    CustomSnackBar.success(successList: [MyStrings.rideCompletedSuccessFully]);
  }

  void updateEvent(PusherResponseModel eventResponse) {
    printX('event.eventName ${eventResponse.eventName}');

    // 🔥 المنطق الجديد: حفظ أو مسح معرف الرحلة بناءً على الحالة
    if (eventResponse.data?.ride != null && eventResponse.data!.ride!.id != null) {
      final String currentRideId = eventResponse.data!.ride!.id.toString();

      // 1. إذا تم قبول العرض أو بدء الالتقاط: احفظ المعرف لتشغيل التتبع
      if (eventResponse.eventName == "bid_accept" || eventResponse.eventName == "pick_up") {
        _saveActiveRideId(currentRideId);
      }

      // 2. إذا انتهت الرحلة أو تم إلغاؤها: امسح المعرف لإيقاف التتبع
      if (eventResponse.eventName == "ride_end" || eventResponse.eventName == "cancel_ride") {
        _clearActiveRideId();
      }
    }

    // الكود الأصلي الخاص بتحديث الواجهة
    if (eventResponse.eventName == "pick_up" ||
        eventResponse.eventName == "ride_end" ||
        eventResponse.eventName == "online-payment-received" ||
        eventResponse.eventName == "bid_accept" ||
        eventResponse.eventName == "cancel_ride") {

      if (eventResponse.eventName == "online-payment-received") {
        CustomSnackBar.success(successList: ["Payment Received"]);
      }
      if (eventResponse.data!.ride != null && eventResponse.data!.ride!.id != rideID) {
        printX('Message for different ride: ${eventResponse.data!.ride!.id}, current ride: $rideID');
        return;
      }
      rideDetailsController.updateRide(eventResponse.data!.ride!);
    }
  }

  // 🔥 دالة جديدة: حفظ معرف الرحلة النشطة
  Future<void> _saveActiveRideId(String rideId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_ride_id', rideId);
      printX("✅ [RIDE TRACKING] تم حفظ معرف الرحلة النشطة: $rideId");
    } catch (e) {
      printX("❌ [RIDE TRACKING] خطأ في حفظ المعرف: $e");
    }
  }

  // 🔥 دالة جديدة: مسح معرف الرحلة عند الانتهاء
  Future<void> _clearActiveRideId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_ride_id');
      printX("🗑️ [RIDE TRACKING] تم مسح معرف الرحلة لانتهائها أو إلغائها");
    } catch (e) {
      printX("❌ [RIDE TRACKING] خطأ في مسح المعرف: $e");
    }
  }

  bool isRideDetailsPage() {
    return Get.currentRoute == RouteHelper.rideDetailsScreen;
  }

  @override
  void onClose() {
    PusherManager().removeListener(onEvent);
    super.onClose();
  }

  Future<void> ensureConnection({String? channelName}) async {
    try {
      var userId = apiClient.sharedPreferences.getString(
        SharedPreferenceHelper.userIdKey,
      ) ?? '';
      await PusherManager().checkAndInitIfNeeded(
        channelName ?? "private-rider-driver-$userId",
      );
    } catch (e) {
      printX("Error ensuring connection: $e");
    }
  }
}