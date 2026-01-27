import 'dart:io';

class ProfileCompletePostModel {
  final String username;
  final String countryName;
  final String countryCode;
  final String mobileNumber;
  final String mobileCode;
  final String zone;
  final File? image; // optional
  final String? address;
  final String? state;
  final String? zip;
  final String? city;

  ProfileCompletePostModel({
    required this.username,
    required this.countryName,
    required this.countryCode,
    required this.mobileNumber,
    required this.mobileCode,
    required this.zone,
    required this.image,
    required this.address,
    required this.state,
    required this.zip,
    required this.city,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    map['username'] = username;
    map['country'] = countryName;
    map['country_code'] = countryCode;
    map['mobile'] = mobileNumber;
    map['mobile_code'] = mobileCode;
    map['address'] = address;
    map['state'] = state;
    map['zip'] = zip;
    map['city'] = city;
    map['zone'] = zone;

    return map;
  }
}
