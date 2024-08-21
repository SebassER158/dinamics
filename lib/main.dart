import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dinamics_app/screens/config_screen.dart';
import 'package:dinamics_app/screens/form_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('project_data');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iDinamics',
      home: FutureBuilder(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            SharedPreferences prefs = snapshot.data as SharedPreferences;
            String? projectId = prefs.getString('project_id');
            if (projectId != null) {
              return FormScreen(projectId: projectId);
            } else {
              return ConfigScreen();
            }
          }
          return CircularProgressIndicator();
        },
      ),
    );
  }
}
