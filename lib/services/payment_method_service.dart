import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'user_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'stripe_service.dart';

/// Persists the payment method setup state using shared preferences.
class PaymentMethodService {
  PaymentMethodService._();

  static final PaymentMethodService instance = PaymentMethodService._();

    // Removed unused _hasPaymentMethodKey
    static const String _savedCardsKeyPrefix = 'saved_payment_cards_v1_';

  Future<List<SavedPaymentCard>> getSavedCards() async {
    final user = UserService().currentUser;
    if (user == null) return <SavedPaymentCard>[];

    final token = await UserService().getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final remoteCards = await _fetchCardsFromBackend(token);
        await _saveCards(remoteCards, user.email);
        return remoteCards;
      } catch (_) {
        // Si backend falla, usar cache local sin romper UX.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _savedCardsKeyPrefix + user.email;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <SavedPaymentCard>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SavedPaymentCard.fromJson)
        .toList();
  }

  Future<void> addManualCard({
    required String cardNumber,
    required String expiry,
    String? cvc,
  }) async {
    final user = UserService().currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;

    final expParts = expiry.split('/');
    if (expParts.length != 2) throw Exception('Fecha inválida');
    final expMonth = int.tryParse(expParts[0]);
    final expYear = int.tryParse('20${expParts[1]}');
    if (expMonth == null || expYear == null) throw Exception('Fecha inválida');

    // Para entrada manual, persistimos en backend con un id interno.
    // Stripe requiere CardField/CardForm para confirmar con datos PCI completos.
    final paymentMethodId = 'pm_local_${DateTime.now().millisecondsSinceEpoch}';

    final cards = await getSavedCards();
    final existingIndex = cards.indexWhere(
      (card) => card.last4 == last4 && card.expiry == expiry,
    );

    final entry = SavedPaymentCard(
      brand: _detectBrand(digits),
      last4: last4,
      expiry: expiry,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
        paymentMethodId: paymentMethodId,
    );

    final token = await UserService().getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesion no valida. Inicia sesion de nuevo.');
    }
    await _saveCardToBackend(entry, token);

    if (existingIndex >= 0) {
      cards[existingIndex] = entry;
    } else {
      cards.insert(0, entry);
    }

