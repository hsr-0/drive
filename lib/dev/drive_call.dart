import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class DriverCallPage extends StatefulWidget {
  final String channelName;
  final String customerName;
  final String customerPhone;
  final String agoraAppId;

  const DriverCallPage({
    super.key,
    required this.channelName,
    required this.customerName,
    required this.customerPhone,
    required this.agoraAppId,
  });

  @override
  State<DriverCallPage> createState() => _DriverCallPageState();
}

class _DriverCallPageState extends State<DriverCallPage> {
  late RtcEngine _engine;
  bool _localUserJoined = false;
  bool _muted = false;
  bool _speaker = true;
  int _callDuration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    print("📞 [AGORA] Initializing Agora Engine...");
    _initAgora();
    _startTimer();
  }

  Future<void> _initAgora() async {
    print("📞 [AGORA] Requesting microphone permission...");
    await [Permission.microphone].request();
    print("✅ [AGORA] Microphone permission granted");

    // 1. إنشاء وتهيئة المحرك
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: widget.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 2. تسجيل معالجات الأحداث
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        // ✅ تفعيل مكبر الصوت هنا بعد الانضمام الناجح للقناة
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("✅ [AGORA] Joined channel successfully: ${widget.channelName}");
          setState(() => _localUserJoined = true);

          // 🔥 تفعيل مكبر الصوت بعد الانضمام
          _engine.setEnableSpeakerphone(true);
          print("✅ [AGORA] Speakerphone enabled after joining channel");
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print("📞 [AGORA] Remote user offline (UID: $remoteUid)");
          _showCallEndedDialog();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          print("📞 [AGORA] Left channel. Duration: ${stats.duration} seconds");
          _showCallEndedDialog();
        },
        onError: (ErrorCodeType err, String msg) {
          print("❌ [AGORA] Error $err: $msg");
        },
      ),
    );

    // 3. تفعيل الصوت وتحديد الدور
    await _engine.enableAudio();
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // 4. الانضمام للقناة (استخدم "" بدلًا من null للـ token)
    print("📞 [AGORA] Joining channel: ${widget.channelName}");
    await _engine.joinChannel(
      token: "", // ✅ هذا هو التعديل المطلوب
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
    print("✅ [AGORA] Join channel request sent");
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showCallEndedDialog() {
    _timer?.cancel();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('انتهت المكالمة'),
          content: Text('مدة المكالمة: ${_formatDuration(_callDuration)}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('موافق'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    try {
      _engine.leaveChannel();
      _engine.release();
      print("✅ [AGORA] Engine released successfully");
    } catch (e) {
      print("⚠️ [AGORA] Error releasing engine: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _engine.leaveChannel();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF202124),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        _engine.leaveChannel();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blue,
                child: const Icon(Icons.person, size: 70, color: Colors.white),
              ),

              const SizedBox(height: 20),

              Text(
                widget.customerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                widget.customerPhone,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _localUserJoined ? "متصل" : "جاري الاتصال...",
                style: TextStyle(
                  color: _localUserJoined ? Colors.green : Colors.white70,
                  fontSize: 16,
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() => _muted = !_muted);
                        _engine.muteLocalAudioStream(_muted);
                        print("📞 [AGORA] Microphone ${_muted ? 'muted' : 'unmuted'}");
                      },
                      icon: Icon(
                        _muted ? Icons.mic_off : Icons.mic,
                        color: _muted ? Colors.red : Colors.white,
                        size: 35,
                      ),
                      padding: const EdgeInsets.all(20),
                      color: const Color(0xFF303134),
                    ),

                    FloatingActionButton(
                      onPressed: () {
                        print("📞 [AGORA] Ending call...");
                        _engine.leaveChannel();
                        Navigator.pop(context);
                      },
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.call_end, color: Colors.white, size: 35),
                    ),

                    IconButton(
                      onPressed: () {
                        setState(() => _speaker = !_speaker);
                        // تبديل مكبر الصوت (بعد الانضمام للقناة)
                        if (_localUserJoined) {
                          _engine.setEnableSpeakerphone(_speaker);
                          print("📞 [AGORA] Speaker ${_speaker ? 'enabled' : 'disabled'}");
                        }
                      },
                      icon: Icon(
                        _speaker ? Icons.volume_up : Icons.volume_off,
                        color: _speaker ? Colors.green : Colors.white,
                        size: 35,
                      ),
                      padding: const EdgeInsets.all(20),
                      color: const Color(0xFF303134),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}