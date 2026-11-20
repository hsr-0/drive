import 'dart:collection';

import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/data/controller/dashboard/dashboard_controller.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:ovoride_driver/presentation/components/dialog/custom_new_ride_dialog.dart';

class RideQueueManager extends GetxController {
  // Queue to store pending rides
  final Queue<RideQueueItem> _rideQueue = Queue<RideQueueItem>();

  // Flag to check if a dialog is currently showing
  bool _isDialogShowing = false;
  String? _activeRideId;
  final Set<String> _queuedIds = <String>{};

  // Add ride to queue
  void addRideToQueue(RideQueueItem item) {
    final id = item.ride.id ?? '-1';
    if (id == '-1' || !_queuedIds.add(id)) return;
    _rideQueue.add(item);
    printX("Ride added to queue id: ${item.ride.id} . Queue size: ${_rideQueue.length} ");

    // If no dialog is showing, show the next one
    if (!_isDialogShowing) {
      _showNextRide();
    }
  }

  // Show next ride from queue
  void _showNextRide() {
    if (_rideQueue.isEmpty || _isDialogShowing) {
      return;
    }

    _isDialogShowing = true;
    final rideItem = _rideQueue.first;
    _activeRideId = rideItem.ride.id;

    CustomNewRideDialog.newRide(
      ride: rideItem.ride,
      currency: rideItem.currency,
      currencySym: rideItem.currencySym,
      dashboardController: rideItem.dashboardController,
      onBidClick: () async {
        _onDialogDismissed(rideItem.ride.id);
      },
      onCancel: () {
        rideItem.dashboardController.declineOffer(rideItem.ride.id ?? '-1');
        _onDialogDismissed(rideItem.ride.id);
      },
      onDispose: () {
        _onDialogDismissed(rideItem.ride.id);
      },
    );
  }

  // Handle dialog dismissal
  void _onDialogDismissed(String? rideId) {
    if (_activeRideId != rideId || !_isDialogShowing) return;
    // Remove the current ride from queue
    if (_rideQueue.isNotEmpty) {
      _queuedIds.remove(_rideQueue.first.ride.id);
      _rideQueue.removeFirst();
      printX("Ride removed from queue. Remaining: ${_rideQueue.length}");
    }

    _isDialogShowing = false;
    _activeRideId = null;

    // Show next ride after 2 seconds if queue is not empty
    if (_rideQueue.isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), () {
        _showNextRide();
      });
    }
  }

  // Clear all pending rides
  void clearQueue() {
    _rideQueue.clear();
    _queuedIds.clear();
    printX("Queue cleared");
  }

  // Get queue size
  int get queueSize => _rideQueue.length;
}

// Model to hold ride queue item data
class RideQueueItem {
  final RideModel ride;
  final String currency;
  final String currencySym;
  final DashBoardController dashboardController;

  RideQueueItem({
    required this.ride,
    required this.currency,
    required this.currencySym,
    required this.dashboardController,
  });
}
