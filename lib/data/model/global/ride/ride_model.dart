import 'package:get/utils.dart';
import 'package:ovoride_driver/data/model/global/ride/app_service_model.dart';
import 'package:ovoride_driver/data/model/global/user/global_driver_model.dart';
import 'package:ovoride_driver/data/model/global/user/global_user_model.dart';
import 'package:ovoride_driver/data/model/global/user/review_model.dart';

class RideModel {
  String? id;
  String? uid;
  String? rideType;
  String? userId;
  String? driverId;
  String? serviceId;
  String? pickupLocation;
  String? pickupLatitude;
  String? pickupLongitude;
  String? destination;
  String? duration;
  String? distance;
  String? destinationLatitude;
  String? destinationLongitude;
  String? recommendAmount;
  String? minAmount;
  String? maxAmount;
  String? offerAmount;
  String? isIntercity;
  String? note;
  String? cancelReason;
  String? canceledUserType;
  String? cancelDate;
  String? numberOfPassenger;
  String? otp;
  String? otpAccept;
  String? completedAt;
  String? pickupDateTime;
  String? isAccepted;
  String? isRunning;
  String? amount;
  String? charge;
  String? appliedCouponId;
  String? status;
  String? paymentType;
  String? paymentStatus;
  String? cashPayment;
  String? gatewayCurrencyId;
  String? createdAt;
  String? updatedAt;
  String? bidsCount;
  String? userReviewCount;
  String? startTime;
  String? endTime;

  GlobalUser? user;
  GlobalDriverInfoModel? driver;
  AppService? service;
  UserReview? userReview;
  UserReview? driverReview;

  RideModel({
    this.id,
    this.rideType,
    this.uid,
    this.userId,
    this.driverId,
    this.serviceId,
    this.pickupLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destination,
    this.duration,
    this.distance,
    this.destinationLatitude,
    this.destinationLongitude,
    this.recommendAmount,
    this.minAmount,
    this.maxAmount,
    this.offerAmount,
    this.isIntercity,
    this.note,
    this.cancelReason,
    this.canceledUserType,
    this.cancelDate,
    this.numberOfPassenger,
    this.otp,
    this.otpAccept,
    this.completedAt,
    this.pickupDateTime,
    this.isAccepted,
    this.isRunning,
    this.amount,
    this.charge,
    this.appliedCouponId,
    this.status,
    this.paymentType,
    this.paymentStatus,
    this.cashPayment,
    this.gatewayCurrencyId,
    this.createdAt,
    this.updatedAt,
    this.bidsCount,
    this.userReviewCount,
    this.user,
    this.driver,
    this.service,
    this.userReview,
    this.driverReview,
    this.startTime,
    this.endTime,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) => RideModel(
        id: json["id"].toString(),
        rideType: json["ride_type"].toString(),
        uid: json["uid"].toString(),
        userId: json["user_id"].toString(),
        driverId: json["driver_id"].toString(),
        serviceId: json["service_id"].toString(),
        pickupLocation: json["pickup_location"].toString(),
        pickupLatitude: json["pickup_latitude"].toString(),
        pickupLongitude: json["pickup_longitude"].toString(),
        destination: json["destination"].toString(),
        duration: json["duration"].toString(),
        distance: json["distance"].toString(),
        destinationLatitude: json["destination_latitude"].toString(),
        destinationLongitude: json["destination_longitude"].toString(),
        recommendAmount: json["recommend_amount"].toString(),
        minAmount: json["min_amount"].toString(),
        maxAmount: json["max_amount"].toString(),
        offerAmount: json["offer_amount"].toString(),
        isIntercity: json["is_intercity"].toString(),
        note: json["note"]?.toString(),
        cancelReason: json["cancel_reason"]?.toString(),
        canceledUserType: json["canceled_user_type"]?.toString(),
        cancelDate: json["cancelled_at"].toString(),
        numberOfPassenger: json["number_of_passenger"].toString(),
        otp: json["otp"].toString(),
        otpAccept: json["otp_accept"].toString(),
        completedAt: json["completed_at"].toString(),
        pickupDateTime: json["pickup_date_time"]?.toString(),
        isAccepted: json["is_accepted"].toString(),
        isRunning: json["is_running"].toString(),
        amount: json["amount"].toString(),
        charge: json["charge"].toString(),
        appliedCouponId: json["applied_coupon_id"].toString(),
        status: json["status"].toString(),
        paymentType: json["payment_type"].toString(),
        paymentStatus: json["payment_status"].toString(),
        cashPayment: json["cash_payment"].toString(),
        gatewayCurrencyId: json["gateway_currency_id"].toString(),
        createdAt: json["created_at"]?.toString(),
        updatedAt: json["updated_at"]?.toString(),
        bidsCount: json["bids_count"] == null ? '0' : json["bids_count"].toString(),
        userReviewCount: json["user_review_count"] == null ? '0' : json["user_review_count"].toString(),
        driverReview: json["driver_review"] == null ? null : UserReview.fromJson(json["driver_review"]),
        userReview: json["user_review"] == null ? null : UserReview.fromJson(json["user_review"]),
        user: json["user"] == null ? null : GlobalUser.fromJson(json["user"]),
        service: json["service"] == null ? null : AppService.fromJson(json["service"]),
        driver: json["driver"] == null ? null : GlobalDriverInfoModel.fromJson(json["driver"]),
        startTime: json["start_time"]?.toString(),
        endTime: json["end_time"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "uid": uid,
        "user_id": userId,
        "driver_id": driverId,
        "service_id": serviceId,
        "pickup_location": pickupLocation,
        "pickup_latitude": pickupLatitude,
        "pickup_longitude": pickupLongitude,
        "destination": destination,
        "duration": duration,
        "distance": distance,
        "destination_latitude": destinationLatitude,
        "destination_longitude": destinationLongitude,
        "recommend_amount": recommendAmount,
        "min_amount": minAmount,
        "max_amount": maxAmount,
        "offer_amount": offerAmount,
        "is_intercity": isIntercity,
        "note": note,
        "cancel_reason": cancelReason,
        "canceled_user_type": canceledUserType,
        "cancelled_at": cancelDate,
        "number_of_passenger": numberOfPassenger,
        "otp": otp,
        "otp_accept": otpAccept,
        "completed_at": completedAt,
        "pickup_date_time": pickupDateTime,
        "is_accepted": isAccepted,
        "is_running": isRunning,
        "amount": amount,
        "charge": charge,
        "applied_coupon_id": appliedCouponId,
        "status": status,
        "payment_type": paymentType,
        "cash_payment": cashPayment,
        "gateway_currency_id": gatewayCurrencyId,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "bids_count": bidsCount,
        'user_review_count': userReviewCount,
        "user": user,
        "driver": driver,
      };

  double getDistance() {
    return (double.tryParse(distance ?? '0') ?? 0).toPrecision(2);
  }
}
