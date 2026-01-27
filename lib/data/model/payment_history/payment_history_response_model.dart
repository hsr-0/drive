import 'dart:convert';

PaymentHistoryResponseModel paymentHistoryResponseModelFromJson(String str) => PaymentHistoryResponseModel.fromJson(json.decode(str));

class PaymentHistoryResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  Data? data;

  PaymentHistoryResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory PaymentHistoryResponseModel.fromJson(Map<String, dynamic> json) => PaymentHistoryResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );
}

class Data {
  Payments? payments;

  Data({this.payments});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        payments: json["payments"] == null ? null : Payments.fromJson(json["payments"]),
      );
}

class Payments {
  List<PaymentHistoryModel>? data;
  dynamic nextPageUrl;

  Payments({this.data, this.nextPageUrl});

  factory Payments.fromJson(Map<String, dynamic> json) => Payments(
        data: json["data"] == null
            ? []
            : List<PaymentHistoryModel>.from(
                json["data"]!.map((x) => PaymentHistoryModel.fromJson(x)),
              ),
        nextPageUrl: json["next_page_url"],
      );
}

class PaymentHistoryModel {
  int? id;
  String? rideId;
  String? riderId;
  String? driverId;
  String? amount;
  String? paymentType;
  String? createdAt;
  String? updatedAt;
  Rider? rider;
  Ride? ride;

  PaymentHistoryModel({
    this.id,
    this.rideId,
    this.riderId,
    this.driverId,
    this.amount,
    this.paymentType,
    this.createdAt,
    this.updatedAt,
    this.rider,
    this.ride,
  });

  factory PaymentHistoryModel.fromJson(Map<String, dynamic> json) => PaymentHistoryModel(
        id: json["id"],
        rideId: json["ride_id"] != null ? json["ride_id"].toString() : "",
        riderId: json["rider_id"] != null ? json["rider_id"].toString() : "",
        driverId: json["driver_id"] != null ? json["driver_id"].toString() : "",
        amount: json["amount"] != null ? json["amount"].toString() : "",
        paymentType: json["payment_type"] != null ? json["payment_type"].toString() : "",
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
        rider: json["rider"] == null ? null : Rider.fromJson(json["rider"]),
        ride: json["ride"] == null ? null : Ride.fromJson(json["ride"]),
      );
}

class Rider {
  int? id;
  String? firstname;
  String? lastname;
  String? username;
  String? email;
  String? dialCode;
  String? mobile;
  String? refBy;
  String? countryName;
  String? countryCode;
  String? city;
  String? state;
  String? zip;
  String? address;
  String? status;
  String? kycData;
  String? kycRejectionReason;
  String? createdAt;
  String? updatedAt;

