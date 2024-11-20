import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Add this import for notifications
import 'todo_provider.dart';

class TodoScreen extends StatefulWidget {
  @override
  _TodoScreenState createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final TextEditingController taskController = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  Timer? _timer;
  List<String> missedTasks = []; // Track missed tasks
  Set<String> notifiedTasks = {}; // Track notified tasks

  @override
  void initState() {
    super.initState();
    _startTimer(); // Start the timer for missed deadlines
    scheduleBackgroundCheck(); // Register background task for checking deadlines
  }

  // Initialize notification plugin (flutter_local_notifications)
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  void scheduleBackgroundCheck() {
    final todoProvider = Provider.of<TodoProvider>(context, listen: false);
    Workmanager().registerPeriodicTask(
      "1",
      "checkMissedDeadlinesTask",
      frequency: Duration(hours: 1),
      inputData: {'tasks': todoProvider.todos.length}, // Using length for simplicity
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      setState(() {
        _checkMissedDeadlines(); // Check for missed deadlines every 5 seconds
        _checkUpcomingDeadlines(); // Check for tasks due soon
      });
    });
  }

  void _checkMissedDeadlines() {
    final now = DateTime.now();
    final todoProvider = Provider.of<TodoProvider>(context, listen: false);

    for (var todo in todoProvider.todos) {
      if (todo.deadline != null && !todo.isDone) {
        bool isDeadlineMissed = todo.deadline!.isBefore(now);

        // Only show the dialog if the deadline is missed and it hasn't been shown before
        if (isDeadlineMissed && !missedTasks.contains(todo.title)) {
          _showMissedDeadlineDialog(todo.title);
          missedTasks.add(todo.title); // Track missed tasks
        }
      }
    }
  }


  // Check for deadlines that are approaching within 10 minutes
  void _checkUpcomingDeadlines() {
    final now = DateTime.now();
    final todoProvider = Provider.of<TodoProvider>(context, listen: false);

    for (var todo in todoProvider.todos) {
      if (todo.deadline != null && !todo.isDone) {
        final deadline = todo.deadline!;
        if (deadline.isBefore(now.add(Duration(minutes: 10))) &&
            deadline.isAfter(now) &&
            !notifiedTasks.contains(todo.title)) {
          _showUpcomingDeadlineNotification(todo);
          notifiedTasks.add(todo.title); // Mark task as notified
        }
      }
    }
  }

  // Show a notification for tasks with approaching deadlines (within 10 minutes)
  void _showUpcomingDeadlineNotification(Todo todo) async {
    var androidDetails = AndroidNotificationDetails(
        'todo_channel', // Channel ID
        'Todo Notifications', // Channel name
        channelDescription: 'Channel for task notifications',
        importance: Importance.high,
        priority: Priority.high);
    var platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      "Deadline approaching",
      "Task '${todo.title}' is due soon!",
      platformDetails,
      payload: todo.id.toString(),
    );
  }

  void _deleteTask(int index, Todo todo) {
    final provider = Provider.of<TodoProvider>(context, listen: false);
    provider.removeTodo(todo.id);

    _listKey.currentState?.removeItem(
      index,
          (context, animation) => _buildItem(todo, animation, index),
      duration: Duration(milliseconds: 300),
    );

    setState(() {});
  }

  Color getCardColor(Todo todo) {
    DateTime now = DateTime.now();
    bool isDeadlineMissed = todo.deadline != null && todo.deadline!.isBefore(now);

    if (todo.isDone) {
      return Colors.grey; // Grey if the task is completed
    }

    // Use isDeadlineMissed here to determine if the task is overdue
    if (isDeadlineMissed) {
      return Colors.black; // Black if the deadline has been missed
    }

    if (todo.deadline == null) {
      return Colors.lightBlue; // Light blue if no deadline
    }

    // For tasks with approaching deadlines, apply different colors
    if (todo.deadline!.isBefore(now.add(Duration(minutes: 1)))) {
      return Colors.red; // Red if the deadline is within 1 minute
    } else if (todo.deadline!.isBefore(now.add(Duration(minutes: 5)))) {
      return Colors.orange; // Orange if deadline is within 5 minutes
    } else {
      return Colors.green; // Green if the deadline is more than 5 minutes away
    }
  }


  void _showMissedDeadlineDialog(String taskTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Missed Deadline'),
          content: Text('You missed the deadline for the task: $taskTitle'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);

    List<Todo> sortedTodos = List.from(todoProvider.todos)
      ..sort((a, b) {
        DateTime now = DateTime.now();
        bool aMissed = a.deadline?.isBefore(now) ?? false;
        bool bMissed = b.deadline?.isBefore(now) ?? false;

        if (!a.isDone && b.isDone) return -1;
        if (a.isDone && !b.isDone) return 1;

        if (!aMissed && bMissed) return -1;
        if (aMissed && !bMissed) return 1;

        if (a.deadline != null && b.deadline != null) {
          return a.deadline!.compareTo(b.deadline!);
        }

        if (a.deadline == null && b.deadline != null) return 1;
        if (a.deadline != null && b.deadline == null) return -1;

        return 0;
      });

    return Scaffold(
      appBar: AppBar(
        title: Text('To-Do List'),
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedList(
              key: _listKey,
              initialItemCount: sortedTodos.length,
              itemBuilder: (context, index, animation) {
                final todo = sortedTodos[index];
                return _buildItem(todo, animation, index); // Keeping the original item building logic
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskController,
                    onChanged: (value) {
                      setState(() {});
                    },
                    onSubmitted: (value) async {
                      if (value.isNotEmpty) {
                        DateTime? deadline = await showDateTimePicker(context);
                        if (deadline != null) {
                          todoProvider.addTodo(value, deadline: deadline);
                        } else {
                          todoProvider.addTodo(value);
                        }
                        taskController.clear();
                        _listKey.currentState?.insertItem(sortedTodos.length);
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Add a task',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: taskController.text.isNotEmpty
                      ? () async {
                    DateTime? deadline = await showDateTimePicker(context);
                    if (deadline != null) {
                      todoProvider.addTodo(taskController.text, deadline: deadline);
                    } else {
                      todoProvider.addTodo(taskController.text);
                    }
                    taskController.clear();
                    _listKey.currentState?.insertItem(sortedTodos.length);
                    setState(() {});
                  }
                      : null,
                  child: Text('Add'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Todo todo, Animation<double> animation, int index) {
    bool isDeadlineMissed = todo.deadline != null && todo.deadline!.isBefore(DateTime.now());

    return SizeTransition(
      sizeFactor: animation,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          color: getCardColor(todo), // Color based on deadlines
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            leading: Checkbox(
              value: todo.isDone,
              onChanged: isDeadlineMissed
                  ? null
                  : (bool? newValue) {
                Provider.of<TodoProvider>(context, listen: false).toggleTodo(todo.id);
              },
            ),
            title: Text(
              todo.title,
              style: TextStyle(
                decoration: todo.isDone ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  String? newTitle = await _showEditDialog(context, todo.title);
                  if (newTitle != null) {
                    Provider.of<TodoProvider>(context, listen: false).updateTodoTitle(todo.id, newTitle);
                  }
                } else if (value == 'delete') {
                  _deleteTask(index, todo);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (!isDeadlineMissed && !todo.isDone)
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
              ],
              icon: Icon(Icons.more_vert),
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _showEditDialog(BuildContext context, String currentTitle) {
    TextEditingController controller = TextEditingController(text: currentTitle);

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Task'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter new task title'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<DateTime?> showDateTimePicker(BuildContext context) async {
  final DateTime? date = await showDatePicker(
    context: context,
    firstDate: DateTime.now(),
    lastDate: DateTime(2100),
  );

  if (date == null) return null;

  final TimeOfDay? time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );

  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}}