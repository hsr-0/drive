import 'dart:io';

class ProfilePostModel {
  final String firstname;
  final String lastName;
  final File? image;
  final String? address;
  final String? state;
  final String? zip;
  final String? city;

  ProfilePostModel({
    required this.firstname,
    required this.lastName,
    required this.image,
    required this.address,
    required this.state,
    required this.zip,
    required this.city,
  });

  factory ProfilePostModel.fromMap(Map<String, dynamic> map) {
    return ProfilePostModel(
      firstname: map['firstname'] as String,
      lastName: map['lastName'] as String,
      image: map['image'] as File,
      address: map['address'] as String,
      state: map['state'] as String,
      zip: map['zip'] as String,
      city: map['city'] as String,
    );
  }
}
