import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'todo_provider.dart';
import 'todo_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WorkManager for non-web platforms
  if (!kIsWeb) {
    await Workmanager().initialize(callbackDispatcher);
  }

  // Initialize Notifications
  await initializeNotifications();

  // Request notification permission for Android 13+ (non-web platforms)
  if (!kIsWeb) {
    await requestNotificationPermission();
  }

  runApp(MyApp());
}

// Function to request notification permission
Future<void> requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

// Initialize local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Callback dispatcher for background task execution
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Your background task logic here
    return Future.value(true);
  });
}

// Initialize notifications
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  // Initialize the FlutterLocalNotificationsPlugin
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

// Show a notification for a missed deadline
Future<void> showMissedDeadlineNotification(Todo todo) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'missed_deadline_channel',
    'Missed Deadlines',
    channelDescription: 'Notifications for missed to-do deadlines',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    int.tryParse(todo.id) ?? 0, // Safe conversion for ID
    'Missed Deadline',
    '${todo.title} has missed its deadline!',
    platformChannelSpecifics,
  );
}

// Function to schedule background work (non-web platforms)
void scheduleNotification() {
  if (!kIsWeb) {
    Workmanager().registerOneOffTask(
      'unique_task', // Unique task identifier
      'task_id', // Task ID (you can change the task ID)
      inputData: <String, dynamic>{'key': 'value'}, // Optional input data
      initialDelay: Duration(seconds: 5), // Set delay before task is executed
    );
  }
}

// Root widget of the app
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TodoProvider(),
      child: MaterialApp(
        title: 'To-Do App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.light, // Light theme
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.dark, // Dark theme
        ),
        themeMode: ThemeMode.system, // Use system theme mode
        home: TodoScreen(),
      ),
    );
  }
}
