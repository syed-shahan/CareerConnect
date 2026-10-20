import 'dart:convert';

import 'package:http/http.dart' as http;

// Base URL of your CareerConnect OTP backend deployed on Vercel.
const String otpBackendBaseUrl = "https://careerconnect-backend-lime.vercel.app";

class OtpResult {
  final bool success;
  final String? error;
  final String? customToken;

  OtpResult({required this.success, this.error, this.customToken});
}

class OtpService {
  static Future<OtpResult> sendOtp({
    required String email,
    required String purpose, // "register" or "login"
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$otpBackendBaseUrl/api/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "purpose": purpose}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        return OtpResult(success: true);
      }

      return OtpResult(
        success: false,
        error: (data["error"] ?? "Failed to send verification code").toString(),
      );
    } catch (e) {
      return OtpResult(
        success: false,
        error: "Could not reach the verification service. Check your internet connection.",
      );
    }
  }

  static Future<OtpResult> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$otpBackendBaseUrl/api/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "code": code, "purpose": purpose}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        return OtpResult(success: true, customToken: data["customToken"]);
      }

      return OtpResult(
        success: false,
        error: (data["error"] ?? "Verification failed").toString(),
      );
    } catch (e) {
      return OtpResult(
        success: false,
        error: "Could not reach the verification service. Check your internet connection.",
      );
    }
  }
}