class ServiceRequest {
  final String id;
  final String roomNumber;
  final String type; // 'Towels', 'Toiletries', 'Cleaning', 'Maintenance', 'Other'
  final String description;
  final String priority; // 'Low', 'Medium', 'High', 'Urgent'
  String status; // 'Pending', 'In Progress', 'Completed'
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? guestName;
  final List<dynamic> refillItems;
  final List<dynamic> foodItems;
  final int? employeeId;
  final String? employeeName;
  final String? preparedByName;
  final String billingStatus; // 'unbilled', 'billed', 'paid'
  final double foodOrderAmount;
  final double foodOrderGst;
  final double foodOrderTotal;

  ServiceRequest({
    required this.id,
    required this.roomNumber,
    required this.type,
    required this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.billingStatus = 'unbilled',
    this.completedAt,
    this.guestName,
    this.refillItems = const [],
    this.foodItems = const [],
    this.employeeId,
    this.employeeName,
    this.preparedByName,
    this.foodOrderAmount = 0.0,
    this.foodOrderGst = 0.0,
    this.foodOrderTotal = 0.0,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    String rawStatus = json['status']?.toString().toLowerCase() ?? 'pending';
    String mappedStatus = 'pending';
    if (rawStatus == 'in_progress' || rawStatus == 'started' || rawStatus == 'in progress') {
        mappedStatus = 'in_progress';
    } else if (rawStatus == 'completed') {
        mappedStatus = 'completed';
    } else if (rawStatus == 'assigned' || rawStatus == 'pending') {
        mappedStatus = 'pending';
    } else {
        mappedStatus = rawStatus;
    }

    return ServiceRequest(
      id: json['id'].toString(),
      roomNumber: json['room_number']?.toString() ?? 'N/A',
      type: json['type']?.toString() ?? 'Other',
      description: json['description']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'Medium',
      status: mappedStatus,
      billingStatus: json['billing_status']?.toString() ?? 'unbilled',
      createdAt: json['created_at'] != null 
          ? _parseDate(json['created_at'].toString())
          : DateTime.now(),
      completedAt: json['completed_at'] != null 
          ? _parseDate(json['completed_at'].toString())
          : null,
      guestName: json['guest_name']?.toString(), // Keep nullable
      refillItems: json['refill_data'] is List ? json['refill_data'] : [],
      foodItems: json['food_items'] is List ? json['food_items'] : [],
      employeeId: json['employee_id'],
      employeeName: json['employee_name']?.toString(),
      preparedByName: json['prepared_by_name']?.toString(),
      foodOrderAmount: double.tryParse(json['food_order_amount']?.toString() ?? '0') ?? 0.0,
      foodOrderGst: double.tryParse(json['food_order_gst']?.toString() ?? '0') ?? 0.0,
      foodOrderTotal: double.tryParse(json['food_order_total']?.toString() ?? '0') ?? 0.0,
    );
  }

  static DateTime _parseDate(String dateStr) {
    if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
      // If it doesn't have timezone info, assume it's UTC from backend
      dateStr += 'Z';
    }
    return DateTime.parse(dateStr).toLocal();
  }
}

