import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orchid_employee/data/models/service_request_model.dart';
import 'package:orchid_employee/core/constants/app_colors.dart';
import 'package:orchid_employee/presentation/providers/service_request_provider.dart';
import 'package:intl/intl.dart';
import 'package:orchid_employee/presentation/providers/inventory_provider.dart';
import 'package:orchid_employee/presentation/providers/kitchen_provider.dart';
import 'package:orchid_employee/presentation/providers/auth_provider.dart';
import 'service_request_dialogs.dart';
import 'package:orchid_employee/presentation/providers/attendance_provider.dart';
import 'package:orchid_employee/presentation/screens/housekeeping/checkout_verification_dialog.dart';

class ServiceRequestsScreen extends StatefulWidget {
  const ServiceRequestsScreen({super.key});

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen> {
  String _selectedFilter = 'All'; // All, Pending, In Progress, Completed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceRequestProvider>().fetchRequests();
      context.read<KitchenProvider>().fetchEmployees();
    });
  }

  void _showAssignDialog(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Assign Employee"),
        content: Consumer<KitchenProvider>(
          builder: (context, kitchen, _) {
            if (kitchen.isLoading && kitchen.employees.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: kitchen.employees.length,
                itemBuilder: (context, index) {
                  final emp = kitchen.employees[index];
                  return ListTile(
                    title: Text(emp['name']),
                    subtitle: Text(emp['role']),
                    trailing: request.employeeId == emp['id'] 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () async {
                      final success = await context.read<ServiceRequestProvider>().assignEmployee(request.id, emp['id']);
                      if (success && mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Assigned to ${emp['name']}"))
                        );
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  List<ServiceRequest> _getFilteredRequests(List<ServiceRequest> requests) {
    if (_selectedFilter == 'All') return requests;
    final normalizedFilter = _selectedFilter.toLowerCase().replaceAll('_', ' ');
    return requests.where((r) {
      final normalizedStatus = r.status.toLowerCase().replaceAll('_', ' ');
      return normalizedStatus == normalizedFilter;
    }).toList();
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'towels':
        return Icons.dry_cleaning;
      case 'toiletries':
        return Icons.soap;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.room_service;
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = context.watch<ServiceRequestProvider>();
    final allRequests = requestProvider.requests;
    final filteredRequests = _getFilteredRequests(allRequests);

    final pendingCount = allRequests.where((r) => r.status.toLowerCase() == 'pending').length;
    final inProgressCount = allRequests.where((r) {
      final status = r.status.toLowerCase().replaceAll('_', ' ');
      return status == 'in progress';
    }).length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Service Requests", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Stats Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                _StatChip(
                  label: "Pending",
                  count: pendingCount,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  label: "In Progress",
                  count: inProgressCount,
                  color: Colors.blue,
                ),
              ],
            ),
          ),

          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Pending', 'In Progress', 'Completed']
                    .map((filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _selectedFilter == filter,
                            onSelected: (selected) {
                              setState(() => _selectedFilter = filter);
                            },
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: _selectedFilter == filter
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),

          // Requests List
          Expanded(
            child: (requestProvider.isLoading && requestProvider.requests.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : requestProvider.error != null
                    ? Center(child: Text(requestProvider.error!))
                    : RefreshIndicator(
                        onRefresh: () async {
                           await requestProvider.fetchRequests();
                        },
                        child: filteredRequests.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      "No $_selectedFilter requests",
                                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredRequests.length,
                                itemBuilder: (context, index) {
                                  final request = filteredRequests[index];
                                  return _RequestCard(
                                    request: request,
                                    onUpdateStatus: (req, status) async {
                                      final ok = await requestProvider.updateRequestStatus(req.id, status);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(ok
                                              ? 'Status updated to ${status.toUpperCase()}'
                                              : 'Failed to update: ${requestProvider.error ?? "Unknown error"}'),
                                            backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            duration: Duration(seconds: ok ? 2 : 4),
                                          ),
                                        );
                                      }
                                      return ok;
                                    },
                                    onAssign: () => _showAssignDialog(request),
                                    priorityColor: _getPriorityColor(request.priority),
                                    typeIcon: _getTypeIcon(request.type),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$count",
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  final ServiceRequest request;
  final Future<bool> Function(ServiceRequest, String) onUpdateStatus;
  final VoidCallback onAssign;
  final Color priorityColor;
  final IconData typeIcon;

  const _RequestCard({
    required this.request,
    required this.onUpdateStatus,
    required this.onAssign,
    required this.priorityColor,
    required this.typeIcon,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _isUpdating = false;

  Future<void> _doUpdate(String status, [String? billingStatus]) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final requestProvider = context.read<ServiceRequestProvider>();
      final empId = context.read<AuthProvider>().employeeId;
      await requestProvider.updateRequestStatus(
        widget.request.id, 
        status, 
        employeeId: empId,
        billingStatus: billingStatus,
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final priorityColor = widget.priorityColor;
    final typeIcon = widget.typeIcon;
    final minutesAgo = DateTime.now().difference(request.createdAt).inMinutes;
    final timeAgo = minutesAgo < 60
        ? "$minutesAgo min ago"
        : "${(minutesAgo / 60).floor()}h ago";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeIcon, color: priorityColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Room ${request.roomNumber}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: priorityColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              request.priority,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.type,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request.guestName != null) ...[
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        request.guestName!,
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  request.description,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_pin, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      request.employeeName ?? "Not assigned",
                      style: TextStyle(
                        color: request.employeeId != null ? Colors.blue[700] : Colors.grey[600],
                        fontWeight: request.employeeId != null ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                         if (auth.role == UserRole.manager || auth.role == UserRole.kitchen) {
                           return InkWell(
                             onTap: widget.onAssign,
                             child: Text(
                               request.employeeId != null ? "Change" : "Assign",
                               style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                             ),
                           );
                         }
                         return const SizedBox.shrink();
                      }
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons
                if (request.status.toLowerCase() == 'pending')
                  _isUpdating
                  ? const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: CircularProgressIndicator(strokeWidth: 2)))
                  : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                              if (!context.read<AttendanceProvider>().isClockedIn) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action Denied: You must Clock In first")));
                                return;
                              }

                              final isFoodService = request.type.toLowerCase().contains('food') || 
                                                    request.description.toLowerCase().contains('food') ||
                                                    request.type.toLowerCase() == 'delivery';

                               if (isFoodService) {
                                  showDialog(
                                    context: context,
                                    builder: (_) => DeliveryStartDialog(
                                      request: request,
                                      onConfirm: () {
                                        final empId = context.read<AuthProvider>().employeeId;
                                        _doUpdate('in_progress');
                                      },
                                    ),
                                  );
                                  return;
                               }

                              showDialog(
                                context: context,
                                builder: (_) => PickInventoryDialog(
                                  requestId: request.id,
                                  roomNumber: request.roomNumber,
                                  preAssignedItems: request.refillItems,
                                  onStart: (items) async {
                                    if (items.isNotEmpty) {
                                      final groupedItems = <int, List<Map<String, dynamic>>>{};
                                      for (var item in items) {
                                        final locId = item['location_id'] as int?;
                                        if (locId != null) {
                                          groupedItems.putIfAbsent(locId, () => []).add(item);
                                        }
                                      }

                                      for (var entry in groupedItems.entries) {
                                        await context.read<InventoryProvider>().createStockIssue(
                                          sourceLocationId: entry.key,
                                          items: entry.value,
                                          notes: "Used for Service Request #${request.id} (Room ${request.roomNumber})",
                                        );
                                      }
                                    }
                                    _doUpdate('in_progress');
                                  },
                                ),
                              );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("Accept & Start"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _doUpdate('cancelled'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text("Reject"),
                        ),
                      ),
                    ],
                  ),
                if (request.status.toLowerCase().replaceAll('_', ' ') == 'in progress')
                  _isUpdating
                  ? const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: CircularProgressIndicator(strokeWidth: 2)))
                  : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                          final desc = request.description.toLowerCase();
                          if (desc.contains("checkout") || request.type.toLowerCase() == 'checkout') {
                             showDialog(
                               context: context,
                               builder: (_) => CheckoutVerificationDialog(
                                 roomNumber: request.roomNumber,
                                 onSuccess: () => _doUpdate('completed', null),
                               )
                             );
                             return;
                          }

                          final isFood = request.type.toLowerCase().contains('food') || 
                                         request.description.toLowerCase().contains('food') ||
                                         request.type.toLowerCase() == 'delivery';

                          showDialog(
                            context: context,
                            builder: (_) => CompleteServiceDialog(
                               requestId: request.id,
                               roomNumber: request.roomNumber,
                               refillItems: request.refillItems,
                               isFoodService: isFood,
                               currentBillingStatus: request.billingStatus,
                               foodOrderAmount: request.foodOrderAmount,
                               foodOrderGst: request.foodOrderGst,
                               foodOrderTotal: request.foodOrderTotal,
                               onJustComplete: (billingStatus) => _doUpdate('completed', billingStatus),
                               onReturn: (items, destId, billingStatus) async {
                                  final provider = context.read<InventoryProvider>();
                                  final locs = provider.locations;
                                  
                                  dynamic roomLoc;
                                  try {
                                    roomLoc = locs.firstWhere((l) => l['name'] == "Room ${request.roomNumber}");
                                  } catch (e) {
                                    roomLoc = null;
                                  }
                                  
                                  if (roomLoc == null) {
                                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Room location not found in inventory system. Cannot return items.")));
                                     return; 
                                  }

                                  await provider.createStockIssue(
                                     sourceLocationId: roomLoc['id'],
                                     destinationLocationId: destId,
                                     items: items.map((i) => {
                                        'item_id': i['item_id'],
                                        'issued_quantity': i['quantity'],
                                        'unit': i['unit']
                                     }).toList(),
                                     notes: "Return from Service Request #${request.id}"
                                  );
                                  _doUpdate('completed', billingStatus);
                               }
                            )
                          );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text("Mark Complete"),
                    ),
                  ),
                if (request.status.toLowerCase() == 'completed')
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              "Completed",
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Show details dialog
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Container(
                                  constraints: BoxConstraints(maxWidth: 500),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Header with gradient
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(Icons.room_service, color: Colors.white, size: 28),
                                            ),
                                            SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Service Details",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    "Room ${request.roomNumber}",
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.9),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => Navigator.pop(context),
                                              icon: Icon(Icons.close, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Content
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Service Type Card
                                            Container(
                                              padding: EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.blue.shade100),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.cleaning_services, color: Colors.blue.shade700, size: 24),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          "Service Type",
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey[600],
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          request.type,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.blue.shade900,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: request.status.toLowerCase() == 'completed' 
                                                          ? Colors.green.shade100 
                                                          : Colors.orange.shade100,
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      request.status,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: request.status.toLowerCase() == 'completed' 
                                                            ? Colors.green.shade700 
                                                            : Colors.orange.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            SizedBox(height: 20),
                                            
                                            // Timeline
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _TimelineItem(
                                                    icon: Icons.play_circle_outline,
                                                    label: "Started",
                                                    time: DateFormat('MMM dd, HH:mm').format(request.createdAt),
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                                if (request.completedAt != null) ...[
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: _TimelineItem(
                                                      icon: Icons.check_circle_outline,
                                                      label: "Completed",
                                                      time: DateFormat('MMM dd, HH:mm').format(request.completedAt!),
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            
                                            if (request.refillItems.isNotEmpty) ...[
                                              SizedBox(height: 24),
                                              Divider(),
                                              SizedBox(height: 16),
                                              
                                              // Inventory Items Section
                                              Row(
                                                children: [
                                                  Icon(Icons.inventory_2, size: 20, color: AppColors.primary),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "Inventory Items",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.grey[800],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                              
                                              ...request.refillItems.map((item) {
                                                final itemId = item['item_id'];
                                                final quantity = item['quantity'];
                                                
                                                String itemName = 'Item #$itemId';
                                                String unit = 'pcs';
                                                
                                                try {
                                                  final invProvider = context.read<InventoryProvider>();
                                                  final inventoryItem = invProvider.allItems.firstWhere(
                                                    (i) => i.id == itemId,
                                                  );
                                                  itemName = inventoryItem.name;
                                                  unit = inventoryItem.unit ?? 'pcs';
                                                } catch (e) {
                                                  print('[WARN] Item $itemId not found: $e');
                                                }
                                                
                                                return Container(
                                                  margin: EdgeInsets.only(bottom: 8),
                                                  padding: EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade50,
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: Colors.grey.shade200),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding: EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Icon(Icons.inventory, size: 18, color: AppColors.primary),
                                                      ),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          itemName,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w500,
                                                            color: Colors.grey[800],
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.primary.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          "$quantity $unit",
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.primary,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ] else ...[
                                              SizedBox(height: 24),
                                              Center(
                                                child: Column(
                                                  children: [
                                                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      "No inventory items assigned",
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey[500],
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(color: Colors.green.shade700),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text("View Details"),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Timeline Item Widget for Service Details Dialog
class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color color;

  const _TimelineItem({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
