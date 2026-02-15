import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CallPage extends StatefulWidget {
  final String channelName; // سنستخدم رقم الطلب كاسم للقناة
  final String customerName; // اسم الزبون للعرض
  final String customerPhone; // رقم الزبون (للعرض فقط)

  const CallPage({
    super.key,
    required this.channelName,
    required this.customerName,
    required this.customerPhone
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  // 🔴🔴 استبدل هذا بـ App ID الخاص بك من Agora 🔴🔴
  final String _appId = "3924f8eebe7048f8a65cb3bd4a4adcec";

  int? _remoteUid; // معرف الزبون عند انضمامه
  bool _localUserJoined = false;
  late RtcEngine _engine;

  // التحكم بالصوت
  bool _muted = false;
  bool _speaker = false;

  // مشغل صوت الرنين (Toot Toot)
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _callTimeout; // لإنهاء المكالمة إذا لم يرد أحد

  @override
  void initState() {
    super.initState();
    initAgora();
    _playRingingSound();

    // إنهاء المكالمة تلقائياً بعد 45 ثانية إذا لم يرد أحد
    _callTimeout = Timer(const Duration(seconds: 45), () {
      if (_remoteUid == null && mounted) {
        _leave();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد رد...")));
      }
    });
  }

  // تشغيل صوت "توت توت" ليعرف السائق أنه جاري الاتصال
  void _playRingingSound() async {
    // يمكنك وضع ملف صوت رنين في assets وتشغيله
    // await _audioPlayer.play(AssetSource('sounds/calling.mp3'));
    // حالياً سنعتمد على الصمت الانتظاري
  }

  Future<void> initAgora() async {
    // 1. طلب الصلاحيات
    await [Permission.microphone].request();

    // 2. إعداد المحرك
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: _appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 3. الاستماع للأحداث
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() => _remoteUid = remoteUid);
          _audioPlayer.stop(); // إيقاف صوت الرنين عند الرد
          _callTimeout?.cancel(); // إلغاء مؤقت الإنهاء
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          _leave(); // إنهاء المكالمة إذا أغلق الزبون الخط
        },
      ),
    );

    // 4. الانضمام للغرفة
    await _engine.enableAudio();
    await _engine.joinChannel(
      token: "", // اتركه فارغاً (App ID Only Mode)
      channelId: widget.channelName,
      uid: 0, // 0 يعني دع Agora تختار لي ID عشوائي
      options: const ChannelMediaOptions(),
    );
  }

  void _leave() {
    _engine.leaveChannel();
    _engine.release();
    _audioPlayer.stop();
    if(mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _callTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202124), // لون واتساب الداكن تقريباً
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            // صورة ومعلومات الزبون
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              widget.customerName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _remoteUid != null ? "00:05" : "جاري الاتصال...", // هنا يمكن وضع عداد وقت المكالمة
              style: const TextStyle(color: Colors.white54, fontSize: 18),
            ),

            const Spacer(),

            // أزرار التحكم السفلية
            Container(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // زر مكبر الصوت
                  _controlBtn(
                    icon: _speaker ? Icons.volume_up : Icons.volume_off,
                    isActive: _speaker,
                    onTap: () {
                      setState(() => _speaker = !_speaker);
                      _engine.setEnableSpeakerphone(_speaker);
                    },
                  ),

                  // زر كتم الصوت
                  _controlBtn(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    isActive: _muted,
                    onTap: () {
                      setState(() => _muted = !_muted);
                      _engine.muteLocalAudioStream(_muted);
                    },
                  ),

                  // زر إنهاء المكالمة (الأحمر)
                  FloatingActionButton(
                    onPressed: _leave,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 30),
      ),
    );
  }
}
