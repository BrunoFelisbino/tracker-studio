import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/drivers/teltonika/teltonika_driver.dart';
import 'core/uce/registry/uce_registry.dart';

void main() {
  UceRegistry.initialize();
  TeltonikaDriver.registerAll();
  runApp(const ProviderScope(child: TrackerStudioApp()));
}
