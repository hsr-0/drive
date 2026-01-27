import 'dart:convert';

import 'package:ovoride_driver/data/model/global/app/ride_meassage_model.dart';

import '../ride/ride_model.dart';

PusherResponseModel pusherResponseModelFromJson(String str) => PusherResponseModel.fromJson(json.decode(str));

class PusherResponseModel {
  String? channelName;
  String? eventName;
  EventData? data;
  PusherResponseModel({this.channelName, this.eventName, this.data});
  PusherResponseModel copyWith({
    String? channelName,
    String? eventName,
    EventData? data,
  }) =>
      PusherResponseModel(
        channelName: channelName.toString(),
        eventName: eventName.toString(),
        data: data,
      );
  factory PusherResponseModel.fromJson(Map<String, dynamic> json) {
    return PusherResponseModel(
      channelName: json["channelName"].toString(),
      eventName: json["eventName"].toString(),
      data: EventData.fromJson(json["data"]),
    );
  }
}

class EventData {
  String? remark;
  String? userId;
  String? driverId;
  String? rideId;
  String? driverLatitude;
  String? driverLongitude;
  RideModel? ride;
  RideMessage? message;
  EventData({
    this.remark,
    this.userId,
    this.driverId,
    this.rideId,
    this.driverLatitude,
    this.driverLongitude,
    this.ride,
    this.message,
  });
  EventData copyWith({
    String? channelName,
    String? eventName,
    String? remark,
    String? userId,
    String? driverId,
    String? rideId,
    RideMessage? message,
    String? driverLatitude,
    String? driverLongitude,
    RideModel? ride,
  }) =>
      EventData(
        remark: remark.toString(),
        userId: userId.toString(),
        driverId: driverId.toString(),
        rideId: rideId.toString(),
        message: message,
        driverLatitude: driverLatitude ?? '',
        driverLongitude: driverLongitude ?? '',
        ride: ride,
      );
  factory EventData.fromJson(Map<String, dynamic> json) {
    return EventData(
      remark: json["remark"].toString(),
      userId: json["userId"].toString(),
      driverId: json["driverId"].toString(),
      rideId: json["rideId"].toString(),
      message: json["message"] != null ? RideMessage.fromJson(json["message"]) : null,
      driverLatitude: json["latitude"].toString(),
      driverLongitude: json["longitude"].toString(),
      ride: json["ride"] != null ? RideModel.fromJson(json["ride"]) : null,
    );
  }
}
