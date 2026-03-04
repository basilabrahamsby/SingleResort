import 'package:flutter/material.dart';
import 'package:orchid_employee/data/services/api_service.dart';
import 'package:orchid_employee/presentation/providers/auth_provider.dart';
import 'package:orchid_employee/presentation/providers/attendance_provider.dart';
import 'package:orchid_employee/core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:orchid_employee/presentation/providers/leave_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isClockedIn = false;
  bool _isLoading = false;
  DateTime? _clockInTime;
  int? _activeLogId;
  List<String> _completedTasks = [];
  
  @override
  void initState() {
    super.initState();
    _checkClockInStatus();
    
    // Fetch attendance and leave data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final attendanceProvider = context.read<AttendanceProvider>();
      final leaveProvider = context.read<LeaveProvider>();
      
      if (authProvider.employeeId != null) {
        attendanceProvider.fetchWorkLogs(authProvider.employeeId!);
        leaveProvider.fetchLeaves(authProvider.employeeId!);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // When we reach here, permissions are granted and we can
      // continue accessing the position of the device.
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      print("Location error: $e");
      return null;
    }
  }

  Future<void> _checkClockInStatus() async {
    final authProvider = context.read<AuthProvider>();
    final employeeId = authProvider.employeeId;
    
    if (employeeId == null) return;
    
    try {
      final apiService = ApiService();
      final response = await apiService.getWorkLogs(employeeId);
      
      if (response.statusCode == 200 && response.data is List) {
        final logs = response.data as List;
        if (logs.isNotEmpty) {
          final now = DateTime.now();
          final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          
          final todayLog = logs.firstWhere(
            (log) => log['date'] == todayStr,
            orElse: () => null,
          );
          
          if (todayLog != null && todayLog['check_out_time'] == null) {
            // Backend stores in UTC, convert to IST
            try {
              final utcDateTime = DateTime.parse('${todayLog['date']}T${todayLog['check_in_time']}Z');
              final istDateTime = utcDateTime.add(Duration(hours: 5, minutes: 30));
              
              setState(() {
                _isClockedIn = true;
                _clockInTime = istDateTime;
                _activeLogId = todayLog['id'];
                
                if (todayLog['completed_tasks'] != null) {
                  try {
                    List<dynamic> parsed = jsonDecode(todayLog['completed_tasks']);
                    _completedTasks = parsed.map((e) => e.toString()).toList();
                  } catch (_) {
                    _completedTasks = [];
                  }
                } else {
                  _completedTasks = [];
                }
              });
            } catch (e) {
              print('Error parsing clock-in time: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error checking clock-in status: $e');
    }
  }

  Future<void> _handleClockInOut() async {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final employeeId = authProvider.employeeId;
    
    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Employee ID not found")),
      );
      return;
    }

    final tasks = authProvider.dailyTasks;

    if (tasks.isEmpty) {
      // No tasks, proceed directly
      await _executeClockInOut(context, authProvider, attendanceProvider, employeeId);
      return;
    }

    // Show dialog with checklist
    List<String> currentCompleted = _isClockedIn 
        ? List<String>.from(_completedTasks)
        : []; 
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool allChecked = true;
            for (String t in tasks) {
              if (!currentCompleted.contains(t)) {
                allChecked = false;
                break;
              }
            }

            return AlertDialog(
              title: Text(!_isClockedIn ? 'Pre-Shift Task Check' : 'End-Shift Task Check'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      !_isClockedIn 
                          ? 'Please acknowledge your assigned daily tasks for today before starting.'
                          : 'Please confirm completion of all your daily tasks before leaving.',
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
                              setDialogState(() {
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

                    await _executeClockInOut(context, authProvider, attendanceProvider, employeeId, tasksToSync: currentCompleted);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allChecked ? Colors.green : Colors.grey,
                  ),
                  child: Text(!_isClockedIn ? 'Acknowledge & Clock In' : 'Complete & Clock Out', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeClockInOut(BuildContext context, AuthProvider authProvider, AttendanceProvider attendanceProvider, int employeeId, {List<String>? tasksToSync}) async {
    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();
      
      if (_isClockedIn) {
        // Update backend with tasks completed if tracking
        if (tasksToSync != null && _activeLogId != null) {
           try {
             await apiService.updateWorkLogTasks(_activeLogId!, tasksToSync);
           } catch (e) {
             print("Failed to sync tasks: $e");
           }
        }

        // Clock Out
        final response = await apiService.clockOut(employeeId);
        if (response.statusCode == 200) {
          setState(() {
            _isClockedIn = false;
            _clockInTime = null;
          });
          // Refresh work logs
          attendanceProvider.fetchWorkLogs(employeeId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✓ Clocked Out Successfully")),
            );
          }
        }
      } else {
        // Clock In
        Position? position = await _getCurrentLocation();
        final response = await apiService.clockIn(
          employeeId, 
          "Mobile App",
          latitude: position?.latitude,
          longitude: position?.longitude,
        );
        if (response.statusCode == 200) {
          int? newLogId = response.data?['id'];
          setState(() {
            _isClockedIn = true;
            _clockInTime = DateTime.now();
            if (newLogId != null) _activeLogId = newLogId;
            if (tasksToSync != null) {
              _completedTasks = List.from(tasksToSync);
            }
          });
          
          if (tasksToSync != null && newLogId != null && tasksToSync.isNotEmpty) {
             try {
               await apiService.updateWorkLogTasks(newLogId, tasksToSync);
             } catch(e) {
               print("Failed to sync initial tasks on clock in: $e");
             }
          }

          // Refresh work logs
          await attendanceProvider.checkTodayStatus(employeeId);
          await attendanceProvider.fetchWorkLogs(employeeId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✓ Clocked In Successfully")),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: Column(
            children: [
              // Header with Clock In/Out
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isClockedIn 
                        ? [Colors.green, Colors.green.shade700]
                        : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        Expanded(
                          child: Text(
                            "Attendance & Profile",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (authProvider.employeeId != null) {
                              attendanceProvider.fetchWorkLogs(authProvider.employeeId!);
                            }
                          },
                          icon: Icon(Icons.refresh, color: Colors.white),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Clock In/Out Card
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _isClockedIn ? "You're Clocked In" : "Ready to Start?",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            DateFormat('hh:mm a').format(DateTime.now()),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isClockedIn && _clockInTime != null) ...[
                            SizedBox(height: 8),
                            Text(
                              "Clocked in at ${DateFormat('hh:mm a').format(_clockInTime!)}",
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleClockInOut,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _isClockedIn ? Colors.green : AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      _isClockedIn ? "CLOCK OUT" : "CLOCK IN",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tabs
              Container(
                color: Colors.white,
                child: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  isScrollable: true,
                  tabs: [
                    Tab(icon: Icon(Icons.access_time, size: 20), text: 'History'),
                    Tab(icon: Icon(Icons.beach_access, size: 20), text: 'Leaves'),
                    Tab(icon: Icon(Icons.payments, size: 20), text: 'Payments'),
                    Tab(icon: Icon(Icons.info_outline, size: 20), text: 'Details'),
                  ],
                ),
              ),
              
              // Tab Content
              Expanded(
                child: TabBarView(
                  children: [
                    _AttendanceHistoryTab(),
                    _LeavesTab(),
                    _PaymentsTab(),
                    _DetailsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Attendance History Tab
class _AttendanceHistoryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final workLogs = attendanceProvider.workLogs;

    return RefreshIndicator(
      onRefresh: () async {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.employeeId != null) {
          await attendanceProvider.fetchWorkLogs(authProvider.employeeId!);
        }
      },
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Summary Card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'This Month',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                  Expanded(
                    child: _SummaryItem(
                      icon: Icons.event_available,
                      label: 'Days Worked',
                      value: '${_groupLogsByDate(workLogs).length}',
                      color: Colors.white,
                    ),
                  ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _SummaryItem(
                        icon: Icons.access_time,
                        label: 'Total Hours',
                        value: _calculateTotalHours(workLogs),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // History Header
          Row(
            children: [
              Icon(Icons.history, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Attendance History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Work Logs List - Grouped by Date
          if (workLogs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Text(
                      'No attendance records found',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._groupLogsByDate(workLogs).entries.map((entry) {
              final date = entry.key;
              final dayLogs = entry.value;
              
              // Calculate total duration for the day
              int totalMinutes = 0;
              bool hasActiveLog = false;
              
              for (var log in dayLogs) {
                if (log['clockOut'] == null) {
                  hasActiveLog = true;
                } else if (log['clockIn'] != null && log['clockOut'] != null) {
                  totalMinutes += (log['clockOut'] as DateTime)
                      .difference(log['clockIn'] as DateTime)
                      .inMinutes;
                }
              }
              
              final totalHours = totalMinutes ~/ 60;
              final remainingMinutes = totalMinutes % 60;
              
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Header
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.calendar_today,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE, MMM dd, yyyy').format(DateTime.parse(date)),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  hasActiveLog 
                                      ? 'Currently working'
                                      : 'Total: ${totalHours}h ${remainingMinutes}m',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: hasActiveLog ? Colors.green : Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasActiveLog)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      SizedBox(height: 12),
                      Divider(height: 1),
                      SizedBox(height: 12),
                      
                      // All clock-in/out entries for this day
                      ...dayLogs.asMap().entries.map((logEntry) {
                        final index = logEntry.key;
                        final log = logEntry.value;
                        final clockIn = log['clockIn'] as DateTime?;
                        final clockOut = log['clockOut'] as DateTime?;
                        
                        final duration = clockIn != null && clockOut != null
                            ? clockOut.difference(clockIn)
                            : null;
                        
                        return Padding(
                          padding: EdgeInsets.only(bottom: index < dayLogs.length - 1 ? 12 : 0),
                          child: Row(
                            children: [
                              // Entry number badge
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.login, size: 14, color: Colors.green),
                                        SizedBox(width: 6),
                                        Text(
                                          clockIn != null 
                                              ? DateFormat('hh:mm a').format(clockIn)
                                              : 'N/A',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                        SizedBox(width: 16),
                                        Icon(Icons.logout, size: 14, color: Colors.red),
                                        SizedBox(width: 6),
                                        Text(
                                          clockOut != null 
                                              ? DateFormat('hh:mm a').format(clockOut)
                                              : 'Working',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    if (duration != null) ...[
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.timer, size: 12, color: Colors.blue),
                                          SizedBox(width: 6),
                                          Text(
                                            '${duration.inHours}h ${duration.inMinutes % 60}m',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  String _calculateTotalHours(List<dynamic> workLogs) {
    int totalMinutes = 0;
    
    for (var log in workLogs) {
      try {
        if (log['date'] != null && log['check_in_time'] != null && log['check_out_time'] != null) {
          // Backend stores in UTC, convert to IST
          final utcIn = DateTime.parse('${log['date']}T${log['check_in_time']}Z');
          final utcOut = DateTime.parse('${log['date']}T${log['check_out_time']}Z');
          final clockIn = utcIn.add(Duration(hours: 5, minutes: 30));
          final clockOut = utcOut.add(Duration(hours: 5, minutes: 30));
          totalMinutes += clockOut.difference(clockIn).inMinutes;
        }
      } catch (e) {
        print('Error calculating hours: $e');
      }
    }
    
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    
    return '${hours}h ${minutes}m';
  }

  Map<String, List<Map<String, dynamic>>> _groupLogsByDate(List<dynamic> workLogs) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (var log in workLogs) {
      try {
        final date = log['date'] as String?;
        if (date == null) continue;
        
        DateTime? clockIn;
        DateTime? clockOut;
        
        // Backend stores in UTC, convert to IST
        if (log['check_in_time'] != null) {
          final utcIn = DateTime.parse('${date}T${log['check_in_time']}Z');
          clockIn = utcIn.add(Duration(hours: 5, minutes: 30));
        }
        
        if (log['check_out_time'] != null) {
          final utcOut = DateTime.parse('${date}T${log['check_out_time']}Z');
          clockOut = utcOut.add(Duration(hours: 5, minutes: 30));
        }
        
        if (!grouped.containsKey(date)) {
          grouped[date] = [];
        }
        
        grouped[date]!.add({
          'clockIn': clockIn,
          'clockOut': clockOut,
        });
      } catch (e) {
        print('Error grouping log: $e');
      }
    }
    
    // Sort by date descending
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    
    return Map.fromEntries(sortedEntries);
  }
}

// Leaves Tab
class _LeavesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final leaveProvider = context.watch<LeaveProvider>();
    final leaves = leaveProvider.leaves;
    
    return RefreshIndicator(
      onRefresh: () async {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.employeeId != null) {
          await leaveProvider.fetchLeaves(authProvider.employeeId!);
        }
      },
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Leave Balance Card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.purple.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.beach_access, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Leave Balance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryItem(
                        icon: Icons.event_available,
                        label: 'Available',
                        value: '${leaveProvider.availableLeaves - leaveProvider.usedLeaves}',
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _SummaryItem(
                        icon: Icons.event_busy,
                        label: 'Used',
                        value: '${leaveProvider.usedLeaves}',
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Apply Leave Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showApplyLeaveDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.add_circle_outline),
              label: Text(
                'Apply for Leave',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Leave History Header
          Row(
            children: [
              Icon(Icons.history, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Leave History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Leave Records from API
          if (leaveProvider.isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (leaves.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.beach_access_outlined, size: 64, color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Text(
                      'No leave records found',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...leaves.map((leave) {
              final fromDate = DateTime.parse(leave['from_date']);
              final toDate = DateTime.parse(leave['to_date']);
              final days = toDate.difference(fromDate).inDays + 1;
              
              return _LeaveCard(
                type: leave['type'] ?? 'Leave',
                startDate: DateFormat('yyyy-MM-dd').format(fromDate),
                endDate: DateFormat('yyyy-MM-dd').format(toDate),
                days: days,
                status: _capitalizeFirst(leave['status'] ?? 'pending'),
                reason: leave['reason'] ?? 'No reason provided',
              );
            }).toList(),
        ],
      ),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _showApplyLeaveDialog(BuildContext context) {
    final leaveProvider = context.read<LeaveProvider>();
    final authProvider = context.read<AuthProvider>();
    
    String selectedLeaveType = 'Paid';
    DateTime? fromDate;
    DateTime? toDate;
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: EdgeInsets.all(24),
              constraints: BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.beach_access, color: AppColors.primary, size: 24),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Apply for Leave',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    
                    // Leave Type Dropdown
                    Text(
                      'Leave Type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedLeaveType,
                          isExpanded: true,
                          items: ['Paid', 'Sick', 'Long', 'Wellness'].map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Icon(
                                    type == 'Paid' ? Icons.event_available :
                                    type == 'Sick' ? Icons.local_hospital :
                                    type == 'Long' ? Icons.flight_takeoff :
                                    Icons.spa,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 12),
                                  Text('$type Leave'),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedLeaveType = value!;
                            });
                          },
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // From Date
                    Text(
                      'From Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            fromDate = picked;
                            // Reset toDate if it's before fromDate
                            if (toDate != null && toDate!.isBefore(fromDate!)) {
                              toDate = null;
                            }
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                            SizedBox(width: 12),
                            Text(
                              fromDate != null 
                                  ? DateFormat('MMM dd, yyyy').format(fromDate!)
                                  : 'Select start date',
                              style: TextStyle(
                                fontSize: 15,
                                color: fromDate != null ? Colors.black87 : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // To Date
                    Text(
                      'To Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    InkWell(
                      onTap: fromDate == null ? null : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fromDate!,
                          firstDate: fromDate!,
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            toDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: fromDate == null ? Colors.grey.shade200 : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: fromDate == null ? Colors.grey.shade50 : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: fromDate == null ? Colors.grey.shade400 : AppColors.primary,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(
                              toDate != null 
                                  ? DateFormat('MMM dd, yyyy').format(toDate!)
                                  : 'Select end date',
                              style: TextStyle(
                                fontSize: 15,
                                color: toDate != null 
                                    ? Colors.black87 
                                    : fromDate == null 
                                        ? Colors.grey.shade400 
                                        : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Days count
                    if (fromDate != null && toDate != null) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_note, size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              '${toDate!.difference(fromDate!).inDays + 1} day(s)',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    SizedBox(height: 20),
                    
                    // Reason
                    Text(
                      'Reason',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter reason for leave...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (fromDate == null || toDate == null || reasonController.text.trim().isEmpty)
                            ? null
                            : () async {
                                final employeeId = authProvider.employeeId;
                                if (employeeId == null) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(content: Text('Employee ID not found')),
                                  );
                                  return;
                                }
                                
                                try {
                                  await leaveProvider.applyLeave(
                                    employeeId: employeeId,
                                    fromDate: fromDate!,
                                    toDate: toDate!,
                                    reason: reasonController.text.trim(),
                                    type: selectedLeaveType,
                                  );
                                  
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(
                                      content: Text('✓ Leave application submitted successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  
                                  // Refresh leave data
                                  leaveProvider.fetchLeaves(employeeId);
                                } catch (e) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: Text(
                          'Submit Application',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Payments Tab
class _PaymentsTab extends StatefulWidget {
  @override
  _PaymentsTabState createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  Map<String, dynamic>? employeeData;
  List<dynamic> salaryPayments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployeeData();
  }

  Future<void> _fetchEmployeeData() async {
    final authProvider = context.read<AuthProvider>();
    final employeeId = authProvider.employeeId;
    
    if (employeeId == null) return;
    
    try {
      final apiService = ApiService();
      
      // Fetch employee details and salary payments in parallel
      final results = await Future.wait([
        apiService.getEmployeeDetails(employeeId),
        apiService.getSalaryPayments(employeeId),
      ]);
      
      final employeeResponse = results[0];
      final paymentsResponse = results[1];
      
      setState(() {
        if (employeeResponse.statusCode == 200 && employeeResponse.data != null) {
          employeeData = employeeResponse.data as Map<String, dynamic>;
        }
        
        if (paymentsResponse.statusCode == 200 && paymentsResponse.data is List) {
          salaryPayments = paymentsResponse.data as List;
        }
        
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching employee data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final salary = employeeData?['salary'] ?? 0.0;
    final formattedSalary = salary.toStringAsFixed(0);
    
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Current Month Salary Card
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Current Month',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Monthly Salary',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      '₹ $formattedSalary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ],
          ),
        ),
        
        SizedBox(height: 24),
        
        // Salary Breakdown
        if (!isLoading && employeeData != null) ...[
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: AppColors.primary, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Salary Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                _SalaryRow(label: 'Basic Salary', amount: salary, isTotal: false),
                Divider(height: 24),
                _SalaryRow(label: 'Net Salary', amount: salary, isTotal: true),
              ],
            ),
          ),
          
          SizedBox(height: 24),
        ],
        
        // Payment History Header
        Row(
          children: [
            Icon(Icons.history, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'Payment History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        // Payment Records
        if (isLoading)
          Center(child: CircularProgressIndicator())
        else if (salaryPayments.isEmpty)
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                SizedBox(height: 16),
                Text(
                  'No Payment Records',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Payment history will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...salaryPayments.map((payment) {
            final month = payment['month'] ?? 'Unknown';
            final basicSalary = payment['basic_salary'] ?? 0.0;
            final allowances = payment['allowances'] ?? 0.0;
            final deductions = payment['deductions'] ?? 0.0;
            final netSalary = payment['net_salary'] ?? 0.0;
            final paymentDate = payment['payment_date'] ?? 'N/A';
            final status = payment['payment_status'] ?? 'pending';
            
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status == 'paid' ? Colors.green.shade200 : Colors.orange.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            month,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: status == 'paid' 
                              ? Colors.green.shade100 
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status == 'paid' ? 'Paid' : 'Pending',
                          style: TextStyle(
                            color: status == 'paid' 
                                ? Colors.green.shade700 
                                : Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 12),
                  _PaymentRow(label: 'Basic Salary', amount: basicSalary),
                  _PaymentRow(label: 'Allowances', amount: allowances, isPositive: true),
                  _PaymentRow(label: 'Deductions', amount: deductions, isNegative: true),
                  SizedBox(height: 8),
                  Divider(height: 1),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Salary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      Text(
                        '₹ ${netSalary.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  if (status == 'paid') ...[
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                        SizedBox(width: 6),
                        Text(
                          'Paid on $paymentDate',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
      ],
    );
  }
}

// Salary Row Widget
class _SalaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isTotal;

  const _SalaryRow({
    required this.label,
    required this.amount,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.grey[900] : Colors.grey[700],
            ),
          ),
          Text(
            '₹ ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.green.shade700 : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

// Details Tab
class _DetailsTab extends StatefulWidget {
  @override
  _DetailsTabState createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  Map<String, dynamic>? employeeData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployeeData();
  }

  Future<void> _fetchEmployeeData() async {
    final authProvider = context.read<AuthProvider>();
    final employeeId = authProvider.employeeId;
    
    if (employeeId == null) return;
    
    try {
      final apiService = ApiService();
      final response = await apiService.getEmployeeDetails(employeeId);
      
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          employeeData = response.data as Map<String, dynamic>;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching employee data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    final name = employeeData?['name'] ?? authProvider.userName ?? 'N/A';
    final role = employeeData?['role'] ?? 'N/A';
    final salary = employeeData?['salary'] ?? 0.0;
    final joinDate = employeeData?['join_date'] ?? 'N/A';
    final email = employeeData?['user']?['email'] ?? 'N/A';
    final phone = employeeData?['user']?['phone'] ?? 'N/A';
    
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _DetailSection(
          title: 'Personal Information',
          icon: Icons.person,
          items: [
            _DetailItem(label: 'Name', value: name),
            _DetailItem(label: 'Employee ID', value: authProvider.employeeId?.toString() ?? 'N/A'),
            _DetailItem(label: 'Role', value: role),
            _DetailItem(label: 'Join Date', value: joinDate),
          ],
        ),
        
        SizedBox(height: 20),
        
        _DetailSection(
          title: 'Contact Information',
          icon: Icons.contact_phone,
          items: [
            _DetailItem(label: 'Email', value: email),
            _DetailItem(label: 'Phone', value: phone),
          ],
        ),
        
        SizedBox(height: 20),
        
        _DetailSection(
          title: 'Work Information',
          icon: Icons.work,
          items: [
            _DetailItem(label: 'Monthly Salary', value: '₹ ${salary.toStringAsFixed(0)}'),
            _DetailItem(label: 'Employment Type', value: 'Full Time'),
          ],
        ),
      ],
    );
  }
}

// Helper Widgets

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 20),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final String type;
  final String startDate;
  final String endDate;
  final int days;
  final String status;
  final String reason;

  const _LeaveCard({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.status,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = status == 'Approved' 
        ? Colors.green 
        : status == 'Pending' 
            ? Colors.orange 
            : Colors.red;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              SizedBox(width: 6),
              Text(
                '$startDate to $endDate ($days ${days > 1 ? 'days' : 'day'})',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            reason,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final String month;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final double netSalary;
  final String paidOn;

  const _PaymentCard({
    required this.month,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    required this.netSalary,
    required this.paidOn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.all(16),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.account_balance_wallet, color: Colors.green),
        ),
        title: Text(
          month,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          'Paid on: $paidOn',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Text(
          '₹ ${netSalary.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        children: [
          Divider(),
          _PaymentRow(label: 'Basic Salary', amount: basicSalary, isPositive: true),
          _PaymentRow(label: 'Allowances', amount: allowances, isPositive: true),
          _PaymentRow(label: 'Deductions', amount: deductions, isPositive: false),
          Divider(),
          _PaymentRow(label: 'Net Salary', amount: netSalary, isPositive: true, isBold: true),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isPositive;
  final bool isNegative;
  final bool isBold;

  const _PaymentRow({
    required this.label,
    required this.amount,
    this.isPositive = false,
    this.isNegative = false,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor;
    String prefix;
    
    if (isNegative) {
      textColor = Colors.red;
      prefix = '-';
    } else if (isPositive) {
      textColor = Colors.green;
      prefix = '+';
    } else {
      textColor = Colors.grey[800]!;
      prefix = '';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[700],
            ),
          ),
          Text(
            '$prefix ₹ ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_DetailItem> items;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          ...items,
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
