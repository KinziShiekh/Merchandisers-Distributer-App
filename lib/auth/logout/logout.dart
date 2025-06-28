import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:merchandiser_app/auth/loginscreen.dart';

class AppFunctions {
  // Make the method static to call it without creating an instance
  static Future<void> handleLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut(); // Sign out the user

      // Navigate to the login screen
      Get.offAll(() => const SignInScreen());
    } catch (e) {
      // Handle errors if logout fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error during logout: $e",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
