import 'package:flutter/material.dart';
import 'package:ppp/goal_screen.dart';
import 'package:ppp/plan_screen.dart';
import 'package:ppp/profile_screen.dart';
import 'home_page.dart';
import 'dash_board.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
Future<void> main() async {
  await dotenv.load(fileName: "assets/.env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blueGrey);
    return MaterialApp(
        title: 'SportFuel+',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          centerTitle: true,
          surfaceTintColor: Colors.transparent, // Removes M3 overlay tint
        ),
        ),
        home: MainScreen()
    );
  }
}
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int index=0;
  final pages=const [DashBoard(),FoodTrackerScreen(),ProfileScreen(),GoalScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:pages[index] ,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => index = i),
          items: [
        BottomNavigationBarItem(icon: Icon(Icons.home),label: "Dashboard"),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined),label: "Plan"),
        BottomNavigationBarItem (icon: Icon(Icons.person),label:"Profile"),
        BottomNavigationBarItem (icon: Icon(Icons.lightbulb), label: "Goals")]),
    );
  }
}
