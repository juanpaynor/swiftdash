package com.example.myapp

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

// Maya SDK imports - temporarily disabled until dependency is resolved
// import com.paymaya.sdk.android.checkout.PayMayaCheckout
// import com.paymaya.sdk.android.checkout.PayMayaCheckoutCallback
// import com.paymaya.sdk.android.checkout.models.CheckoutRequest
// import com.paymaya.sdk.android.checkout.models.CheckoutResult
// import com.paymaya.sdk.android.checkout.models.TotalAmount
// import com.paymaya.sdk.android.checkout.models.RedirectUrl
// import com.paymaya.sdk.android.checkout.models.Buyer
// import com.paymaya.sdk.android.checkout.models.Contact
// import com.paymaya.sdk.android.checkout.models.Item
// import com.paymaya.sdk.android.common.PayMayaEnvironment
// import com.paymaya.sdk.android.common.LogLevel

import org.json.JSONObject
import java.math.BigDecimal
import java.util.*

class MainActivity : FlutterActivity(), MethodCallHandler {
    private val CHANNEL = "swiftdash/payment"
    private val TAG = "SwiftDashPayment"
    
    // Maya SDK client - temporarily disabled
    // private var payMayaCheckout: PayMayaCheckout? = null
    private var pendingResult: Result? = null
    private var isInitialized = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(this)
        
