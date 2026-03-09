import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

class RentalSubscriptionRecord {
  const RentalSubscriptionRecord({
    required this.subscriptionId,
    required this.customerId,
    required this.bikeName,
    required this.planLabel,
    required this.priceLabel,
    required this.status,
    required this.createdAtMillis,
    required this.nextRenewalAtMillis,
    required this.cancelAtPeriodEnd,
  });

  final String subscriptionId;
  final String customerId;
  final String bikeName;
  final String planLabel;
  final String priceLabel;
  final String status;
  final int createdAtMillis;
  final int nextRenewalAtMillis;
  final bool cancelAtPeriodEnd;

  RentalSubscriptionRecord copyWith({
    String? subscriptionId,
    String? customerId,
    String? bikeName,
    String? planLabel,
    String? priceLabel,
    String? status,
    int? createdAtMillis,
    int? nextRenewalAtMillis,
    bool? cancelAtPeriodEnd,
  }) {
    return RentalSubscriptionRecord(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      customerId: customerId ?? this.customerId,
      bikeName: bikeName ?? this.bikeName,
      planLabel: planLabel ?? this.planLabel,
      priceLabel: priceLabel ?? this.priceLabel,
      status: status ?? this.status,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      nextRenewalAtMillis: nextRenewalAtMillis ?? this.nextRenewalAtMillis,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'subscriptionId': subscriptionId,
      'customerId': customerId,
      'bikeName': bikeName,
      'planLabel': planLabel,
      'priceLabel': priceLabel,
      'status': status,
      'createdAtMillis': createdAtMillis,
      'nextRenewalAtMillis': nextRenewalAtMillis,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
    };
  }

  static RentalSubscriptionRecord fromJson(Map<String, dynamic> json) {
    return RentalSubscriptionRecord(
      subscriptionId: json['subscriptionId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      bikeName: json['bikeName'] as String? ?? '',
      planLabel: json['planLabel'] as String? ?? '',
      priceLabel: json['priceLabel'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      createdAtMillis: json['createdAtMillis'] as int? ?? 0,
      nextRenewalAtMillis: json['nextRenewalAtMillis'] as int? ?? 0,
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
    );
  }
}

class RentalSubscriptionService {
    Future<void> remove(String subscriptionId) async {
      final records = await getAll();
      records.removeWhere((item) => item.subscriptionId == subscriptionId);
      await saveAll(records);
    }
  RentalSubscriptionService._();

  static final RentalSubscriptionService instance = RentalSubscriptionService._();

  static const String _storageKeyPrefix = 'rental_subscriptions_v1_';

  Future<List<RentalSubscriptionRecord>> getAll() async {
    final user = UserService().currentUser;
    if (user == null) return <RentalSubscriptionRecord>[];
    final preferences = await SharedPreferences.getInstance();
    final key = _storageKeyPrefix + user.email;
    final raw = preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return <RentalSubscriptionRecord>[];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(RentalSubscriptionRecord.fromJson)
        .toList();
  }

  Future<void> saveAll(List<RentalSubscriptionRecord> records) async {
    final user = UserService().currentUser;
    if (user == null) return;
    final preferences = await SharedPreferences.getInstance();
    final payload = records.map((record) => record.toJson()).toList();
    final key = _storageKeyPrefix + user.email;
    await preferences.setString(key, jsonEncode(payload));
  }

  Future<void> upsert(RentalSubscriptionRecord record) async {
    final records = await getAll();
    final existingIndex = records.indexWhere(
      (item) => item.subscriptionId == record.subscriptionId,
    );
    if (existingIndex >= 0) {
      records[existingIndex] = record;
    } else {
      records.insert(0, record);
    }
    await saveAll(records);
  }
}
