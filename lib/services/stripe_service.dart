import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

const String stripePublishableKeyOverride =
    'pk_test_51T1B8XRUYbbTSSSbRm4JfG6cb8kufZfcZmDfl81fL5HdzTSeRopij1cisKnSs5bUxWxxayfVUQITaEwnZ2YsD4n700108L9xR1';
const String stripeBackendUrlOverride = 'https://gobike-backend.onrender.com';
const String _envPublishableKey = String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
  defaultValue: '',
);
const String _envBackendUrl = String.fromEnvironment(
  'STRIPE_BACKEND_URL',
  defaultValue: '',
);

class StripeService {
  StripeService._();

  static final StripeService instance = StripeService._();

  bool _initialized = false;

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    final key = _resolvePublishableKey();
    if (key.isEmpty) {
      throw StateError(
        'Configura STRIPE_PUBLISHABLE_KEY con --dart-define o editing stripePublishableKeyOverride.',
      );
    }
    Stripe.publishableKey = key;
    Stripe.merchantIdentifier = 'GoBikePayments';
    await Stripe.instance.applySettings();
    _initialized = true;
  }

  Future<void> presentPaymentSheet({
    required int amountCents,
    required String currency,
    required String description,
  }) async {
    await ensureInitialized();
    final sheetData = await _createPaymentSheetData(
      amountCents: amountCents,
      currency: currency,
      description: description,
    );
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: sheetData.clientSecret,
        merchantDisplayName: 'GoBike',
        customerId: sheetData.customerId,
        customerEphemeralKeySecret: sheetData.ephemeralKey,
        style: ThemeMode.system,
        billingDetails: BillingDetails(),
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  }

  Future<void> validateCardWithSetupIntent() async {
    await ensureInitialized();
    final clientSecret = await _createSetupIntentClientSecret();
    await Stripe.instance.confirmSetupIntent(
      paymentIntentClientSecret: clientSecret,
      params: PaymentMethodParams.card(paymentMethodData: PaymentMethodData()),
    );
  }

  Future<String> createSetupIntentClientSecret() async {
    await ensureInitialized();
    return _createSetupIntentClientSecret();
  }

  Future<SubscriptionPaymentResult> presentSubscriptionSheet({
    required String priceId,
    required String description,
  }) async {
    await ensureInitialized();
    final sheetData = await _createSubscriptionSheetData(
      priceId: priceId,
      description: description,
    );
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: sheetData.clientSecret,
        merchantDisplayName: 'GoBike',
        customerId: sheetData.customerId,
        customerEphemeralKeySecret: sheetData.ephemeralKey,
        style: ThemeMode.system,
        billingDetails: BillingDetails(),
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    return SubscriptionPaymentResult(
      subscriptionId: sheetData.subscriptionId,
      customerId: sheetData.customerId,
      status: sheetData.status,
      currentPeriodEndMillis: sheetData.currentPeriodEndMillis,
    );
  }

  Future<SubscriptionDetails> fetchSubscriptionDetails({
    required String subscriptionId,
  }) async {
    final backendUrl = _resolveBackendUrl();
    if (backendUrl.isEmpty) {
      throw StateError(
        'Configura STRIPE_BACKEND_URL con --dart-define o editing stripeBackendUrlOverride.',
      );
    }

    final uri = Uri.parse('$backendUrl/subscription/$subscriptionId');
    final response = await http.get(uri, headers: _jsonHeaders);
    _throwIfUnexpectedHtmlResponse(response);

    if (response.statusCode >= 400) {
      throw StateError('Stripe backend error: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return SubscriptionDetails(
      id: payload['id'] as String? ?? subscriptionId,
      status: payload['status'] as String? ?? 'unknown',
      cancelAtPeriodEnd: payload['cancelAtPeriodEnd'] as bool? ?? false,
      currentPeriodEndMillis: ((payload['currentPeriodEnd'] as num?)
                  ?.toInt() ??
              0) *
          1000,
      priceId: payload['priceId'] as String? ?? '',
      interval: payload['interval'] as String? ?? '',
    );
  }

  Future<void> cancelSubscription({required String subscriptionId}) async {
    final backendUrl = _resolveBackendUrl();
    if (backendUrl.isEmpty) {
      throw StateError(
        'Configura STRIPE_BACKEND_URL con --dart-define o editing stripeBackendUrlOverride.',
      );
    }

    final uri = Uri.parse('$backendUrl/cancel-subscription');
    final response = await http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode(<String, Object?>{'subscriptionId': subscriptionId}),
    );
    _throwIfUnexpectedHtmlResponse(response);

    if (response.statusCode >= 400) {
      throw StateError('Stripe backend error: ${response.body}');
    }
  }

  Future<_PaymentSheetData> _createPaymentSheetData({
    required int amountCents,
    required String currency,
    required String description,
  }) async {
    final backendUrl = _resolveBackendUrl();
    if (backendUrl.isEmpty) {
      throw StateError(
        'Configura STRIPE_BACKEND_URL con --dart-define o editing stripeBackendUrlOverride.',
      );
    }
    final uri = Uri.parse('$backendUrl/create-payment-intent');
    final response = await http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode(<String, Object?>{
        'amount': amountCents,
        'currency': currency,
        'description': description,
      }),
    );
    _throwIfUnexpectedHtmlResponse(response);
    if (response.statusCode >= 400) {
      throw StateError('Stripe backend error: ${response.body}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final clientSecret = payload['paymentIntentClientSecret'] as String?;
    final ephemeralKey = payload['ephemeralKey'] as String?;
    final customerId = payload['customer'] as String?;
    if (clientSecret == null || ephemeralKey == null || customerId == null) {
      throw StateError('Stripe backend response incompleta: ${response.body}');
    }
    return _PaymentSheetData(
      clientSecret: clientSecret,
      ephemeralKey: ephemeralKey,
      customerId: customerId,
    );
  }

  Future<String> _createSetupIntentClientSecret() async {
    final backendUrl = _resolveBackendUrl();
    if (backendUrl.isEmpty) {
      throw StateError(
        'Configura STRIPE_BACKEND_URL con --dart-define o editing stripeBackendUrlOverride.',
      );
    }
    final uri = Uri.parse('$backendUrl/create-setup-intent');
    final response = await http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode(<String, Object?>{}),
    );

    _throwIfUnexpectedHtmlResponse(response);

    if (response.statusCode >= 400) {
      throw StateError('Stripe backend error: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final clientSecret = payload['setupIntentClientSecret'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw StateError('Stripe backend response incompleta: ${response.body}');
    }
    return clientSecret;
  }

  Future<_PaymentSheetData> _createSubscriptionSheetData({
    required String priceId,
    required String description,
  }) async {
    final backendUrl = _resolveBackendUrl();
    if (backendUrl.isEmpty) {
      throw StateError(
        'Configura STRIPE_BACKEND_URL con --dart-define o editing stripeBackendUrlOverride.',
      );
    }
    if (priceId.isEmpty) {
      throw StateError(
        'Falta el priceId de Stripe para este botón. Configura el plan mensual con su price_...',
      );
    }

    final uri = Uri.parse('$backendUrl/create-subscription');
    final response = await http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode(<String, Object?>{
        'priceId': priceId,
        'description': description,
      }),
    );

    _throwIfUnexpectedHtmlResponse(response);

    if (response.statusCode >= 400) {
      throw StateError('Stripe backend error: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final clientSecret = payload['paymentIntentClientSecret'] as String?;
    final ephemeralKey = payload['ephemeralKey'] as String?;
    final customerId = payload['customer'] as String?;
    final subscriptionId = payload['subscriptionId'] as String?;
    final status = payload['status'] as String?;
    final currentPeriodEnd = (payload['currentPeriodEnd'] as num?)?.toInt();
    if (clientSecret == null || ephemeralKey == null || customerId == null) {
      throw StateError('Stripe backend response incompleta: ${response.body}');
    }
    return _PaymentSheetData(
      clientSecret: clientSecret,
      ephemeralKey: ephemeralKey,
      customerId: customerId,
      subscriptionId: subscriptionId,
      status: status,
      currentPeriodEndMillis:
          currentPeriodEnd == null ? null : currentPeriodEnd * 1000,
    );
  }

  String _resolvePublishableKey() {
    if (_envPublishableKey.isNotEmpty) {
      return _envPublishableKey;
    }
    return stripePublishableKeyOverride;
  }

  String _resolveBackendUrl() {
    final configuredUrl = _envBackendUrl.isNotEmpty
        ? _envBackendUrl
        : stripeBackendUrlOverride;

    if (configuredUrl.isEmpty || kIsWeb) {
      return configuredUrl;
    }

    final uri = Uri.tryParse(configuredUrl);
    if (uri == null) {
      return configuredUrl;
    }

    final isLocalhost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (isLocalhost && defaultTargetPlatform == TargetPlatform.android) {
      return uri.replace(host: '10.0.2.2').toString();
    }

    return configuredUrl;
  }

  void _throwIfUnexpectedHtmlResponse(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final isHtml = contentType.contains('text/html') ||
        response.body.trimLeft().startsWith('<!DOCTYPE html');
    if (!isHtml) {
      return;
    }
    throw StateError(
      'El backend de Stripe devolvió HTML en vez de JSON. Verifica STRIPE_BACKEND_URL y que ngrok apunte al puerto correcto (ej: 4242).',
    );
  }
}

class _PaymentSheetData {
  const _PaymentSheetData({
    required this.clientSecret,
    required this.ephemeralKey,
    required this.customerId,
    this.subscriptionId,
    this.status,
    this.currentPeriodEndMillis,
  });

  final String clientSecret;
  final String ephemeralKey;
  final String customerId;
  final String? subscriptionId;
  final String? status;
  final int? currentPeriodEndMillis;
}

class SubscriptionPaymentResult {
  const SubscriptionPaymentResult({
    required this.subscriptionId,
    required this.customerId,
    required this.status,
    required this.currentPeriodEndMillis,
  });

  final String? subscriptionId;
  final String customerId;
  final String? status;
  final int? currentPeriodEndMillis;
}

class SubscriptionDetails {
  const SubscriptionDetails({
    required this.id,
    required this.status,
    required this.cancelAtPeriodEnd,
    required this.currentPeriodEndMillis,
    required this.priceId,
    required this.interval,
  });

  final String id;
  final String status;
  final bool cancelAtPeriodEnd;
  final int currentPeriodEndMillis;
  final String priceId;
  final String interval;
}
