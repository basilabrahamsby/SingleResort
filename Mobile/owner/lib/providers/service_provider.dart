import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/service.dart';
import '../models/service_request.dart';

class ServiceProvider with ChangeNotifier {
  final ApiService _apiService;
  List<ServiceModel> _services = [];
  List<AssignedService> _assignedServices = [];
  List<ServiceRequest> _requests = [];
  bool _isLoading = false;

  ServiceProvider(this._apiService);

  List<ServiceModel> get services => _services;
  List<AssignedService> get assignedServices => _assignedServices;
  List<ServiceRequest> get requests => _requests;
  bool get isLoading => _isLoading;

  Future<void> fetchServices() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.client.get('/services');
      if (response.statusCode == 200) {
        final List<dynamic> list = response.data ?? [];
        _services = list.map((e) => ServiceModel.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error fetching services: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAssignedServices() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.client.get('/services/assigned');
        if (response.statusCode == 200) {
        final List<dynamic> list = response.data ?? [];
        _assignedServices = list.map((e) => AssignedService.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error fetching assigned services: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRequests() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.client.get('/service-requests');
      if (response.statusCode == 200) {
        final List<dynamic> list = response.data ?? [];
        _requests = list.map((e) => ServiceRequest.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error fetching requests: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRequestStatus(int requestId, String status, {
    String? billingStatus,
    List<Map<String, dynamic>>? inventoryReturns,
    int? returnLocationId,
    int? pickupLocationId,
    int? employeeId,
    String? notes,
  }) async {
    try {
      final Map<String, dynamic> data = {'status': status};
      if (billingStatus != null) data['billing_status'] = billingStatus;
      if (inventoryReturns != null) data['inventory_returns'] = inventoryReturns;
      if (returnLocationId != null) data['return_location_id'] = returnLocationId;
      if (pickupLocationId != null) data['pickup_location_id'] = pickupLocationId;
      if (employeeId != null) data['employee_id'] = employeeId;
      if (notes != null) data['notes'] = notes;

      final response = await _apiService.client.put('/service-requests/$requestId', 
        data: data
      );
      if (response.statusCode == 200) {
        await fetchRequests(); // Refresh
        await fetchAssignedServices();
      }
    } catch (e) {
      print('Error updating request status: $e');
      rethrow;
    }
  }

  Future<void> updateAssignedServiceStatus(int assignedId, String status, {
    String? billingStatus,
    List<Map<String, dynamic>>? inventoryReturns,
    int? returnLocationId,
    String? notes,
  }) async {
    try {
      final Map<String, dynamic> data = {'status': status};
      if (billingStatus != null) data['billing_status'] = billingStatus;
      if (inventoryReturns != null) data['inventory_returns'] = inventoryReturns;
      if (returnLocationId != null) data['return_location_id'] = returnLocationId;
      if (notes != null) data['notes'] = notes;

      final response = await _apiService.client.patch('/services/assigned/$assignedId', 
        data: data
      );
      if (response.statusCode == 200) {
        await fetchRequests(); // Refresh
        await fetchAssignedServices();
      }
    } catch (e) {
      print('Error updating assigned service status: $e');
      rethrow;
    }
  }

  Future<List<ServiceRequest>> fetchRoomRequests(int roomId) async {
    try {
      final response = await _apiService.client.get('/service-requests', queryParameters: {'room_id': roomId});
      if (response.statusCode == 200) {
        final List<dynamic> list = response.data ?? [];
        return list.map((e) => ServiceRequest.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error fetching room requests: $e');
    }
    return [];
  }

  Future<bool> createRequest(Map<String, dynamic> data) async {
    try {
       final response = await _apiService.client.post('/service-requests', data: data);
       if (response.statusCode == 200) {
         return true;
       }
    } catch (e) {
       print('Error creating request: $e');
    }
    return false;
  }

  Future<List<dynamic>> fetchAssignedServiceInventory(int assignedId) async {
    try {
      final response = await _apiService.client.get('/services/assigned/$assignedId/inventory');
      if (response.statusCode == 200) {
        return response.data ?? [];
      }
    } catch (e) {
      print('Error fetching assigned service inventory: $e');
    }
    return [];
  }
}
