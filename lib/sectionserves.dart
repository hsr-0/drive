import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
// 👇 تأكد أن هذا الملف يحتوي على كلاس DeliveryApp الذي برمجناه سابقاً
import 'dev/tx.dart';

class ServicesSelectionScreen extends StatelessWidget {
  const ServicesSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('منصة بيتي للخدمات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView( // إضافة سكرول لتجنب مشاكل الشاشات الصغيرة
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // بطاقة خدمات التاكسي
              _buildServiceCard(
                title: 'خدمات التاكسي',
                subtitle: 'ابدأ استقبال طلبات الركاب الآن',
                imagePath: 'assets/images/taxi.png',
                color: Colors.blue.shade700,
                onTap: () {
                  // 🔥 التعديل الأول: الانتقال إلى السبلاش لفحص تسجيل الدخول
                  // نستخدم toNamed وليس offAllNamed لنسمح للسائق بالعودة لهذه الشاشة إذا أراد
                  Get.toNamed(RouteHelper.splashScreen);
                },
              ),
              const SizedBox(height: 20),

              // بطاقة خدمات التوصيل
              _buildServiceCard(
                title: 'خدمات التوصيل (مندوب)',
                subtitle: 'توصيل الطلبات والطرود',
                imagePath: 'assets/images/ms.jpg',
                color: Colors.orange.shade800,
                onTap: () {
                  // 🔥 التعديل الثاني: الانتقال المباشر لتطبيق الدلفري
                  Get.to(() => const DeliveryApp());
                },
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // الخلفية (صورة + لون)
              Positioned.fill(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  // إضافة معالجة في حال عدم وجود الصورة لكي لا ينهار التطبيق
                  errorBuilder: (context, error, stackTrace) => Container(color: color.withOpacity(0.2)),
                ),
              ),
              // التظليل والنصوص
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.9), color.withOpacity(0.3)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Cairo'),
                      ),
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
