import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CallService {
  static const String _appId = "3924f8eebe7048f8a65cb3bd4a4adcec"; // ⚠️ غيّر هذا بـ App ID الخاص بك
  static const String _baseUrl = 'https://banner.beytei.com/wp-json';

  static Future<bool> initiateCall(String token, String orderId, String channelName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/taxi/v3/call/notify-customer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'order_ref': orderId,
          'channel_name': channelName,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<RtcEngine> createEngine() async {
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: _appId));
    await engine.enableAudio();
    return engine;
  }
}