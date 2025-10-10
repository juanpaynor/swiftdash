package com.swiftdash.app

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*

class MainActivity : FlutterActivity(), MethodCallHandler {
    private val CHANNEL = "swiftdash/payment"
    private val TAG = "SwiftDashPayment"
    
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
            "initializePayment" -> initializePaymentMock(call, result)
            "startCheckout" -> startCheckoutMock(call, result)
            "getPaymentStatus" -> getPaymentStatusMock(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Mock payment initialization - simulates Maya SDK setup
     */
    private fun initializePaymentMock(call: MethodCall, result: Result) {
        try {
            val clientKey = call.argument<String>("clientKey")
            val environment = call.argument<String>("environment")
            
            Log.d(TAG, "Mock: Initializing payment with environment: $environment")
            
            // Mock successful initialization
            isInitialized = true
            
            val response = mapOf(
                "success" to true,
                "message" to "Payment system initialized (mock mode)"
            )
            
            result.success(response)
            Log.d(TAG, "Mock: Payment initialization successful")
            
        } catch (e: Exception) {
            Log.e(TAG, "Mock: Error initializing payment", e)
            result.error("INIT_ERROR", "Failed to initialize payment: ${e.message}", null)
        }
    }

    /**
     * Mock checkout process - simulates Maya payment flow
     */
    private fun startCheckoutMock(call: MethodCall, result: Result) {
        try {
            val amount = call.argument<Double>("amount")
            val paymentMethod = call.argument<String>("paymentMethod")
            val deliveryId = call.argument<String>("deliveryId")
            
            Log.d(TAG, "Mock: Starting checkout - Amount: $amount, Method: $paymentMethod")
            
            // Store pending result
            pendingResult = result
            
            // Simulate payment processing delay
            Handler(Looper.getMainLooper()).postDelayed({
                when (paymentMethod) {
                    "cash" -> {
                        // Cash payment - always successful
                        val successResponse = mapOf(
                            "isSuccess" to true,
                            "status" to "cashPending",
                            "deliveryId" to deliveryId,
                            "amount" to amount,
                            "method" to "cash",
                            "timestamp" to Date().time.toString(),
                            "transactionData" to mapOf(
                                "mockMode" to true,
                                "paymentType" to "cash"
                            )
                        )
                        pendingResult?.success(successResponse)
                        pendingResult = null
                        Log.d(TAG, "Mock: Cash payment successful")
                    }
                    "creditCard", "mayaWallet" -> {
                        // Digital payment - simulate success
                        val mockCheckoutId = "mock_checkout_${System.currentTimeMillis()}"
                        val mockPaymentId = "mock_payment_${System.currentTimeMillis()}"
                        
                        val successResponse = mapOf(
                            "isSuccess" to true,
                            "status" to "paid",
                            "checkoutId" to mockCheckoutId,
                            "paymentId" to mockPaymentId,
                            "deliveryId" to deliveryId,
                            "amount" to amount,
                            "method" to paymentMethod,
                            "mayaPaymentMethod" to if (paymentMethod == "creditCard") "CARD" else "WALLET",
                            "timestamp" to Date().time.toString(),
                            "transactionData" to mapOf(
                                "mockMode" to true,
                                "reference" to mockPaymentId
                            )
                        )
                        pendingResult?.success(successResponse)
                        pendingResult = null
                        Log.d(TAG, "Mock: Digital payment successful")
                    }
                    else -> {
                        val errorResponse = mapOf(
                            "isSuccess" to false,
                            "status" to "failed",
                            "errorMessage" to "Unsupported payment method: $paymentMethod",
                            "deliveryId" to deliveryId,
                            "amount" to amount,
                            "timestamp" to Date().time.toString()
                        )
                        pendingResult?.success(errorResponse)
                        pendingResult = null
                        Log.d(TAG, "Mock: Payment failed - unsupported method")
                    }
                }
            }, 2000) // 2 second delay to simulate processing
            
        } catch (e: Exception) {
            Log.e(TAG, "Mock: Error starting checkout", e)
            result.error("CHECKOUT_ERROR", "Failed to start checkout: ${e.message}", null)
        }
    }

    /**
     * Mock payment status check
     */
    private fun getPaymentStatusMock(call: MethodCall, result: Result) {
        try {
            val checkoutId = call.argument<String>("checkoutId")
            
            Log.d(TAG, "Mock: Getting payment status for: $checkoutId")
            
            val statusResponse = mapOf(
                "checkoutId" to checkoutId,
                "status" to "paid", // Mock as paid
                "paymentId" to "mock_payment_${System.currentTimeMillis()}",
                "timestamp" to Date().time.toString(),
                "mockMode" to true
            )
            
            result.success(statusResponse)
            
        } catch (e: Exception) {
            Log.e(TAG, "Mock: Error getting payment status", e)
            result.error("STATUS_ERROR", "Failed to get payment status: ${e.message}", null)
        }
    }
}
