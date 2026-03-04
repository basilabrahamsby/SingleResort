import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orchid_employee/presentation/providers/auth_provider.dart';
import 'package:orchid_employee/presentation/providers/attendance_provider.dart';
import 'package:orchid_employee/data/services/api_service.dart';
import 'package:orchid_employee/core/constants/app_colors.dart';

class EmployeeDailyTasksScreen extends StatefulWidget {
  const EmployeeDailyTasksScreen({super.key});

  @override
  State<EmployeeDailyTasksScreen> createState() => _EmployeeDailyTasksScreenState();
}

class _EmployeeDailyTasksScreenState extends State<EmployeeDailyTasksScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Refresh status to get the latest complete_tasks logic over activeLogId
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.employeeId != null) {
        context.read<AttendanceProvider>().checkTodayStatus(authProvider.employeeId);
      }
    });
  }

  Future<void> _updateTasks(List<String> newCompletedList) async {
    final attendanceProvider = context.read<AttendanceProvider>();
    
    if (!attendanceProvider.isClockedIn || attendanceProvider.activeLogId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be clocked in to update your tasks.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final apiService = context.read<ApiService>();
      await apiService.updateWorkLogTasks(
        attendanceProvider.activeLogId!,
        newCompletedList,
      );
      // Reload from server to reflect
      final authProvider = context.read<AuthProvider>();
      if (authProvider.employeeId != null) {
        await attendanceProvider.checkTodayStatus(authProvider.employeeId);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update tasks: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    
    final tasks = authProvider.dailyTasks;
    final currentCompleted = attendanceProvider.completedTasks;
    
    final completedCount = currentCompleted.length;
    final totalCount = tasks.length;
    final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Daily Tasks'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No daily tasks assigned.',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Progress Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Daily Progress',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '$completedCount / $totalCount Done',
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Task List
                      Expanded(
                        child: ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final isChecked = currentCompleted.contains(task);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isChecked ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: isChecked,
                                activeColor: Colors.green,
                                checkColor: Colors.white,
                                title: Text(
                                  task,
                                  style: TextStyle(
                                    fontWeight: isChecked ? FontWeight.normal : FontWeight.w500,
                                    decoration: isChecked ? TextDecoration.lineThrough : null,
                                    color: isChecked ? Colors.grey : Colors.black87,
                                  ),
                                ),
                                onChanged: (val) {
                                  if (!attendanceProvider.isClockedIn) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please clock in before completing tasks.'), backgroundColor: Colors.orange),
                                    );
                                    return;
                                  }
                                  
                                  List<String> updated = List.from(currentCompleted);
                                  if (val == true) {
                                    updated.add(task);
                                  } else {
                                    updated.remove(task);
                                  }
                                  _updateTasks(updated);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
