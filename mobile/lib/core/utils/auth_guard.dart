import 'package:flutter/material.dart';
import '../../presentation/controllers/auth_controller.dart';
import '../../presentation/widgets/auth_modal.dart';

void requireAuth(
  BuildContext context,
  AuthController authController, {
  required VoidCallback onAuthenticated,
  String prompt = 'Sign in to access this feature',
}) {
  if (authController.isAuthenticated) {
    onAuthenticated();
    return;
  }

  AuthModal.show(
    context,
    authController: authController,
    prompt: prompt,
    onSuccess: onAuthenticated,
  );
}
