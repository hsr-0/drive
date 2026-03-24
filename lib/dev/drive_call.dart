import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

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
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _initAgora();
    _startTimer();
  }

  Future<void> _initAgora() async {
    // اهتزاز عند بدء المكالمة (مثل الواتساب)
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500);
    }

    // طلب صلاحية المايكروفون
    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _hasError = true;
        _errorMessage = "يرجى منح صلاحية المايكروفون في إعدادات الجهاز";
        _isLoading = false;
      });
      return;
    }

    try {
      // إنشاء محرك Agora
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: widget.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // تسجيل معالجات الأحداث
      _engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (mounted) {
            setState(() => _localUserJoined = true);
            // 🔥 تفعيل السماعة فور الانضمام للقناة (الحل الأهم)
            _engine.setEnableSpeakerphone(true);
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (mounted && !_hasError) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          if (mounted && _localUserJoined) {
            _showCallEndedDialog("الزبون أنهى المكالمة");
          }
        },
        onError: (ErrorCodeType err, String msg) {
          if (mounted && !_hasError) {
            setState(() {
              _hasError = true;
              _errorMessage = "خطأ في الاتصال: $msg";
              _isLoading = false;
            });
          }
        },
      ));

      // تفعيل الصوت وتحديد الدور
      await _engine.enableAudio();
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // الانضمام للقناة (استخدم "" بدل null للـ token)
      await _engine.joinChannel(
        token: "",
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(),
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "فشل في بدء المكالمة: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _localUserJoined) {
        setState(() => _callDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showCallEndedDialog(String message) {
    _timer?.cancel();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.call_end, color: Colors.red),
              SizedBox(width: 10),
              Text("انتهت المكالمة"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 10),
              Text("المدة: ${_formatDuration(_callDuration)}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // إغلاق الـ Dialog
                Navigator.pop(context); // الرجوع للشاشة السابقة
              },
              child: const Text("موافق", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _engine.muteLocalAudioStream(_muted);
  }

  void _toggleSpeaker() {
    setState(() => _speaker = !_speaker);
    _engine.setEnableSpeakerphone(_speaker);
  }

  void _endCall() async {
    _timer?.cancel();

    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      print("Error releasing Agora engine: $e");
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    try {
      _engine.leaveChannel();
      _engine.release();
    } catch (e) {
      print("Error in dispose: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _endCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F2027),
        body: SafeArea(
          child: Column(
            children: [
              // شريط الحالة العلوي
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _endCall,
                    ),
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _speaker ? Icons.volume_up : Icons.volume_off,
                        color: _speaker ? Colors.green : Colors.white70,
                        size: 28,
                      ),
                      onPressed: _toggleSpeaker,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // معلومات المتصل
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.grey.shade800,
                      child: const Icon(
                        Icons.person,
                        size: 70,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  Text(
                    widget.customerName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    widget.customerPhone,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // حالة الاتصال
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: _hasError
                          ? Colors.red.withOpacity(0.2)
                          : (_localUserJoined
                          ? Colors.green.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: _hasError
                            ? Colors.red
                            : (_localUserJoined ? Colors.green : Colors.blue),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasError
                              ? Icons.error
                              : (_localUserJoined ? Icons.check_circle : Icons.access_time),
                          color: _hasError
                              ? Colors.red
                              : (_localUserJoined ? Colors.green : Colors.blue),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _hasError
                              ? _errorMessage
                              : (_localUserJoined ? "متصل الآن" : "جاري الاتصال..."),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 3),

              // لوحة التحكم
              Container(
                padding: const EdgeInsets.only(bottom: 40, top: 25),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // أزرار التحكم
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // زر كتم المايكروفون
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: _muted ? Colors.red.withOpacity(0.2) : Colors.white10,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _muted ? Colors.red : Colors.white70,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  _muted ? Icons.mic_off : Icons.mic,
                                  color: _muted ? Colors.red : Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _muted ? "إلغاء الكتم" : "كتم",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        // زر إنهاء المكالمة (الأحمر الكبير)
                        GestureDetector(
                          onTap: _endCall,
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.shade400,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),

                        // زر مكبر الصوت
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _toggleSpeaker,
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: _speaker ? Colors.green.withOpacity(0.2) : Colors.white10,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _speaker ? Colors.green : Colors.white70,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  _speaker ? Icons.volume_up : Icons.volume_down,
                                  color: _speaker ? Colors.green : Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _speaker ? "إيقاف السماعة" : "تفعيل السماعة",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // رسالة إرشادية
                    if (!_localUserJoined && !_hasError)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          "في انتظار اتصال الزبون...\nتأكد من رفع صوت الجهاز",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
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
