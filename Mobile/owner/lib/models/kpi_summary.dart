class DepartmentExpense {
  final String department;
  final double amount;
  final double percentage;

  DepartmentExpense({required this.department, required this.amount, required this.percentage});

  factory DepartmentExpense.fromJson(Map<String, dynamic> json) {
    return DepartmentExpense(
      department: json['department'] ?? 'Unknown',
      amount: (json['amount'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class KpiSummary {
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final int totalBookings;
  final int roomBookings;
  final int packageBookings; // Added
  final int foodOrders;
  final Map<String, dynamic> departmentKpis;
  final double totalOutputTax;
  final double totalInputTax;
  final List<DepartmentExpense> departmentExpenses;
  final Map<String, dynamic> revenueByMode;

  // New Fields
  final int assignedServices;
  final int completedServices;
  final double totalServiceRevenue;
  final int foodItemsAvailable;
  final int activeEmployees;
  final int onlineEmployees;
  final int inventoryCategories;
  final int inventoryDepartments;
  final double totalPurchases;
  final int activeVendors;
  final int purchaseCount;
  final int sellableItemsCount;
  final int lowStockItemsCount;
  final int inventoryItems;
  final double totalInventoryValue;

  KpiSummary({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.totalBookings,
    required this.roomBookings,
    this.packageBookings = 0,
    required this.foodOrders,
    required this.departmentKpis,
    this.totalOutputTax = 0.0,
    this.totalInputTax = 0.0,
    this.departmentExpenses = const [],
    this.revenueByMode = const {},
    this.assignedServices = 0,
    this.completedServices = 0,
    this.totalServiceRevenue = 0.0,
    this.foodItemsAvailable = 0,
    this.activeEmployees = 0,
    this.onlineEmployees = 0,
    this.inventoryCategories = 0,
    this.inventoryDepartments = 0,
    this.totalPurchases = 0.0,
    this.activeVendors = 0,
    this.purchaseCount = 0,
    this.sellableItemsCount = 0,
    this.lowStockItemsCount = 0,
    this.inventoryItems = 0,
    this.totalInventoryValue = 0.0,
  });

  factory KpiSummary.fromJson(Map<String, dynamic> json) {
    // Structure from /dashboard/summary is flat
    
    // Net Profit might not be explicitly sent, so calculate it
    var rawDepts = json['department_expenses'] as List<dynamic>? ?? [];
    List<DepartmentExpense> deptExpenses = rawDepts.map((i) => DepartmentExpense.fromJson(i)).toList();

    return KpiSummary(
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      totalExpenses: (json['total_expenses'] ?? 0).toDouble(),
      netProfit: ((json['total_revenue'] ?? 0) - (json['total_expenses'] ?? 0)).toDouble(),
      totalBookings: json['total_bookings'] ?? 0,
      roomBookings: json['room_bookings'] ?? 0,
      packageBookings: json['package_bookings'] ?? 0, // Added
      foodOrders: json['food_orders'] ?? 0,
      departmentKpis: json['department_kpis'] ?? {},
      totalOutputTax: (json['total_output_tax'] ?? 0).toDouble(),
      totalInputTax: (json['total_input_tax'] ?? 0).toDouble(),
      departmentExpenses: deptExpenses,
      revenueByMode: json['revenue_by_mode'] ?? {},
      
      // New Fields
      assignedServices: json['assigned_services'] ?? 0,
      completedServices: json['completed_services'] ?? 0,
      totalServiceRevenue: (json['total_service_revenue'] ?? 0).toDouble(),
      foodItemsAvailable: json['food_items_available'] ?? 0,
      activeEmployees: json['active_employees'] ?? 0,
      onlineEmployees: json['online_employees'] ?? 0,
      inventoryCategories: json['inventory_categories'] ?? 0,
      inventoryDepartments: json['inventory_departments'] ?? 0,
      totalPurchases: (json['total_purchases'] ?? 0).toDouble(),
      activeVendors: json['vendor_count'] ?? 0,
      purchaseCount: json['purchase_count'] ?? 0,
      sellableItemsCount: json['sellable_items_count'] ?? 0,
      lowStockItemsCount: json['low_stock_items_count'] ?? 0,
      inventoryItems: json['inventory_items'] ?? 0,
      totalInventoryValue: (json['total_inventory_value'] ?? 0).toDouble(),
    );
  }
}
