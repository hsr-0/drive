import 'dart:convert';

import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';

AllRideResponseModel completeRideResponseModelFromJson(String str) => AllRideResponseModel.fromJson(json.decode(str));

class AllRideResponseModel {
  String? remark;
  String? status;
  Data? data;
  List<String>? message;

  AllRideResponseModel({this.remark, this.status, this.data, this.message});

  factory AllRideResponseModel.fromJson(Map<String, dynamic> json) => AllRideResponseModel(
        remark: json["remark"],
        status: json["status"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        message: json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x)),
      );
}

class Data {
  AllRides? allRides;
  String? userImagePath;
  Data({this.allRides, this.userImagePath});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        allRides: json["rides"] == null ? null : AllRides.fromJson(json["rides"]),
        userImagePath: json["user_image_path"],
      );

  Map<String, dynamic> toJson() => {"completed_rides": allRides?.toJson()};
}

class AllRides {
  List<RideModel>? data;

  String? nextPageUrl;

  AllRides({this.data, this.nextPageUrl});

  factory AllRides.fromJson(Map<String, dynamic> json) => AllRides(
        data: json["data"] == null ? [] : List<RideModel>.from(json["data"]!.map((x) => RideModel.fromJson(x))),
        nextPageUrl: json["next_page_url"],
      );

  Map<String, dynamic> toJson() => {
        "data": data == null ? [] : List<RideModel>.from(data!.map((x) => x.toJson())),
        "next_page_url": nextPageUrl,
      };
}