  Rider({
    this.id,
    this.firstname,
    this.lastname,
    this.username,
    this.email,
    this.dialCode,
    this.mobile,
    this.refBy,
    this.countryName,
    this.countryCode,
    this.city,
    this.state,
    this.zip,
    this.address,
    this.status,
    this.kycData,
    this.kycRejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  factory Rider.fromJson(Map<String, dynamic> json) => Rider(
        id: json["id"],
        firstname: json["firstname"] != null ? json["firstname"].toString() : "",
        lastname: json["lastname"] != null ? json["lastname"].toString() : "",
        username: json["username"] != null ? json["username"].toString() : "",
        email: json["email"] != null ? json["email"].toString() : "",
        dialCode: json["dial_code"] != null ? json["dial_code"].toString() : "",
        mobile: json["mobile"] != null ? json["mobile"].toString() : "",
        refBy: json["ref_by"] != null ? json["ref_by"].toString() : "",
        countryName: json["country_name"] != null ? json["country_name"].toString() : "",
        countryCode: json["country_code"] != null ? json["country_code"].toString() : "",
        city: json["city"] != null ? json["city"].toString() : "",
        state: json["state"] != null ? json["state"].toString() : "",
        zip: json["zip"] != null ? json["zip"].toString() : "",
        address: json["address"] != null ? json["address"].toString() : "",
        status: json["status"] != null ? json["status"].toString() : "",
        kycData: json["kyc_data"] != null ? json["kyc_data"].toString() : "",
        kycRejectionReason: json["kyc_rejection_reason"] != null ? json["kyc_rejection_reason"].toString() : "",
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
      );
}

class Ride {
  int? id;
  String? rideType;
  String? uid;
  String? userId;
  String? driverId;
  String? serviceId;
  String? gatewayCurrencyId;
  String? pickupLocation;
  String? pickupLatitude;
  String? pickupLongitude;
  String? destination;
  String? duration;
  String? distance;
  String? pickupZoneId;
  String? destinationZoneId;
  String? destinationLatitude;
  String? destinationLongitude;
  String? recommendAmount;
  String? minAmount;
  String? maxAmount;
  String? note;
  String? numberOfPassenger;
  String? otp;
  String? startTime;
  String? endTime;
  String? cancelReason;
  String? cancelledAt;
  String? amount;
  String? discountAmount;
  String? commissionPercentage;
  String? commissionAmount;
  String? appliedCouponId;
  String? status;
  String? paymentType;
  String? paymentStatus;
  String? canceledUserType;
  String? createdAt;
  String? updatedAt;

  Ride({
    this.id,
    this.rideType,
    this.uid,
    this.userId,
    this.driverId,
    this.serviceId,
    this.gatewayCurrencyId,
    this.pickupLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destination,
    this.duration,
    this.distance,
    this.pickupZoneId,
    this.destinationZoneId,
    this.destinationLatitude,
    this.destinationLongitude,
    this.recommendAmount,
    this.minAmount,
    this.maxAmount,
    this.note,
    this.numberOfPassenger,
    this.otp,
    this.startTime,
    this.endTime,
    this.cancelReason,
    this.cancelledAt,
    this.amount,
    this.discountAmount,
    this.commissionPercentage,
    this.commissionAmount,
    this.appliedCouponId,
    this.status,
    this.paymentType,
    this.paymentStatus,
    this.canceledUserType,
    this.createdAt,
    this.updatedAt,
  });

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
        id: json["id"],
        rideType: json["ride_type"] != null ? json["ride_type"].toString() : "",
        uid: json["uid"] != null ? json["uid"].toString() : "",
        userId: json["user_id"] != null ? json["user_id"].toString() : "",
        driverId: json["driver_id"] != null ? json["driver_id"].toString() : "",
        serviceId: json["service_id"] != null ? json["service_id"].toString() : "",
        gatewayCurrencyId: json["gateway_currency_id"] != null ? json["gateway_currency_id"].toString() : "",
        pickupLocation: json["pickup_location"] != null ? json["pickup_location"].toString() : "",
        pickupLatitude: json["pickup_latitude"] != null ? json["pickup_latitude"].toString() : "",
        pickupLongitude: json["pickup_longitude"] != null ? json["pickup_longitude"].toString() : "",
        destination: json["destination"] != null ? json["destination"].toString() : "",
        duration: json["duration"] != null ? json["duration"].toString() : "",
        distance: json["distance"] != null ? json["distance"].toString() : "",
        pickupZoneId: json["pickup_zone_id"] != null ? json["pickup_zone_id"].toString() : "",
        destinationZoneId: json["destination_zone_id"] != null ? json["destination_zone_id"].toString() : "",
        destinationLatitude: json["destination_latitude"] != null ? json["destination_latitude"].toString() : "",
        destinationLongitude: json["destination_longitude"] != null ? json["destination_longitude"].toString() : "",
        recommendAmount: json["recommend_amount"] != null ? json["recommend_amount"].toString() : "",
        minAmount: json["min_amount"] != null ? json["min_amount"].toString() : "",
        maxAmount: json["max_amount"] != null ? json["max_amount"].toString() : "",
        note: json["note"] != null ? json["note"].toString() : "",
        numberOfPassenger: json["number_of_passenger"] != null ? json["number_of_passenger"].toString() : "",
        otp: json["otp"] != null ? json["otp"].toString() : "",
        startTime: json["start_time"] != null ? json["start_time"].toString() : "",
        endTime: json["end_time"] != null ? json["end_time"].toString() : "",
        cancelReason: json["cancel_reason"] != null ? json["cancel_reason"].toString() : "",
        cancelledAt: json["cancelled_at"] != null ? json["cancelled_at"].toString() : "",
        amount: json["amount"] != null ? json["amount"].toString() : "",
        discountAmount: json["discount_amount"] != null ? json["discount_amount"].toString() : "",
        commissionPercentage: json["commission_percentage"] != null ? json["commission_percentage"].toString() : "",
        commissionAmount: json["commission_amount"] != null ? json["commission_amount"].toString() : "",
        appliedCouponId: json["applied_coupon_id"] != null ? json["applied_coupon_id"].toString() : "",
        status: json["status"] != null ? json["status"].toString() : "",
        paymentType: json["payment_type"] != null ? json["payment_type"].toString() : "",
        paymentStatus: json["payment_status"] != null ? json["payment_status"].toString() : "",
        canceledUserType: json["canceled_user_type"] != null ? json["canceled_user_type"].toString() : "",
        createdAt: json["created_at"].toString(),
        updatedAt: json["updated_at"].toString(),
      );
}

class Link {
  String? url;
  String? label;
  bool? active;

  Link({this.url, this.label, this.active});

  factory Link.fromJson(Map<String, dynamic> json) => Link(url: json["url"], label: json["label"], active: json["active"]);

  Map<String, dynamic> toJson() => {
        "url": url,
        "label": label,
        "active": active,
      };
}
