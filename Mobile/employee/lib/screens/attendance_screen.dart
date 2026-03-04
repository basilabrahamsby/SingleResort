import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<AttendanceProvider>(context, listen: false).fetchStatus());
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final user = Provider.of<AuthProvider>(context).user;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Digital Clock Display
            Text(
              DateFormat('hh:mm a').format(now),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            Text(
              DateFormat('EEEE, MMMM d, y').format(now),
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 48),

            // Big Clock In/Out Button
            GestureDetector(
              onTap: provider.isLoading ? null : () {
                if (!provider.isClockedIn) {
                  _showTaskChecklist(context, provider, user?.employeeId, true);
                } else {
                  _showTaskChecklist(context, provider, user?.employeeId, false);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: provider.isClockedIn ? Colors.red.shade400 : Colors.green.shade400,
                  boxShadow: [
                    BoxShadow(
                      color: (provider.isClockedIn ? Colors.red : Colors.green).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      provider.isClockedIn ? Icons.exit_to_app : Icons.login,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.isClockedIn ? 'CLOCK OUT' : 'CLOCK IN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Status Text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: provider.isLoading 
                  ? const CircularProgressIndicator()
                  : Column(
                      children: [
                        Text(
                          provider.isClockedIn ? 'Currently On Duty' : 'Currently Off Duty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: provider.isClockedIn ? Colors.green.shade700 : Colors.grey.shade700,
                          ),
                        ),
                        if (provider.isClockedIn && provider.clockInTime != null)
                          Text(
                            'Since ${DateFormat('hh:mm a').format(provider.clockInTime!)}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskChecklist(BuildContext context, AttendanceProvider provider, int? employeeId, bool isClockIn) {
    if (employeeId == null) {
      if (isClockIn) {
        provider.clockIn(-1); 
      } else {
        provider.clockOut(-1);
      }
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tasks = authProvider.dailyTasks;

    if (tasks.isEmpty) {
      // No tasks, proceed directly
      if (isClockIn) {
        provider.clockIn(employeeId);
      } else {
        provider.clockOut(employeeId);
      }
      return;
    }

    // Clone the completed tasks from backend log if checking out
    List<String> currentCompleted = isClockIn 
        ? [] 
        : List<String>.from(provider.completedTasks);
    
    // Check if we even need to show this if already everything is done?
    // User requested "compulsary complete this task in clock in and clock out"
    // So we show the dialog no matter what.

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool allChecked = true;
            for (String t in tasks) {
              if (!currentCompleted.contains(t)) {
                allChecked = false;
                break;
              }
            }

            return AlertDialog(
              title: Text(isClockIn ? 'Pre-Shift Task Acknowledgment' : 'End-Shift Task Completion'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isClockIn 
                          ? 'Please acknowledge your assigned tasks for today before clocking in.'
                          : 'Please confirm completion of all your daily tasks before clocking out.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final isChecked = currentCompleted.contains(task);
                          return CheckboxListTile(
                            title: Text(task),
                            value: isChecked,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  currentCompleted.add(task);
                                } else {
                                  currentCompleted.remove(task);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: allChecked ? () async {
                    Navigator.pop(context); // Close dialog

                    // Update backend if checking out or just update immediately
                    if (!isClockIn && provider.activeLogId != null) {
                      try {
                        await Provider.of<ApiService>(context, listen: false).updateWorkLogTasks(
                          provider.activeLogId!,
                          currentCompleted,
                        );
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save tasks: $e')));
                         return;
                      }
                    }

                    if (isClockIn) {
                      provider.clockIn(employeeId);
                    } else {
                      provider.clockOut(employeeId);
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allChecked ? Colors.green : Colors.grey,
                  ),
                  child: Text(isClockIn ? 'Acknowledge & Clock In' : 'Complete & Clock Out', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
