import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/otp_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final otpEmail = TextEditingController();
  final otpController = TextEditingController();

  bool loading = false;
  bool useOtpLogin = false;

  bool sendingOtp = false;
  bool verifyingOtp = false;
  bool otpSent = false;

  Future<void> login() async {
    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      // AuthGate (in main.dart) is listening to auth state and will already
      // swap to OpportunitiesScreen the instant sign-in succeeds — often
      // before this line even runs. Only navigate manually if this screen
      // is still on-screen (e.g. reached via a named route after logout,
      // where there's no AuthGate above it to react automatically).
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed")),
        );
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> sendLoginOtp() async {
    final emailText = otpEmail.text.trim();

    if (emailText.isEmpty || !emailText.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter a valid email address first")),
      );
      return;
    }

    setState(() => sendingOtp = true);

    final result = await OtpService.sendOtp(email: emailText, purpose: "login");

    if (!mounted) return;

    setState(() {
      sendingOtp = false;
      if (result.success) otpSent = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success ? "Code sent! Check your email inbox." : (result.error ?? "Failed to send code"),
        ),
      ),
    );
  }

  Future<void> verifyLoginOtp() async {
    final code = otpController.text.trim();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter the 6-digit code from your email")),
      );
      return;
    }

    setState(() => verifyingOtp = true);

    final result = await OtpService.verifyOtp(
      email: otpEmail.text.trim(),
      code: code,
      purpose: "login",
    );

    if (!mounted) return;

    if (!result.success || result.customToken == null) {
      setState(() => verifyingOtp = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? "Incorrect code")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithCustomToken(result.customToken!);

      // Same reasoning as password login: AuthGate may already have
      // switched screens by the time this runs.
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed, please try again")),
        );
      }
    }

    if (mounted) {
      setState(() => verifyingOtp = false);
    }
  }

  void resetOtpFlow() {
    setState(() {
      otpSent = false;
      otpController.clear();
    });
  }

  Widget input(TextEditingController c, String label,
      {bool isPass = false, bool enabled = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: c,
        obscureText: isPass,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget buildPasswordForm() {
    return Column(
      children: [
        input(email, "Email"),
        input(password, "Password", isPass: true),
        SizedBox(height: 20),
        loading
            ? CircularProgressIndicator()
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await login();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text("Login"),
                ),
              ),
      ],
    );
  }

  Widget buildOtpForm() {
    return Column(
      children: [
        input(otpEmail, "Email", enabled: !otpSent),
        if (otpSent) input(otpController, "6-digit code"),
        SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: otpSent
                ? (verifyingOtp ? null : verifyLoginOtp)
                : (sendingOtp ? null : sendLoginOtp),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: (sendingOtp || verifyingOtp)
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(otpSent ? "Verify & Login" : "Send Code"),
          ),
        ),
        if (otpSent)
          TextButton(
            onPressed: resetOtpFlow,
            child: Text("Wrong email? Edit it"),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.15,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Welcome Back",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        ToggleButtons(
                          borderRadius: BorderRadius.circular(12),
                          isSelected: [!useOtpLogin, useOtpLogin],
                          onPressed: (index) {
                            setState(() {
                              useOtpLogin = index == 1;
                              otpSent = false;
                            });
                          },
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text("Password"),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text("OTP"),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        useOtpLogin ? buildOtpForm() : buildPasswordForm(),
                        SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: Text("Create Account"),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}