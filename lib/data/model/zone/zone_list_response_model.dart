// To parse this JSON data, do
//
//     final zoneListResponseModel = zoneListResponseModelFromJson(jsonString);

import 'dart:convert';

ZoneListResponseModel zoneListResponseModelFromJson(String str) => ZoneListResponseModel.fromJson(json.decode(str));

class ZoneListResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  Data? data;

  ZoneListResponseModel({this.remark, this.status, this.message, this.data});

  factory ZoneListResponseModel.fromJson(Map<String, dynamic> json) => ZoneListResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );
}

class Data {
  Zones? zones;

  Data({this.zones});

  factory Data.fromJson(Map<String, dynamic> json) => Data(zones: json["zones"] == null ? null : Zones.fromJson(json["zones"]));

  Map<String, dynamic> toJson() => {"zones": zones?.toJson()};
}

class Zones {
  List<ZoneData>? data;
  dynamic nextPageUrl;

  Zones({this.data, this.nextPageUrl});

  factory Zones.fromJson(Map<String, dynamic> json) => Zones(
        data: json["data"] == null ? [] : List<ZoneData>.from(json["data"]!.map((x) => ZoneData.fromJson(x))),
        nextPageUrl: json["next_page_url"],
      );

  Map<String, dynamic> toJson() => {
        "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
        "next_page_url": nextPageUrl,
      };
}

class ZoneData {
  String? id;
  String? name;

  ZoneData({this.id, this.name});

  factory ZoneData.fromJson(Map<String, dynamic> json) => ZoneData(id: json["id"].toString(), name: json["name"].toString());

  Map<String, dynamic> toJson() => {"id": id, "name": name};
}
