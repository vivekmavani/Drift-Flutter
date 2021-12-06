import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/moor_database.dart';
import 'ui/home_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Provider(
      // The single instance of AppDatabase
      create: (_) => AppDatabase().taskDao,
      child: MaterialApp(
        title: 'Material App',
        home: HomePage(),
      ),
    );
  }
}