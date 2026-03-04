class ServiceModel {
  final int id;
  final String name;
  final String description;
  final double charges;
  final bool isVisibleToGuest;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.charges,
    required this.isVisibleToGuest,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      charges: (json['charges'] ?? 0).toDouble(),
      isVisibleToGuest: json['is_visible_to_guest'] ?? false,
    );
  }
}

class AssignedService {
  final int id;
  final int serviceId;
  final String serviceName;
  final int roomId;
  final String roomNumber;
  final String employeeName;
  final String status;
  final String? billingStatus;
  final String assignedAt;
  final String? startedAt;
  final String? completedAt;

  AssignedService({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.roomId,
    required this.roomNumber,
    required this.employeeName,
    required this.status,
    this.billingStatus,
    required this.assignedAt,
    this.startedAt,
    this.completedAt,
  });

  factory AssignedService.fromJson(Map<String, dynamic> json) {
    return AssignedService(
      id: json['id'] ?? 0,
      serviceId: json['service']?['id'] ?? json['service_id'] ?? 0,
      serviceName: json['service']?['name'] ?? json['service_name'] ?? json['request_type'] ?? 'Unknown',
      roomId: json['room']?['id'] ?? json['room_id'] ?? 0,
      roomNumber: json['room']?['number'] ?? json['room_number'] ?? '-',
      employeeName: json['employee']?['name'] ?? json['employee_name'] ?? '-',
      status: json['status'] ?? 'pending',
      billingStatus: json['billing_status'] ?? 'unbilled',
      assignedAt: json['assigned_at'] ?? json['created_at'] ?? '',
      startedAt: json['started_at'],
      completedAt: json['completed_at'] ?? json['last_used_at'],
    );
  }
}
