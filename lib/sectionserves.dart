import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ovoride_driver/core/route/route.dart';
import 'dev/tx.dart';

class ServicesSelectionScreen extends StatefulWidget {
  const ServicesSelectionScreen({super.key});

  @override
  State<ServicesSelectionScreen> createState() => _ServicesSelectionScreenState();
}

class _ServicesSelectionScreenState extends State<ServicesSelectionScreen> {

  @override
  void initState() {
    super.initState();
    // تشغيل الفحوصات عند فتح الشاشة
    _runAppChecks();
  }

  void _runAppChecks() async {
    await _checkForUpdate();
    await _requestReviewIfAppropriate();
  }

  // ---------------------------------------------------------
  // 1. منطق التحديث الإجباري (باستخدام المفتاح الجديد)
  // ---------------------------------------------------------
  Future<void> _checkForUpdate() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      // إعدادات الجلب (Fetch)
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // لجلب التحديث فوراً عند كل تشغيل
      ));

      await remoteConfig.fetchAndActivate();

      // استخراج البيانات باستخدام المفتاح الفريد لتطبيق الخدمات
      final configString = remoteConfig.getString('services_update_config');
      if (configString.isEmpty) return;

      final config = jsonDecode(configString);
      final platformConfig = Platform.isIOS ? config['ios'] : config['android'];

      final minVer = platformConfig['minimum_version'];
      final url = platformConfig['store_url'];

      if (minVer != null) {
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = Version.parse(packageInfo.version);
        final requiredVersion = Version.parse(minVer);

        // إذا كان إصدار التطبيق الحالي أصغر من الإصدار المطلوب
        if (currentVersion < requiredVersion) {
          if (mounted) _showUpdateSheet(url);
        }
      }
    } catch (e) {
      debugPrint('Update Error: $e');
    }
  }

  // واجهة التحديث (مودرن - Bottom Sheet)
  void _showUpdateSheet(String updateUrl) {
    showModalBottomSheet(
      context: context,
      isDismissible: false, // يمنع إغلاق النافذة بالضغط خارجها
      enableDrag: false,    // يمنع سحب النافذة لأسفل لإغلاقها
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.update_rounded, size: 70, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              "تحديث إلزامي",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 10),
            const Text(
              "يتوفر إصدار جديد من تطبيق بيتي خدمات. يرجى التحديث الآن لضمان استمرارية الخدمة بشكل سليم.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () async {
                  final uri = Uri.parse(updateUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text("تحديث الآن", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 2. منطق تقييم التطبيق
  // ---------------------------------------------------------
  Future<void> _requestReviewIfAppropriate() async {
    final InAppReview inAppReview = InAppReview.instance;
    final prefs = await SharedPreferences.getInstance();

    int openCount = (prefs.getInt('services_open_count') ?? 0) + 1;
    await prefs.setInt('services_open_count', openCount);

    // نطلب التقييم عند المرة الخامسة لفتح التطبيق
    if (openCount == 5) {
      if (await inAppReview.isAvailable()) {
        inAppReview.requestReview();
      }
    }
  }

  // ---------------------------------------------------------
  // واجهة المستخدم (UI)
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('منصة بيتي للخدمات',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Cairo')),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildServiceCard(
                title: 'خدمات التاكسي',
                subtitle: 'ابدأ استقبال طلبات الركاب الآن',
                imagePath: 'assets/images/taxi.png',
                color: Colors.blue.shade700,
                onTap: () => Get.toNamed(RouteHelper.splashScreen),
              ),
              const SizedBox(height: 20),
              _buildServiceCard(
                title: 'خدمات التوصيل (مندوب)',
                subtitle: 'توصيل الطلبات والطرود',
                imagePath: 'assets/images/ms.jpg',
                color: Colors.orange.shade800,
                onTap: () => Get.to(() => const DeliveryApp()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            children: [
              Positioned.fill(child: Image.asset(imagePath, fit: BoxFit.cover)),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.95), color.withOpacity(0.2)],
                      begin: Alignment.bottomRight,
                      end: Alignment.topLeft,
                    ),
                  ),
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Cairo')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
