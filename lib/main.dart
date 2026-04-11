import 'dart:io';

import 'package:baitul_mal_plus/presentation/home/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future main() async {
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();

    databaseFactory = databaseFactoryFfi;
  }

  runApp(const BaitulMalApp());
}
