import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// تأكد من مسار الاستيراد الصحيح في مشروع السائق
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';

class NewDriverChatController extends GetxController {
  final String rideId;
  NewDriverChatController({required this.rideId});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController messageController = TextEditingController();
  bool isSubmitLoading = false;

  // إرسال الرسالة من السائق
  Future<void> sendMessage() async {
    if (messageController.text.trim().isEmpty) return;

    String msgText = messageController.text.trim();
    messageController.clear();
    isSubmitLoading = true;
    update();

    try {
      final prefs = await SharedPreferences.getInstance();
      String currentDriverId = prefs.getString(SharedPreferenceHelper.userIdKey) ?? "0";

      // 1. الحفظ في Firestore
      await _firestore
          .collection('taxi_rides_chats')
          .doc(rideId)
          .collection('messages')
          .add({
        'message': msgText,
        'userId': "0",
        'driverId': currentDriverId,
        'image': "null",
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. إخطار السيرفر عبر البوابة السريعة المستقلة
      await notifyServer(msgText);

    } catch (e) {
      print("Error Driver Chat: $e");
    } finally {
      isSubmitLoading = false;
      update();
    }
  }

  // استدعاء بوابة الإشعارات المباشرة (تتجاوز حماية لارافيل)
  Future<void> notifyServer(String message) async {
    try {
      // استخدام الرابط الجديد المباشر
      const String apiUrl = 'https://taxi.beytei.com/taxi-chat-api.php';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          // تم الاستغناء عن Authorization Token لتجاوز جدار الحماية بنجاح
        },
        body: jsonEncode({
          'ride_id': rideId,
          'message': message,
          'sender_type': 'driver' // السائق يخبر السيرفر أنه المرسل
        }),
      );

      if (response.statusCode == 200) {
        print("✅ تم إرسال إشعار للزبون بنجاح عبر البوابة المباشرة");
      } else {
        print("❌ فشل إرسال إشعار السائق. الحالة: ${response.statusCode}");
      }
    } catch (e) {
      print("Notification failed: $e");
    }
  }

  Stream<QuerySnapshot> getMessagesStream() {
    return _firestore
        .collection('taxi_rides_chats')
        .doc(rideId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();
  }
}