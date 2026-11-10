import 'package:flutter/material.dart';
import 'package:pinshift/app.dart';
import 'package:pinshift/data/checkout_reminders.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CheckoutReminders.schedule();
  runApp(const PinshiftRoot());
}
