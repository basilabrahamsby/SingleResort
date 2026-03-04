class ServiceRequest {
  final int id;
  final String requestType;
  final String description;
  final String status;
  final String createdAt;
  final String roomNumber;
  final String employeeName;
  final bool isCheckoutRequest;
  final bool isAssignedService;
  final int? assignedServiceId;
  final String? completedAt;
  final String? billingStatus;
  final List<dynamic>? assetDamages;
  final List<dynamic>? inventoryData;
  final List<dynamic>? refillData;
  final int? pickupLocationId;

  ServiceRequest({
    required this.id,
    required this.requestType,
    required this.description,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.roomNumber,
    required this.employeeName,
    required this.isCheckoutRequest,
    this.isAssignedService = false,
    this.assignedServiceId,
    this.billingStatus,
    this.assetDamages,
    this.inventoryData,
    this.refillData,
    this.pickupLocationId,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] ?? 0,
      requestType: json['request_type'] ?? 'General',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
      completedAt: json['completed_at'],
      roomNumber: json['room_number'] ?? '-',
      employeeName: json['employee_name'] ?? '-',
      isCheckoutRequest: json['is_checkout_request'] ?? false,
      isAssignedService: json['is_assigned_service'] ?? false,
      assignedServiceId: json['assigned_service_id'],
      billingStatus: json['billing_status'] ?? 'unbilled',
      assetDamages: json['asset_damages'],
      inventoryData: json['inventory_data_with_charges'] ?? json['inventory_data'],
      refillData: json['refill_data'],
      pickupLocationId: json['pickup_location_id'],
    );
  }
}
