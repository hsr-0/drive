import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/data/controller/dashboard/dashboard_controller.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';

/// Fixed server fare. The driver accepts or declines, never proposes a bid.
class OfferBidBottomSheet extends StatelessWidget {
  final RideModel ride;
  const OfferBidBottomSheet({super.key, required this.ride});
  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashBoardController>(builder: (controller) => SafeArea(
      child: Padding(padding: const EdgeInsets.all(20), child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('طلب رحلة قريب منك', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('من: ' + (ride.pickupLocation ?? '-')),
          const SizedBox(height: 4),
          Text('إلى: ' + (ride.destination ?? '-')),
          const SizedBox(height: 18),
          const Text('الأجرة المحددة من منصة بيتي', textAlign: TextAlign.center),
          Text(ride.payableFare.toStringAsFixed(0) + ' د.ع', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: controller.isSendBidLoading ? null : () async {
              await controller.sendBid(ride.id ?? '-1', amount: ride.amount ?? '0',
                onActon: () { if (Get.isBottomSheetOpen ?? false) Get.back(); });
            },
            child: const Text('قبول الرحلة بهذا السعر'),
          ),
          TextButton(
            onPressed: () {
              controller.declineOffer(ride.id ?? '-1');
              Get.back();
            },
            child: const Text('ليس الآن'),
          ),
        ]),
      ),
    ));
  }
}
