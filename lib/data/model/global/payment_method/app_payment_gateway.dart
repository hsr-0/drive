import 'package:ovoride_driver/data/model/global/payment_method/app_payment_method.dart';

class AppPaymentGateway {
  String? id;
  String? name;
  String? currency;
  String? symbol;
  String? methodCode;
  String? gatewayAlias;
  String? minAmount;
  String? maxAmount;
  String? percentCharge;
  String? fixedCharge;
  String? rate;
  String? createdAt;
  String? updatedAt;
  AppPaymentMethod? method;

  AppPaymentGateway({
    this.id,
    this.name,
    this.currency,
    this.symbol,
    this.methodCode,
    this.gatewayAlias,
    this.minAmount,
    this.maxAmount,
    this.percentCharge,
    this.fixedCharge,
    this.rate,
    this.createdAt,
    this.updatedAt,
    this.method,
  });

  factory AppPaymentGateway.fromJson(Map<String, dynamic> json) => AppPaymentGateway(
        id: json["id"].toString(),
        name: json["name"].toString(),
        currency: json["currency"].toString(),
        symbol: json["symbol"].toString(),
        methodCode: json["method_code"].toString(),
        gatewayAlias: json["gateway_alias"].toString(),
        minAmount: json["min_amount"].toString(),
        maxAmount: json["max_amount"].toString(),
        percentCharge: json["percent_charge"].toString(),
        fixedCharge: json["fixed_charge"].toString(),
        rate: json["rate"].toString(),
        createdAt: json["created_at"]?.toString(),
        updatedAt: json["updated_at"]?.toString(),
        method: json["method"] == null ? null : AppPaymentMethod.fromJson(json["method"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "currency": currency,
        "symbol": symbol,
        "method_code": methodCode,
        "gateway_alias": gatewayAlias,
        "min_amount": minAmount,
        "max_amount": maxAmount,
        "percent_charge": percentCharge,
        "fixed_charge": fixedCharge,
        "rate": rate,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "method": method?.toJson(),
      };
}
