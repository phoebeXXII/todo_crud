import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:collection';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';


class Todo {
  String id;
  String title;
  bool isDone;
  DateTime? deadline;
  DateTime creationDate;
  bool hasMissedDeadlineNotified; // Track if notified for missed deadline

  Todo({
    required this.id,
    required this.title,
    this.isDone = false,
    this.deadline,
    required this.creationDate,
    this.hasMissedDeadlineNotified = false, // Default to false
  });
}

class TodoProvider extends ChangeNotifier {
  final List<Todo> _todos = [];
  Timer? _timer;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  UnmodifiableListView<Todo> get todos => UnmodifiableListView(_todos);

  // Getter to return sorted todos
  List<Todo> get sortedTodos {
    DateTime now = DateTime.now();
    List<Todo> sorted = List.from(_todos);

    sorted.sort((a, b) {
      int? remainingTimeA = a.deadline?.difference(now).inSeconds;
      int? remainingTimeB = b.deadline?.difference(now).inSeconds;

      if (a.isDone && b.isDone) return 0; // Completed tasks stay at the bottom

      if (remainingTimeA != null && remainingTimeB != null) {
        if (remainingTimeA < 0 && remainingTimeB < 0) {
          return remainingTimeA.compareTo(remainingTimeB); // Both missed deadlines
        } else if (remainingTimeA < 0) {
          return 1; // Missed tasks go to the end
        } else if (remainingTimeB < 0) {
          return -1; // Missed tasks go to the end
        } else {
          return remainingTimeA.compareTo(remainingTimeB); // Sort by upcoming deadlines
        }
      } else if (remainingTimeA != null) {
        return -1; // Tasks with deadlines come before those without
      } else if (remainingTimeB != null) {
        return 1; // Tasks with deadlines come before those without
      } else {
        return 0; // Both tasks without deadlines
      }
    });

    return sorted;
  }

  TodoProvider() {
    _initializeNotifications();
    _startAutoRefresh();
    _initializeWorkmanager();
  }

  void _initializeNotifications() async {
    // Initialize notifications only for Android
    if (Platform.isAndroid) {
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // Request permission for notifications on Android if not granted
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    }

    // No notification handling required for Web
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkDeadlines();
    });
  }

  // Initialize workmanager for background tasks
  void _initializeWorkmanager() {
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher);
      Workmanager().registerPeriodicTask(
        'check_deadlines_task',
        'checkMissedDeadlinesTask',
        frequency: Duration(minutes: 15), // Runs every 15 minutes
      );
    }
  }


  // Background task callback dispatcher
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) {
      final todoProvider = TodoProvider();
      todoProvider._checkDeadlines(); // Run the deadline check in the background
      return Future.value(true);
    });
  }

  void addTodo(String title, {DateTime? deadline}) {
    _todos.add(Todo(
      id: DateTime.now().toString(),
      title: title,
      creationDate: DateTime.now(),
      deadline: deadline,
    ));
    notifyListeners();
  }

  // Check for missed deadlines and show notifications
  void _checkDeadlines() {
    DateTime now = DateTime.now();
    for (var todo in _todos) {
      if (todo.deadline != null && !todo.isDone && todo.deadline!.isBefore(now)) {
        if (!todo.hasMissedDeadlineNotified) {
          // Show the notification only if not previously shown
          _showMissedDeadlineNotification(todo);
          todo.hasMissedDeadlineNotified = true; // Mark as notified
        }
      }
    }
    notifyListeners(); // Refresh UI if needed
  }

  // Show a notification for a missed deadline
  Future<void> _showMissedDeadlineNotification(Todo todo) async {
    // Check the platform before setting the notification
    if (Platform.isAndroid) {
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
        int.tryParse(todo.id) ?? 0, // Safe ID conversion
        'Missed Deadline',
        '${todo.title} has missed its deadline!',
        platformChannelSpecifics,
      );
    }
  }


  void removeTodo(String id) {
    _todos.removeWhere((todo) => todo.id == id);
    notifyListeners();
  }

  void toggleTodo(String id) {
    var todo = _todos.firstWhere((todo) => todo.id == id);
    todo.isDone = !todo.isDone;

    if (todo.isDone) {
      flutterLocalNotificationsPlugin.cancel(int.tryParse(todo.id) ?? 0);
      todo.hasMissedDeadlineNotified = false; // Reset notification flag
    }

    notifyListeners();
  }

  void updateTodoTitle(String id, String newTitle) {
    var todo = _todos.firstWhere((todo) => todo.id == id);
    todo.title = newTitle;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
