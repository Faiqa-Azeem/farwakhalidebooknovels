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
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Callback to update UI or show errors
  Function(String message, bool isError)? onError;
  Function(String message)? onSuccess;

  bool _isAvailable = false;
  bool _isInitialized = false;

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
      _isInitialized = false;
    }, onError: (error) {
      if (onError != null) onError!("Purchase Error: $error", true);
    });
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
       debugPrint("Store not available");
    }
  }

  /// Maps an ebook price to the correct store product ID per platform.
  /// iOS uses tier_500_v2 for Rs 500; Google Play uses tier_500.
  static String productIdForPrice(int price) {
    if (Platform.isIOS && price == 500) {
      return 'tier_500_v2';
    }
    return 'tier_$price';
  }

  /// Start an ebook purchase using the platform-correct product ID.
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

    // Never pass cleartext email/PII in applicationUserName on Android — Google Play
    // blocks purchases and returns BillingResponse.developerError / "Invalid obfuscated account id".
    // Ebook context is stored in SharedPreferences instead.
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
      
      // If it's a bundle, the calling class would set the bundle IDs directly to SharedPreferences right before calling buyTopUp.
    } catch(e) {
      debugPrint("Error saving prefs: $e");
    }

    // autoConsume: false so we only complete/consume after access is granted successfully.
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
        // Show loading?
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          final error = purchaseDetails.error;
          debugPrint(
            "Purchase error: code=${error?.code}, message=${error?.message}, "
            "details=${error?.details}, product=${purchaseDetails.productID}",
          );
          if (onError != null) {
            onError!(error?.message ?? "Purchase failed", true);
          }
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          final success = await _deliverProduct(purchaseDetails);
          if (success && purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
        }
        
        // Removed eager completePurchase, moved it inside success block
      }
    }
  }

  Future<bool> _deliverProduct(PurchaseDetails purchaseDetails) async {
    // 1. Extract Info
    // applicationUserName is likely null on some Android versions, 
    // so we might need to rely on local state if this is simple app.
    // BUT for robustness, we need to know WHICH ebook to unlock.
    
    // NOTE: passing "developerPayload" or "applicationUserName" is not fully reliable on all Android versions.
    // Ideally, we should have stored a local "pending_purchase_ebook_id" variable.
    
    // However, if we assume the user stays on the screen, we can handle it.
    // For now, we will just Consume it and let the UI handle the Grant if we can track it.
    
    // Better Approach: 
    // We grant access HERE. But we need the ebookId. 
    // If applicationUserName works, we use it.
    
    // We should verify purchaseDetails.verificationData on server, but for now we trust it.
    
    // IMPORTANT: Since we can't easily pass custom data in buyConsumable that survives reliably 
    // without a server verifying the token, we will load variables from SharedPreferences.
    
    final prefs = await SharedPreferences.getInstance();
    final String? storedEmail = prefs.getString('pendingUserEmail') ?? PurchaseService.pendingUserEmail;
    final String? storedEbookId = prefs.getString('pendingEbookId') ?? PurchaseService.pendingEbookId;

    if (storedEbookId != null && storedEmail != null) {
       try {
         // Log payment (Wrap in separate try-catch so it doesn't fail the whole delivery on unique constraint or RLS)
         try {
           await SupabaseService.insertEbookPayment(
              ebookId: storedEbookId,
              email: storedEmail,
              deviceId: 'google_play_billing', 
           );
         } catch (insertError) {
           debugPrint("Payment log insert failed, continuing to grant access: $insertError");
         }
         
         // Grant Access Directly
         await SupabaseService.grantAccess(
           email: storedEmail, 
           ebookId: storedEbookId
         );
         
          if (onSuccess != null) onSuccess!("Purchase Successful! Access Granted.");
          
          // Clear pending
          PurchaseService.pendingEbookId = null;
          PurchaseService.pendingUserEmail = null;
          await prefs.remove('pendingEbookId');
          await prefs.remove('pendingUserEmail');

          return true; // Successfully processed and recorded

       } catch (e) {
         if (onError != null) onError!("Payment OK but Grant failed: $e. Contact Admin.", true);
         return false; // Do not consume the purchase so it stays tracked
       }
    } else {
       if (onError != null) onError!("Purchase tracked by store but missing ebook context. Contact Admin.", true);
       return false; // Do not consume
    }
  }

  // Static temporary storage for the current flow (maintained for fallback)
  static String? pendingEbookId;
  static String? pendingUserEmail;
  
  void dispose() {
    _subscription.cancel();
    _isInitialized = false;
  }
}
