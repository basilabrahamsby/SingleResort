import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart'; // Needed for FormData
import '../models/employee.dart';
import '../models/leave.dart';
import '../models/employee_status_overview.dart';
import '../models/staff_history.dart';
import '../models/working_log.dart';
import '../models/monthly_report.dart';

class StaffProvider with ChangeNotifier {
  final ApiService _apiService;
  List<Employee> _employees = [];
  bool _isLoading = false;

  EmployeeStatusOverview? _statusOverview;
  UserHistory? _userHistory;
  List<WorkingLog> _workLogs = [];
  MonthlyReport? _monthlyReport;

  StaffProvider(this._apiService);

  List<Employee> get employees => _employees;
  EmployeeStatusOverview? get statusOverview => _statusOverview;
  UserHistory? get userHistory => _userHistory;
  List<WorkingLog> get workLogs => _workLogs;
  MonthlyReport? get monthlyReport => _monthlyReport;
  bool get isLoading => _isLoading;

  Future<void> fetchEmployees() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.client.get('/employees');
      if (response.statusCode == 200 && response.data is List) {
        _employees = (response.data as List).map((e) => Employee.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error fetching employees: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStatusOverview() async {
    try {
      final response = await _apiService.client.get('/employees/status-overview');
      if (response.statusCode == 200) {
        _statusOverview = EmployeeStatusOverview.fromJson(response.data);
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching status overview: $e");
    }
  }

  Future<void> fetchUserHistory(int userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.client.get('/reports/user-history', queryParameters: {'user_id': userId});
      if (response.statusCode == 200) {
        _userHistory = UserHistory.fromJson(response.data);
      }
    } catch (e) {
      print("Error fetching user history: $e");
      _userHistory = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchWorkLogs(int employeeId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.client.get('/attendance/work-logs/$employeeId');
      if (response.statusCode == 200 && response.data is List) {
        _workLogs = (response.data as List).map((e) => WorkingLog.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error fetching work logs: $e");
      _workLogs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMonthlyReport(int employeeId, int year, int month) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.client.get('/attendance/monthly-report/$employeeId', 
        queryParameters: {'year': year, 'month': month}
      );
      if (response.statusCode == 200) {
        _monthlyReport = MonthlyReport.fromJson(response.data);
      }
    } catch (e) {
      print("Error fetching monthly report: $e");
      _monthlyReport = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> clockIn(int employeeId, String location) async {
    try {
      double? lat;
      double? lon;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high
          );
          lat = position.latitude;
          lon = position.longitude;
        }
      } catch (e) {
        print("Error fetching GPS coordinates: $e");
      }

      await _apiService.client.post('/attendance/clock-in', data: {
        'employee_id': employeeId, 
        'location': location,
        'latitude': lat,
        'longitude': lon,
      });
      await fetchWorkLogs(employeeId); // Refresh logs
      await fetchEmployees(); // Refresh status
      return true;
    } catch (e) {
      print("Error clocking in: $e");
      return false;
    }
  }

  Future<bool> clockOut(int employeeId) async {
    try {
      await _apiService.client.post('/attendance/clock-out', data: {'employee_id': employeeId});
      await fetchWorkLogs(employeeId); // Refresh logs
      await fetchEmployees(); // Refresh status
      return true;
    } catch (e) {
      print("Error clocking out: $e");
      return false;
    }
  }

  // Leave Management
  List<Leave> _pendingLeaves = [];
  List<Leave> get pendingLeaves => _pendingLeaves;

  Future<void> fetchPendingLeaves() async {
    try {
      final response = await _apiService.client.get('/employees/pending-leaves');
      if (response.statusCode == 200 && response.data is List) {
        _pendingLeaves = (response.data as List).map((e) => Leave.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching pending leaves: $e");
    }
  }

  Future<void> updateLeaveStatus(int id, String status) async {
    try {
      await _apiService.client.put('/employees/leave/$id/status/$status');
      _pendingLeaves.removeWhere((l) => l.id == id);
      notifyListeners();
    } catch (e) {
      print("Error updating leave status: $e");
      rethrow;
    }
  }

  // Employee Leaves (Specific to an employee)
  List<Leave> _employeeLeaves = [];
  List<Leave> get employeeLeaves => _employeeLeaves;

  Future<void> fetchEmployeeLeaves(int employeeId) async {
    try {
      final response = await _apiService.client.get('/employees/leave/$employeeId');
      if (response.statusCode == 200 && response.data is List) {
        _employeeLeaves = (response.data as List).map((e) => Leave.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching employee leaves: $e");
      _employeeLeaves = [];
    }
  }

  Future<bool> addEmployee(Map<String, dynamic> data) async {
    try {
      final formData = FormData.fromMap(data);
      final response = await _apiService.client.post('/employees', data: formData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchEmployees();
        return true;
      }
    } catch (e) {
      print("Error adding employee: $e");
    }
    return false;
  }
}