    await _saveCards(cards, user.email);
    await setHasPaymentMethod(cards.isNotEmpty);
  }

  /// Usa Stripe SetupIntent + PaymentSheet para guardar la tarjeta con
  /// autenticación bancaria (3DS) cuando el emisor la requiere.
  Future<void> addCardWithStripeVerification() async {
    final user = UserService().currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final token = await UserService().getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesion no valida. Inicia sesion de nuevo.');
    }

    await StripeService.instance.ensureInitialized();

    final setupData = await _createStripeSetupIntent(token);
    final setupIntentClientSecret =
        setupData['setupIntentClientSecret'] as String? ?? '';
    final customerId = setupData['customer'] as String? ?? '';
    final ephemeralKey = setupData['ephemeralKey'] as String? ?? '';

    if (setupIntentClientSecret.isEmpty ||
        customerId.isEmpty ||
        ephemeralKey.isEmpty) {
      throw Exception('Respuesta incompleta del backend al iniciar Stripe.');
    }

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'RentalBike',
        setupIntentClientSecret: setupIntentClientSecret,
        customerId: customerId,
        customerEphemeralKeySecret: ephemeralKey,
        style: ThemeMode.system,
        allowsDelayedPaymentMethods: false,
      ),
    );

    await Stripe.instance.presentPaymentSheet();

    final syncedCards = await _syncCardsFromStripe(token);
    await _saveCards(syncedCards, user.email);
    await setHasPaymentMethod(syncedCards.isNotEmpty);
  }

  Future<void> removeCard(SavedPaymentCard card) async {
    final user = UserService().currentUser;
    if (user == null) return;

    final token = await UserService().getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await _removeCardFromBackend(card.paymentMethodId, token);
      } catch (_) {
        // Continuar con borrado local para no bloquear al usuario.
      }
    }

    final cards = await getSavedCards();
    cards.removeWhere((c) =>
      c.brand == card.brand &&
      c.last4 == card.last4 &&
      c.expiry == card.expiry &&
      c.createdAtMillis == card.createdAtMillis
    );
    await _saveCards(cards, user.email);
    await setHasPaymentMethod(cards.isNotEmpty);
  }

  Future<bool> hasPaymentMethod() async {
    final cards = await getSavedCards();
    return cards.isNotEmpty;
  }

  // setHasPaymentMethod ya no es necesario, pero se deja vacío para compatibilidad
  Future<void> setHasPaymentMethod(bool value) async {}

  Future<void> _saveCards(List<SavedPaymentCard> cards, String email) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(cards.map((card) => card.toJson()).toList());
    final key = _savedCardsKeyPrefix + email;
    await prefs.setString(key, encoded);
  }

  Future<List<SavedPaymentCard>> _fetchCardsFromBackend(String token) async {
    final baseUrl = UserService().getBackendBaseUrl();
    final uri = Uri.parse('$baseUrl/payment-methods');
    final response = await http.get(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 400) {
      throw Exception('Error backend payment-methods: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final cards = (payload['cards'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SavedPaymentCard.fromJson)
        .toList();
    return cards;
  }

  Future<void> _saveCardToBackend(SavedPaymentCard card, String token) async {
    final baseUrl = UserService().getBackendBaseUrl();
    final uri = Uri.parse('$baseUrl/payment-methods');
    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'brand': card.brand,
        'last4': card.last4,
        'expiry': card.expiry,
        'paymentMethodId': card.paymentMethodId,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo guardar en backend: ${response.body}');
    }
  }

  Future<void> _removeCardFromBackend(String paymentMethodId, String token) async {
    final baseUrl = UserService().getBackendBaseUrl();
    final uri = Uri.parse('$baseUrl/payment-methods/$paymentMethodId');
    final response = await http.delete(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo eliminar en backend: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> _createStripeSetupIntent(String token) async {
    final baseUrl = UserService().getBackendBaseUrl();
    final uri = Uri.parse('$baseUrl/payment-methods/setup-intent');
    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{}),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo iniciar la verificacion de tarjeta: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<SavedPaymentCard>> _syncCardsFromStripe(String token) async {
    final baseUrl = UserService().getBackendBaseUrl();
    final uri = Uri.parse('$baseUrl/payment-methods/sync-stripe');
    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{}),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudieron sincronizar las tarjetas de Stripe: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload['cards'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SavedPaymentCard.fromJson)
        .toList();
  }

  String _detectBrand(String digits) {
    if (digits.startsWith('4')) {
      return 'VISA';
    }
    if (digits.startsWith('5')) {
      return 'Mastercard';
    }
    if (digits.startsWith('34') || digits.startsWith('37')) {
      return 'AMEX';
    }
    return 'Tarjeta';
  }
}

class SavedPaymentCard {
  const SavedPaymentCard({
    required this.brand,
    required this.last4,
    required this.expiry,
    required this.createdAtMillis,
    required this.paymentMethodId,
  });

  final String brand;
  final String last4;
  final String expiry;
  final int createdAtMillis;
  final String paymentMethodId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'brand': brand,
      'last4': last4,
      'expiry': expiry,
      'createdAtMillis': createdAtMillis,
      'paymentMethodId': paymentMethodId,
    };
  }

  static SavedPaymentCard fromJson(Map<String, dynamic> json) {
    return SavedPaymentCard(
      brand: json['brand'] as String? ?? 'Tarjeta',
      last4: json['last4'] as String? ?? '0000',
      expiry: json['expiry'] as String? ?? '--/--',
      createdAtMillis: json['createdAtMillis'] as int? ?? 0,
      paymentMethodId: json['paymentMethodId'] as String? ?? '',
    );
  }
}