        Log.d(TAG, "Platform channel configured")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initializePayment" -> initializePayment(call, result)
            "startCheckout" -> startCheckout(call, result)
            "checkPaymentStatus" -> checkPaymentStatus(call, result)
            "cleanup" -> cleanup(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Initialize Maya SDK with provided credentials
     */
    private fun initializePayment(call: MethodCall, result: Result) {
        try {
            val publicKey = call.argument<String>("publicKey")
            val environment = call.argument<String>("environment")
            val logLevel = call.argument<String>("logLevel")

            if (publicKey == null || publicKey.isEmpty()) {
                result.error("INVALID_PARAMS", "Public key is required", null)
                return
            }

            Log.d(TAG, "Initializing Maya SDK - Environment: $environment")

            // Determine environment
            val payMayaEnv = when (environment) {
                "PRODUCTION" -> PayMayaEnvironment.PRODUCTION
                else -> PayMayaEnvironment.SANDBOX
            }

            // Determine log level
            val mayaLogLevel = when (logLevel) {
                "DEBUG" -> LogLevel.DEBUG
                "INFO" -> LogLevel.INFO
                "WARN" -> LogLevel.WARN
                "ERROR" -> LogLevel.ERROR
                else -> LogLevel.ERROR
            }

            // Initialize Maya Checkout client
            payMayaCheckout = PayMayaCheckout.newBuilder()
                .clientPublicKey(publicKey)
                .environment(payMayaEnv)
                .logLevel(mayaLogLevel)
                .build()

            isInitialized = true
            
            Log.d(TAG, "Maya SDK initialized successfully")
            
            result.success(mapOf(
                "success" to true,
                "message" to "Maya SDK initialized successfully"
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Maya SDK", e)
            result.error("INITIALIZATION_ERROR", "Failed to initialize Maya SDK: ${e.message}", null)
        }
    }

    /**
     * Start Maya checkout process
     */
    private fun startCheckout(call: MethodCall, result: Result) {
        try {
            if (!isInitialized || payMayaCheckout == null) {
                result.error("NOT_INITIALIZED", "Maya SDK not initialized", null)
                return
            }

            // Store pending result for callback
            pendingResult = result

            // Extract parameters
            val amount = call.argument<Double>("amount")
            val description = call.argument<String>("description")
            val referenceNumber = call.argument<String>("referenceNumber")
            val deliveryId = call.argument<String>("deliveryId")
            val customerName = call.argument<String>("customerName")
            val customerEmail = call.argument<String>("customerEmail")
            val customerPhone = call.argument<String>("customerPhone")
            val metadata = call.argument<Map<String, Any>>("metadata")

            if (amount == null || amount <= 0) {
                result.error("INVALID_AMOUNT", "Valid amount is required", null)
                return
            }

            if (description == null || description.isEmpty()) {
                result.error("INVALID_DESCRIPTION", "Description is required", null)
                return
            }

            if (referenceNumber == null || referenceNumber.isEmpty()) {
                result.error("INVALID_REFERENCE", "Reference number is required", null)
                return
            }

            Log.d(TAG, "Starting checkout - Amount: $amount, Reference: $referenceNumber")

            // Create total amount
            val totalAmount = TotalAmount(
                value = BigDecimal.valueOf(amount),
                currency = "PHP"
            )

            // Create items list
            val items = listOf(
                Item(
                    name = description,
                    quantity = 1,
                    amount = Item.Amount(
                        value = BigDecimal.valueOf(amount)
                    ),
                    totalAmount = Item.Amount(
                        value = BigDecimal.valueOf(amount)
                    )
                )
            )

            // Create buyer (optional but recommended)
            val buyer = if (customerName != null || customerEmail != null || customerPhone != null) {
                Buyer(
                    firstName = customerName?.split(" ")?.getOrNull(0) ?: "",
                    lastName = customerName?.split(" ")?.drop(1)?.joinToString(" ") ?: "",
                    contact = Contact(
                        phone = customerPhone ?: "",
                        email = customerEmail ?: ""
                    )
                )
            } else null

            // Create redirect URLs
            val redirectUrl = RedirectUrl(
                success = "swiftdash://payment/success",
                failure = "swiftdash://payment/failure",
                cancel = "swiftdash://payment/cancel"
            )

            // Create metadata map
            val requestMetadata = mutableMapOf<String, Any>()
            requestMetadata["deliveryId"] = deliveryId ?: ""
            requestMetadata["timestamp"] = System.currentTimeMillis()
            metadata?.let { requestMetadata.putAll(it) }

            // Create checkout request
            val checkoutRequest = CheckoutRequest(
                totalAmount = totalAmount,
                buyer = buyer,
                items = items,
                requestReferenceNumber = referenceNumber,
                redirectUrl = redirectUrl,
                metadata = requestMetadata
            )

            // Start checkout activity
            payMayaCheckout!!.startCheckoutActivityForResult(
                activity = this,
                checkoutRequest = checkoutRequest,
                callback = object : PayMayaCheckoutCallback {
                    override fun onCheckoutSuccess(checkoutId: String, paymentId: String?) {
                        Log.d(TAG, "Checkout successful - CheckoutId: $checkoutId, PaymentId: $paymentId")
                        
                        pendingResult?.success(mapOf(
                            "isSuccess" to true,
                            "status" to "paid",
                            "checkoutId" to checkoutId,
                            "paymentId" to paymentId,
                            "deliveryId" to deliveryId,
                            "amount" to amount,
                            "method" to call.argument<String>("paymentMethod"),
                            "timestamp" to System.currentTimeMillis().toString()
                        ))
                        pendingResult = null
                    }

                    override fun onCheckoutFailure(checkoutId: String?, exception: Exception) {
                        Log.e(TAG, "Checkout failed - CheckoutId: $checkoutId", exception)
                        
                        pendingResult?.success(mapOf(
                            "isSuccess" to false,
                            "status" to "failed",
                            "checkoutId" to checkoutId,
                            "deliveryId" to deliveryId,
                            "amount" to amount,
                            "method" to call.argument<String>("paymentMethod"),
                            "errorMessage" to (exception.message ?: "Payment failed"),
                            "errorCode" to "CHECKOUT_FAILED",
                            "timestamp" to System.currentTimeMillis().toString()
                        ))
                        pendingResult = null
                    }

                    override fun onCheckoutCancel(checkoutId: String?) {
                        Log.d(TAG, "Checkout cancelled - CheckoutId: $checkoutId")
                        
                        pendingResult?.success(mapOf(
                            "isSuccess" to false,
                            "status" to "pending",
                            "checkoutId" to checkoutId,
                            "deliveryId" to deliveryId,
                            "amount" to amount,
                            "method" to call.argument<String>("paymentMethod"),
                            "errorMessage" to "Payment was cancelled by user",
                            "timestamp" to System.currentTimeMillis().toString()
                        ))
                        pendingResult = null
                    }
                }
            )

        } catch (e: Exception) {
            Log.e(TAG, "Error starting checkout", e)
            result.error("CHECKOUT_ERROR", "Failed to start checkout: ${e.message}", null)
        }
    }

    /**
     * Check payment status for a checkout ID
     */
    private fun checkPaymentStatus(call: MethodCall, result: Result) {
        try {
            if (!isInitialized || payMayaCheckout == null) {
                result.error("NOT_INITIALIZED", "Maya SDK not initialized", null)
                return
            }

            val checkoutId = call.argument<String>("checkoutId")
            
            if (checkoutId == null || checkoutId.isEmpty()) {
                result.error("INVALID_CHECKOUT_ID", "Checkout ID is required", null)
                return
            }

            Log.d(TAG, "Checking payment status for checkout: $checkoutId")

            // Use Maya SDK to check payment status
            // Note: This is a synchronous operation, consider running in background thread
            Thread {
                try {
                    val paymentStatus = payMayaCheckout!!.checkPaymentStatus(checkoutId)
                    
                    runOnUiThread {
                        when (paymentStatus) {
                            CheckoutResult.PAYMENT_SUCCESS -> {
                                result.success(mapOf(
                                    "isSuccess" to true,
                                    "status" to "paid",
                                    "checkoutId" to checkoutId
                                ))
                            }
                            CheckoutResult.AUTH_FAILED, CheckoutResult.PAYMENT_FAILED -> {
                                result.success(mapOf(
                                    "isSuccess" to false,
                                    "status" to "failed",
                                    "checkoutId" to checkoutId,
                                    "errorMessage" to "Payment verification failed"
                                ))
                            }
                            else -> {
                                result.success(mapOf(
                                    "isSuccess" to false,
                                    "status" to "pending",
                                    "checkoutId" to checkoutId
                                ))
                            }
                        }
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        Log.e(TAG, "Error checking payment status", e)
                        result.error("STATUS_CHECK_ERROR", "Failed to check payment status: ${e.message}", null)
                    }
                }
            }.start()

        } catch (e: Exception) {
            Log.e(TAG, "Error in checkPaymentStatus", e)
            result.error("STATUS_CHECK_ERROR", "Failed to check payment status: ${e.message}", null)
        }
    }

    /**
     * Cleanup Maya SDK resources
     */
    private fun cleanup(call: MethodCall, result: Result) {
        try {
            Log.d(TAG, "Cleaning up Maya SDK resources")
            
            payMayaCheckout = null
            isInitialized = false
            pendingResult = null
            
            result.success(mapOf("success" to true))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
            result.error("CLEANUP_ERROR", "Failed to cleanup: ${e.message}", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        // Let Maya SDK handle the activity result
        payMayaCheckout?.onActivityResult(requestCode, resultCode, data)?.let { checkoutResult ->
            // This is handled by the callback in startCheckout
            Log.d(TAG, "Activity result processed by Maya SDK: $checkoutResult")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Cleanup resources
        payMayaCheckout = null
        pendingResult = null
        isInitialized = false
    }
}
