import 'dart:convert';
import 'package:get/get.dart';
import 'package:laravel_reverb/laravel_reverb.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/core/utils/method.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';

/// Coexisting transports: hosted Pusher is kept for unchanged legacy builds.
/// When the server enables Reverb, this bridge keeps the existing PusherEvent
/// consumer API, replacing only the underlying new-client socket.
class PusherManager {
  static final PusherManager _instance = PusherManager._internal();
  factory PusherManager() => _instance;
  PusherManager._internal();

  final ApiClient apiClient = ApiClient(sharedPreferences: Get.find());
  final PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
  final List<void Function(PusherEvent)> _listeners = [];
  final Map<String, Subscription> _subscriptions = {};
  Reverb? _reverb;
  bool _reverbMode = false;
  bool _loadedMode = false;
  bool _legacyReady = false;
  Future<void>? _loading;
  String _channelName = '';

  void addListener(void Function(PusherEvent) listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(void Function(PusherEvent) listener) {
    _listeners.remove(listener);
  }

  bool isConnected() =>
      _reverbMode ? (_reverb?.state == ReverbState.connected) :
      pusher.connectionState.toLowerCase() == 'connected';

  Future<void> init(String channelName) => checkAndInitIfNeeded(channelName);

  Future<void> checkAndInitIfNeeded(String channelName) async {
    if (_loading != null) await _loading;
    if (!_loadedMode) {
      _loading = _selectTransport();
      try { await _loading; } finally { _loading = null; }
    }
    if (_reverbMode) {
      await _connectReverb(channelName);
    } else {
      await _connectLegacy(channelName);
    }
  }

  Future<void> _selectTransport() async {
    _loadedMode = true;
    try {
      final result = await apiClient.request(
        UrlContainer.baseUrl + 'driver/realtime-config', Method.getMethod,
        null, passHeader: true);
      final raw = result.responseJson;
      final data = raw is Map ? raw['data'] : null;
      if (result.statusCode == 200 && data is Map &&
          data['enabled'] == true &&
          (data['key']?.toString().isNotEmpty ?? false) &&
          (data['host']?.toString().isNotEmpty ?? false)) {
        apiClient.initToken();
        _reverb = Reverb(
          host: data['host'].toString(),
          port: int.tryParse(data['port'].toString()) ?? 443,
          appKey: data['key'].toString(),
          useTls: data['tls'] != false,
          authEndpoint: UrlContainer.baseUrl + 'driver/reverb/auth',
          authHeaders: () async {
            apiClient.initToken();
            return <String, String>{
              'Authorization': apiClient.tokenType + ' ' + apiClient.token,
              'Accept': 'application/json',
              'X-Beytei-Taxi-Protocol': '2',
            };
          },
          onError: (error, _) => printX('Taxi Reverb connection error: ' + error.toString()),
        );
        _reverbMode = true;
        _reverb!.onReconnected(() {
          for (final listener in List.of(_listeners)) {
            listener(PusherEvent(
              channelName: '',
              eventName: 'beytei:reconnected',
              data: '{}',
            ));
          }
        });
      }
    } catch (error) {
      printX('Taxi realtime config unavailable. Using original transport: ' + error.toString());
      _reverbMode = false;
    }
  }

  Future<void> _connectReverb(String channelName) async {
    final reverb = _reverb;
    if (reverb == null) return;
    if (reverb.state != ReverbState.connected) {
      await reverb.connect();
    }
    if (_subscriptions.containsKey(channelName)) return;
    final channel = channelName.startsWith('private-')
        ? reverb.private(channelName.substring('private-'.length))
        : reverb.channel(channelName);
    _subscriptions[channelName] = channel.listenAll((event, payload) {
      if (event.startsWith('pusher:') || event.startsWith('pusher_internal:')) return;
      final body = payload is String ? payload : jsonEncode(payload);
      final item = PusherEvent(
        channelName: channelName, eventName: event, data: body);
      for (final fn in List.of(_listeners)) { fn(item); }
    });
  }

  Future<void> _connectLegacy(String channelName) async {
    if (!_legacyReady) {
      final key = apiClient.getPushConfig().appKey ?? '';
      final cluster = apiClient.getPushConfig().cluster ?? '';
      if (key.isEmpty || cluster.isEmpty) return;
      await pusher.init(
        apiKey: key, cluster: cluster,
        onConnectionStateChange: (current, previous) {
          if (current.toLowerCase() == 'disconnected') {
            Future.delayed(const Duration(seconds: 3), () {
              if (!_reverbMode && !isConnected()) {
                _connectLegacy(_channelName);
              }
            });
          }
        },
        onEvent: (event) {
          for (final fn in List.of(_listeners)) { fn(event); }
        },
        onError: (message, code, error) =>
            printX('Legacy taxi socket error: ' + message),
        onSubscriptionError: (message, error) =>
            printX('Legacy taxi subscription error: ' + message),
        onSubscriptionSucceeded: (channel, data) =>
            printX('Legacy taxi channel ready: ' + channel),
        onAuthorizer: onAuthorizer,
      );
      _legacyReady = true;
    }
    _channelName = channelName;
    if (!isConnected()) await pusher.connect();
    if (pusher.getChannel(channelName) == null) {
      await pusher.subscribe(channelName: channelName);
    }
  }

  Future<Map<String, dynamic>?> onAuthorizer(
    String channelName, String socketId, dynamic options) async {
    try {
      final result = await apiClient.request(
        UrlContainer.baseUrl + UrlContainer.pusherAuthenticate + socketId + '/' + channelName,
        Method.postMethod, null, passHeader: true);
      if (result.statusCode == 200 && result.responseJson is Map) {
        return Map<String, dynamic>.from(result.responseJson);
      }
    } catch (error) { printX('Legacy authorization error: ' + error.toString()); }
    return null;
  }

  Future<void> disconnect() async {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _reverb?.disconnect(forget: true);
    if (_legacyReady) await pusher.disconnect();
    _reverbMode = false;
    _loadedMode = false;
    _legacyReady = false;
    _reverb = null;
  }
}
