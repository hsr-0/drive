import 'package:flutter/material.dart';








class ContestModel {
  final bool hasActiveContest;
  final String title;
  final int targetRides;
  final int completedRides;
  final String rewardAmount;
  final double progressPercentage;

  ContestModel({
    required this.hasActiveContest,
    this.title = '',
    this.targetRides = 0,
    this.completedRides = 0,
    this.rewardAmount = '0',
    this.progressPercentage = 0.0,
  });

  factory ContestModel.fromJson(Map<String, dynamic> json) {
    // التحقق مما إذا كان هناك مسابقة نشطة
    bool active = json['data']?['has_active_contest'] ?? false;

    if (!active) {
      return ContestModel(hasActiveContest: false);
    }

    var contestData = json['data']['contest'];
    var progressData = json['data']['progress'];

    return ContestModel(
      hasActiveContest: true,
      title: contestData['title'] ?? 'مسابقة',
      targetRides: contestData['target_rides'] ?? 0,
      completedRides: progressData['completed_rides'] ?? 0,
      rewardAmount: contestData['reward_amount'].toString(),
      progressPercentage: (progressData['completed_rides'] / contestData['target_rides']).clamp(0.0, 1.0),
    );
  }
}

class ContestProgressCard extends StatelessWidget {
  final String title;
  final int targetRides;
  final int completedRides;
  final String rewardAmount;
  final double progressPercentage;

  const ContestProgressCard({
    Key? key,
    required this.title,
    required this.targetRides,
    required this.completedRides,
    required this.rewardAmount,
    required this.progressPercentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // التدرج اللوني السمائي العصري
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00B4D8), // سمائي فاتح ومشرق
            Color(0xFF0077B6), // أزرق هادئ للعمق
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B4D8).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // القسم العلوي: العنوان والأيقونة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.amberAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo', // تأكد من استخدام خطك المفضل
                    ),
                  ),
                ],
              ),
              // قيمة الجائزة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$rewardAmount د.ع',
                  style: const TextStyle(
                    color: Color(0xFF0077B6),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          // شريط التقدم (Progress Bar)
          Stack(
            children: [
              // الخلفية الداكنة للشريط
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // الشريط المتحرك
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    height: 12,
                    width: constraints.maxWidth * progressPercentage,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 15),

          // النصوص السفلية (الرحلات المكتملة والمتبقية)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الرحلات: $completedRides / $targetRides',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                progressPercentage >= 1.0
                    ? '🎉 مبروك بطلنا!'
                    : 'باقي ${targetRides - completedRides} رحلة',
                style: TextStyle(
                  color: progressPercentage >= 1.0 ? Colors.amberAccent : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
