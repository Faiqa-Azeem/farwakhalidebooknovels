import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/supabase_service.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  Function(String message, bool isError)? onError;
  Function(String message)? onSuccess;

  bool _isAvailable = false;
  bool _isInitialized = false;
  bool _isRecoveringPurchases = false;

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription?.cancel();
      _isInitialized = false;
    }, onError: (error) {
      if (onError != null) onError!("Purchase Error: $error", true);
    });
    _checkAvailability().then((_) => _recoverPendingPurchases());
  }

  Future<void> _checkAvailability() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
       debugPrint("Store not available");
    }
  }

  /// Clears unconsumed Android consumables that block new purchases.
  Future<void> _recoverPendingPurchases() async {
    if (!_isAvailable || _isRecoveringPurchases) return;
    _isRecoveringPurchases = true;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('restorePurchases failed: $e');
    } finally {
      _isRecoveringPurchases = false;
    }
  }

  static bool _isAlreadyOwnedError(IAPError? error) {
    if (error == null) return false;
    final message = (error.message).toLowerCase();
    final details = (error.details ?? '').toString().toLowerCase();
    return message.contains('already own') ||
        message.contains('item already owned') ||
        details.contains('item_already_owned') ||
        error.code == '7';
  }

  /// Maps an ebook price to the correct store product ID per platform.
  static String productIdForPrice(int price) {
    if (Platform.isIOS && price == 500) {
      return 'tier_500_v2';
    }
    return 'tier_$price';
  }

  Future<void> buyEbook({
    required int price,
    required String ebookId,
    required String userEmail,
  }) {
    final productId = productIdForPrice(price);
    debugPrint('Starting purchase: platform=${Platform.operatingSystem}, price=$price, productId=$productId');
    return buyTopUp(productId, ebookId, userEmail);
  }

  Future<void> buyTopUp(String productId, String ebookId, String userEmail) async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      if (onError != null) onError!("Store not available. Try again later.", true);
      return;
    }

    final Set<String> ids = {productId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);

    if (response.notFoundIDs.isNotEmpty) {
       if (onError != null) onError!("Product $productId not found in store.", true);
       return;
    }

    if (response.productDetails.isEmpty) {
       if (onError != null) onError!("Start purchase failed: No products found.", true);
       return;
    }

    if (response.error != null) {
      debugPrint("queryProductDetails error: ${response.error}");
      if (onError != null) {
        onError!("Could not load product from store. Try again later.", true);
      }
      return;
    }

    final ProductDetails productDetails = response.productDetails.first;

    final PurchaseParam purchaseParam;
    if (Platform.isAndroid) {
      purchaseParam = PurchaseParam(productDetails: productDetails);
    } else {
      final obfuscatedUser = sha256.convert(utf8.encode(userEmail)).toString();
      purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: obfuscatedUser,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pendingUserEmail', userEmail);
      if (ebookId.isNotEmpty) {
        await prefs.setString('pendingEbookId', ebookId);
      }
      PurchaseService.pendingUserEmail = userEmail;
      PurchaseService.pendingEbookId = ebookId;
    } catch(e) {
      debugPrint("Error saving prefs: $e");
    }

    final started = await _iap.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: false,
    );
    if (!started && onError != null) {
      onError!("Could not start purchase. Please try again.", true);
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        final error = purchaseDetails.error;
        debugPrint(
          "Purchase error: code=${error?.code}, message=${error?.message}, "
          "details=${error?.details}, product=${purchaseDetails.productID}",
        );

        if (Platform.isAndroid && _isAlreadyOwnedError(error)) {
          await _recoverPendingPurchases();
          if (onError != null) {
            onError!(
              "A previous purchase is being finalized. Please wait a moment and try again.",
              false,
            );
          }
        } else if (onError != null) {
          onError!(error?.message ?? "Purchase failed", true);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        final success = await _deliverProduct(purchaseDetails);
        if (success && purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        } else if (!success && purchaseDetails.pendingCompletePurchase) {
          // Consume stuck purchases that cannot be delivered so future buys work.
          debugPrint('Consuming undeliverable purchase to unblock store: ${purchaseDetails.productID}');
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedEmail = prefs.getString('pendingUserEmail') ?? PurchaseService.pendingUserEmail;
    final String? storedEbookId = prefs.getString('pendingEbookId') ?? PurchaseService.pendingEbookId;

    if (storedEbookId != null && storedEmail != null) {
       try {
         try {
           await SupabaseService.insertEbookPayment(
              ebookId: storedEbookId,
              email: storedEmail,
              deviceId: 'google_play_billing', 
           );
         } catch (insertError) {
           debugPrint("Payment log insert failed, continuing to grant access: $insertError");
         }
         
         await SupabaseService.grantAccess(
           email: storedEmail, 
           ebookId: storedEbookId
         );
         
          if (onSuccess != null) onSuccess!("Purchase Successful! Access Granted.");
          
          PurchaseService.pendingEbookId = null;
          PurchaseService.pendingUserEmail = null;
          await prefs.remove('pendingEbookId');
          await prefs.remove('pendingUserEmail');

          return true;

       } catch (e) {
         if (onError != null) onError!("Payment OK but Grant failed: $e. Contact Admin.", true);
         return false;
       }
    } else {
       debugPrint('Purchase received without ebook context: ${purchaseDetails.productID}');
       if (onError != null) {
         onError!("Purchase tracked by store but missing ebook context. Contact Admin.", true);
       }
       return false;
    }
  }

  static String? pendingEbookId;
  static String? pendingUserEmail;
  
  void dispose() {
    _subscription?.cancel();
    _isInitialized = false;
  }
}
