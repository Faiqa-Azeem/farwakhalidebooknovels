import 'dart:async';
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
       print("⚠️ Store not available");
    }
  }

  Future<void> buyTopUp(String productId, String ebookId, String userEmail) async {
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

    final ProductDetails productDetails = response.productDetails.first;

    // Use applicationUserName to pass ebookId and email safely through the purchase
    // We will pack it as "email|ebookId"
    final purchaseParam = PurchaseParam(
      productDetails: productDetails,
      applicationUserName: "$userEmail|$ebookId", 
    );

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

    _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show loading?
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if (onError != null) onError!(purchaseDetails.error?.message ?? "Purchase failed", true);
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
    
    final payload = purchaseDetails.verificationData.localVerificationData;
    // We should verify this on server, but for now we trust it.
    
    // IMPORTANT: Since we can't easily pass custom data in buyConsumable that survives reliably 
    // without a server verifying the token, we will load variables from SharedPreferences.
    
    final prefs = await SharedPreferences.getInstance();
    final String? storedEmail = prefs.getString('pendingUserEmail') ?? PurchaseService.pendingUserEmail;
    final String? storedEbookId = prefs.getString('pendingEbookId') ?? PurchaseService.pendingEbookId;

    if (storedEbookId != null && storedEmail != null) {
       try {
         await SupabaseService.insertEbookPayment(
            ebookId: storedEbookId,
            email: storedEmail,
            deviceId: 'google_play_billing', 
         );
         
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
