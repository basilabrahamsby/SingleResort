import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/service_provider.dart';
import '../providers/auth_provider.dart';
import '../models/service.dart';
import '../models/service_request.dart';
import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart' as inventory_provider;

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      final provider = Provider.of<ServiceProvider>(context, listen: false);
      provider.fetchServices();
      provider.fetchAssignedServices();
      provider.fetchRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Catalog'),
            Tab(text: 'Activity'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ServiceCatalogTab(),
          ServiceActivityTab(),
          ServiceRequestsTab(),
        ],
      ),
    );
  }
}

class ServiceCatalogTab extends StatelessWidget {
  const ServiceCatalogTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceProvider>(
      builder: (context, provider, child) {
        final services = provider.services;
        
        // KPIs
        final totalServices = services.length;
        final guestVisible = services.where((s) => s.isVisibleToGuest).length;
        final avgPrice = services.isEmpty 
            ? 0.0 
            : services.fold(0.0, (sum, s) => sum + s.charges) / services.length;

        return Column(
          children: [
            // KPI Dashboard
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _KpiCard(
                    title: 'Total Services',
                    value: '$totalServices',
                    icon: Icons.spa,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _KpiCard(
                    title: 'Guest Visible',
                    value: '$guestVisible',
                    icon: Icons.visibility,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _KpiCard(
                    title: 'Avg Price',
                    value: '₹${avgPrice.toStringAsFixed(0)}',
                    icon: Icons.attach_money,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
            
            // List
                    Expanded(
              child: provider.isLoading && services.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : services.isEmpty
                      ? const Center(child: Text('No services defined.'))
                      : RefreshIndicator(
                          onRefresh: () => provider.fetchServices(),
                          child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: services.length,
                              itemBuilder: (context, index) {
                                final service = services[index];
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.withOpacity(0.1),
                                      child: const Icon(Icons.spa, color: Colors.blue),
                                    ),
                                    title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(service.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    trailing: Text('₹${service.charges.toStringAsFixed(2)}', 
                                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    onTap: () {
                                      final history = provider.assignedServices
                                          .where((a) => a.serviceId == service.id)
                                          .toList()
                                          ..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
                                      
                                      final totalRevenue = history.where((h) => h.status.toLowerCase() == 'completed').length * service.charges;
    
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                        builder: (context) => DraggableScrollableSheet(
                                          initialChildSize: 0.6,
                                          minChildSize: 0.4,
                                          maxChildSize: 0.9,
                                          expand: false,
                                          builder: (context, scrollController) => Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: ListView(
                                              controller: scrollController,
                                              children: [
                                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                                  Expanded(child: Text(service.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                                                  Text('\$${service.charges.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                                                ]),
                                                const SizedBox(height: 16),
                                                const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                                const SizedBox(height: 8),
                                                Text(service.description, style: const TextStyle(fontSize: 16)),
                                                const SizedBox(height: 16),
                                                Row(children: [
                                                  Icon(service.isVisibleToGuest ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                                                  const SizedBox(width: 8),
                                                  Text(service.isVisibleToGuest ? "Visible to Guests" : "Hidden from Guests", style: const TextStyle(color: Colors.grey)),
                                                ]),
                                                const Divider(height: 32),
                                                const Text("Service History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                  children: [
                                                    _StatBadge("Total Requests", "${history.length}", Colors.blue),
                                                    _StatBadge("Revenue", "₹${totalRevenue.toStringAsFixed(0)}", Colors.green),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                if (history.isEmpty)
                                                  const Center(child: Text("No history found for this service", style: TextStyle(color: Colors.grey)))
                                                else
                                                  ...history.take(10).map((h) => ListTile(
                                                    contentPadding: EdgeInsets.zero,
                                                    leading: const Icon(Icons.history, size: 20, color: Colors.grey),
                                                    title: Text("Room ${h.roomNumber} - ${h.status.toUpperCase()}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                                    subtitle: Text("${DateFormat('dd-MM-yyyy').format(DateTime.parse(h.assignedAt))} • ${h.employeeName}", style: const TextStyle(fontSize: 12)),
                                                    trailing: Text(h.status == 'completed' ? '+₹${service.charges.toInt()}' : '-', style: TextStyle(color: h.status == 'completed' ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
                                                  )),
                                                const SizedBox(height: 24),
                                                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                      ),
            ),
          ],
        );
      },
    );
  }
}

class ServiceActivityTab extends StatelessWidget {
  const ServiceActivityTab({super.key});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      case 'in_progress': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceProvider>(
      builder: (context, provider, child) {
        final assigned = provider.assignedServices;

        // KPIs
        final totalAssigned = assigned.length;
        final pending = assigned.where((s) => s.status.toLowerCase() == 'pending').length;
        
        // Calculate Revenue (Approximate based on service charges)
        // Need to lookup service charge from services list
        double revenue = 0.0;
        for (var a in assigned) {
             if (a.status.toLowerCase() == 'completed') {
               // Find service in catalog
               final service = provider.services.firstWhere(
                 (s) => s.id == a.serviceId, 
                 orElse: () => ServiceModel(id: 0, name: '', description: '', charges: 0, isVisibleToGuest: false));
               revenue += service.charges;
             }
        }

        return Column(
          children: [
            // KPI Dashboard
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                   _KpiCard(
                    title: 'Requests',
                    value: '$totalAssigned',
                    icon: Icons.assignment,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _KpiCard(
                    title: 'Pending',
                    value: '$pending',
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                   const SizedBox(width: 12),
                  _KpiCard(
                    title: 'Revenue',
                    value: '₹${revenue.toStringAsFixed(0)}',
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
                ],
              ),
            ),

            Expanded(
              child: provider.isLoading && assigned.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : assigned.isEmpty
                      ? const Center(child: Text('No assigned services found.'))
                      : RefreshIndicator(
                          onRefresh: () => provider.fetchAssignedServices(),
                          child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: assigned.length,
                              itemBuilder: (context, index) {
                                final item = assigned[index];
                                final isPending = item.status.toLowerCase() != 'completed' && item.status.toLowerCase() != 'cancelled';
                                
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getStatusColor(item.status).withOpacity(0.1),
                                      child: Icon(Icons.room_service, color: _getStatusColor(item.status)),
                                    ),
                                    title: Text('${item.serviceName} (Room ${item.roomNumber})'),
                                    subtitle: Text('Assigned to: ${item.employeeName}\nAt: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(item.assignedAt))}'),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(item.status.toUpperCase(), 
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _getStatusColor(item.status))),
                                        if (isPending)
                                          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                                      ],
                                    ),
                                    onTap: isPending ? () {
                                      // Find linked request
                                      ServiceRequest? request;
                                      try {
                                        request = provider.requests.firstWhere(
                                          (r) => r.assignedServiceId == item.id || (r.roomNumber == item.roomNumber && r.status.toLowerCase() == item.status.toLowerCase())
                                        );
                                      } catch (_) {
                                        // Local placeholder if not found in list
                                        request = ServiceRequest(
                                          id: 0, 
                                          requestType: item.serviceName,
                                          description: 'Assigned Service Task',
                                          status: item.status,
                                          createdAt: item.assignedAt,
                                          roomNumber: item.roomNumber,
                                          employeeName: item.employeeName,
                                          isCheckoutRequest: item.serviceName.toLowerCase().contains('checkout'),
                                          isAssignedService: true,
                                          assignedServiceId: item.id,
                                        );
                                      }
                                      _showCompletionDialog(context, request, provider);
                                    } : null,
                                  ),
                                );
                              },
                            ),
                      ),
            ),
          ],
        );
      },
    );
  }
}

class ServiceRequestsTab extends StatelessWidget {
  const ServiceRequestsTab({super.key});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceProvider>(
      builder: (context, provider, child) {
        final requests = provider.requests;

        // KPIs
        final totalRequests = requests.length;
        final pendingRequests = requests.where((r) => r.status.toLowerCase() == 'pending').length;
        final checkoutRequests = requests.where((r) => r.isCheckoutRequest).length;

        return Column(
          children: [
            // KPI Dashboard
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _KpiCard(
                    title: 'Total',
                    value: '$totalRequests',
                    icon: Icons.inbox,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _KpiCard(
                    title: 'Pending',
                    value: '$pendingRequests',
                    icon: Icons.pending,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _KpiCard(
                    title: 'Checkouts',
                    value: '$checkoutRequests',
                    icon: Icons.playlist_add_check,
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: provider.isLoading && requests.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : requests.isEmpty
                      ? const Center(child: Text('No service requests found.'))
                      : RefreshIndicator(
                          onRefresh: () => provider.fetchRequests(),
                          child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: requests.length,
                              itemBuilder: (context, index) {
                                final request = requests[index];
                                final isCheckout = request.isCheckoutRequest;
                                
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isCheckout ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                      child: Icon(
                                        isCheckout ? Icons.playlist_add_check : Icons.room_service, 
                                        color: isCheckout ? Colors.purple : Colors.blue
                                      ),
                                    ),
                                    title: Text(isCheckout 
                                      ? 'Checkout Verify (Room ${request.roomNumber})' 
                                      : 'Service Request (Room ${request.roomNumber})'
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (request.description.isNotEmpty)
                                          Text(request.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text('Status: ${request.status} • ${DateFormat('dd-MM-yyyy').format(DateTime.parse(request.createdAt))}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12)
                                        ),
                                      ],
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(request.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _getStatusColor(request.status).withOpacity(0.5))
                                      ),
                                      child: Text(
                                        request.status.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 10,
                                          color: _getStatusColor(request.status)
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                        builder: (context) => DraggableScrollableSheet(
                                          initialChildSize: 0.7,
                                          minChildSize: 0.5,
                                          maxChildSize: 0.95,
                                          expand: false,
                                          builder: (context, scrollController) {
                                            // Calculate Inventory Items
                                            final inventory = request.inventoryData ?? [];
                                            final damages = request.assetDamages ?? [];
                                            
                                            return Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: ListView(
                                                controller: scrollController,
                                                children: [
                                                  Row(children: [
                                                    Icon(isCheckout ? Icons.playlist_add_check : Icons.room_service, size: 32, color: isCheckout ? Colors.purple : Colors.blue),
                                                    const SizedBox(width: 16),
                                                    Expanded(child: Text(isCheckout ? 'Checkout Verify' : 'Service Request', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                                                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _getStatusColor(request.status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(request.status.toUpperCase(), style: TextStyle(color: _getStatusColor(request.status), fontWeight: FontWeight.bold))),
                                                  ]),
                                                  const Divider(height: 32),
                                                  _buildDetailRow("Room", "${request.roomNumber}"),
                                                  if (request.description.isNotEmpty)
                                                     _buildDetailRow("Description", request.description),
                                                  _buildDetailRow("Created At", DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(request.createdAt))),
                                                  if (request.completedAt != null)
                                                    _buildDetailRow("Completed At", request.completedAt!),
                                                  
                                                  if (isCheckout) ...[
                                                    const Divider(height: 32),
                                                    const Text("Inventory Checked", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
                                                    const SizedBox(height: 12),
                                                    if (inventory.isEmpty)
                                                      const Text("No inventory data recorded.", style: TextStyle(color: Colors.grey))
                                                    else
                                                      ...inventory.map((item) => ListTile(
                                                        contentPadding: EdgeInsets.zero,
                                                        dense: true,
                                                        title: Text(item['item_name'] ?? 'Unknown Item', style: const TextStyle(fontWeight: FontWeight.w500)),
                                                        trailing: Text("Qty: ${item['quantity'] ?? 0}"),
                                                      )),
                                                      
                                                    if (damages.isNotEmpty) ...[
                                                       const Divider(height: 32),
                                                       const Text("Damages / Missing Assets", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                                                       const SizedBox(height: 12),
                                                       ...damages.map((item) => Card(
                                                         color: Colors.red.withOpacity(0.05),
                                                         elevation: 0,
                                                         margin: const EdgeInsets.only(bottom: 8),
                                                         child: ListTile(
                                                           dense: true,
                                                           leading: const Icon(Icons.broken_image, color: Colors.red),
                                                           title: Text(item['item_name'] ?? 'Asset', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                                            subtitle: Text("Damage: ${item['description'] ?? 'Reported'}"),
                                                            trailing: Text("₹${item['cost'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                                         ),
                                                       )),
                                                    ]
                                                  ],
    
                                                  const SizedBox(height: 24),
                                                  if (request.status.toLowerCase() == 'pending' || request.status.toLowerCase() == 'assigned' || request.status.toLowerCase() == 'in_progress')
                                                    Row(
                                                      children: [
                                                        if (request.status.toLowerCase() == 'pending')
                                                          Expanded(child: ElevatedButton(
                                                            onPressed: () => _showCollectionDialog(context, request, provider),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.blue[700], 
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                            ), 
                                                            child: const Text("Collect & Start")
                                                          ))
                                                        else
                                                          Expanded(child: ElevatedButton(
                                                            onPressed: () => _showCompletionDialog(context, request, provider),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.green, 
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                            ), 
                                                            child: const Text("Complete Task")
                                                          )),
                                                        const SizedBox(width: 16),
                                                        Expanded(child: OutlinedButton(onPressed: () { provider.updateRequestStatus(request.id, 'cancelled'); Navigator.pop(context); }, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Cancel"))),
                                                      ],
                                                    ),
                                                  const SizedBox(height: 16),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                      ),
            ),
          ],
        );
      },
    );
  }
}

void _showCollectionDialog(BuildContext context, ServiceRequest request, ServiceProvider provider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => _CollectionDialog(request: request, provider: provider, scrollController: controller),
    ),
  );
}

class _CollectionDialog extends StatefulWidget {
  final ServiceRequest request;
  final ServiceProvider provider;
  final ScrollController scrollController;

  const _CollectionDialog({required this.request, required this.provider, required this.scrollController});

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  int? _selectedPickupLocationId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<inventory_provider.InventoryProvider>(context, listen: false).fetchLocations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final neededItems = widget.request.refillData ?? widget.request.inventoryData ?? [];
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.shopping_basket_outlined, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text('Collect Items', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('Pickup inventory for this service', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              children: [
                const Text('ITEMS TO COLLECT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.grey)),
                const SizedBox(height: 12),
                if (neededItems.isEmpty)
                   const Text('No specific items recorded for this request.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                else
                  ...neededItems.map((item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: Colors.blue, radius: 4),
                    title: Text(item['item_name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Text('Qty: ${item['quantity'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
                const SizedBox(height: 32),
                const Text('PICKUP FROM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.grey)),
                const SizedBox(height: 12),
                Consumer<inventory_provider.InventoryProvider>(
                  builder: (context, invProvider, _) {
                    final locations = invProvider.locations.where((l) => l['is_inventory_point'] == true || l['location_type']?.toString().contains('WAREHOUSE') == true).toList();
                    return DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        hintText: 'Select Store/Pantry Location',
                      ),
                      value: _selectedPickupLocationId,
                      items: locations.map((loc) => DropdownMenuItem(
                        value: loc['id'] as int,
                        child: Text(loc['name'] ?? 'Storage'),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedPickupLocationId = val),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleCollect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirm Collection & Start', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCollect() async {
    if (_selectedPickupLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a pickup location')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.user?.id;

      await widget.provider.updateRequestStatus(
        widget.request.id, 
        'in_progress',
        pickupLocationId: _selectedPickupLocationId,
        employeeId: employeeId,
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Close detail sheet
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Items collected. Task started.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

void _showCompletionDialog(BuildContext context, ServiceRequest request, ServiceProvider provider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: _CompletionDialog(request: request, provider: provider, scrollController: controller),
      ),
    ),
  );
}

class _CompletionDialog extends StatefulWidget {
  final ServiceRequest request;
  final ServiceProvider provider;
  final ScrollController scrollController;

  const _CompletionDialog({
    required this.request, 
    required this.provider,
    required this.scrollController,
  });

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  String _billingStatus = 'unbilled';
  int? _selectedLocationId;
  final List<Map<String, dynamic>> _inventoryReturns = [];
  bool _isSubmitting = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _billingStatus = widget.request.billingStatus ?? 'unbilled';
    
    // Auto-detect if it should be paid based on type
    final type = widget.request.requestType.toLowerCase();
    if (type.contains('food') || type.contains('delivery') || type.contains('order')) {
      _billingStatus = 'paid';
    }

    // Initialize inventory returns from initial data
    _initializeInventory(widget.request.refillData ?? widget.request.inventoryData ?? []);

    // Fetch fresher inventory if this is an assigned service
    if (widget.request.assignedServiceId != null) {
      widget.provider.fetchAssignedServiceInventory(widget.request.assignedServiceId!).then((items) {
        if (items.isNotEmpty && mounted) {
          setState(() {
            _initializeInventory(items, clearExisting: true);
          });
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<inventory_provider.InventoryProvider>(context, listen: false).fetchLocations();
    });
  }

  void _initializeInventory(List<dynamic> sourceData, {bool clearExisting = false}) {
    if (clearExisting) _inventoryReturns.clear();
    
    for (var item in sourceData) {
      final name = (item['item_name'] ?? 'Item').toLowerCase();
      // Logic from Services.jsx: Force known consumables to NOT be rentable
      final isKnownConsumable = ["coca", "cola", "water", "chips", "juice", "biscuit"].any((k) => name.contains(k));
      final isRentable = !isKnownConsumable && (item['is_rentable'] == true || item['track_laundry_cycle'] == true || name.contains('sheet') || name.contains('towel') || name.contains('pillow'));

      _inventoryReturns.add({
        'item_id': item['item_id'] ?? item['id'],
        'assignment_id': item['assignment_id'],
        'item_name': item['item_name'] ?? 'Item',
        'item_code': item['item_code'] ?? '-',
        'quantity_assigned': (item['quantity'] ?? item['quantity_assigned'] ?? 0).toDouble(),
        'quantity_used': 0.0,
        'quantity_returned': (item['quantity'] ?? item['quantity_assigned'] ?? 0).toDouble(),
        'available_stock': (item['quantity'] ?? item['quantity_assigned'] ?? 0).toDouble(), // For rentals
        'damage_qty': 0.0, // For rentals
        'is_rentable': isRentable,
        'is_laundry': isRentable, // Default to true for laundry-trackable items
        'is_waste': false,
        'request_replacement': false,
        'laundry_location_id': null,
        'waste_location_id': null,
        'return_location_id': null,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDelivery = widget.request.requestType.toLowerCase().contains('delivery') || 
                       widget.request.requestType.toLowerCase().contains('food');
    final isAssigned = widget.request.isAssignedService;
    final isCheckout = widget.request.isCheckoutRequest;

    // Filter items like Services.jsx
    final rentalItems = _inventoryReturns.where((i) => i['is_rentable'] == true).toList();
    final consumableItems = _inventoryReturns.where((i) => i['is_rentable'] == false).toList();

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCheckout ? Colors.purple[50] : Colors.indigo[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isCheckout ? Icons.fact_check_rounded : Icons.task_alt_rounded, 
                      color: isCheckout ? Colors.purple : Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isCheckout ? 'Room Clean-up & Verification' : 'Task Completion', 
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                        Text('Room ${widget.request.roomNumber} • ${widget.request.requestType}', 
                          style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              if (isDelivery) ...[
                _buildSectionHeader('PAYMENT PROTOCOL', Icons.payments_outlined),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildBillingOption('paid', 'Settle Now', Icons.check_circle_rounded, Colors.green),
                      _buildBillingOption('unbilled', 'Add to Folio', Icons.receipt_long_rounded, Colors.orange),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              if (consumableItems.isNotEmpty) ...[
                _buildSectionHeader('CONSUMABLES USAGE', Icons.inventory_2_outlined),
                const SizedBox(height: 16),
                ...consumableItems.map((item) => _buildInventoryItem(item)),
                const SizedBox(height: 32),
              ],

              if (rentalItems.isNotEmpty) ...[
                _buildSectionHeader('RENTAL & LAUNDRY VERIFICATION', Icons.local_laundry_service_outlined),
                const SizedBox(height: 16),
                ...rentalItems.map((item) => _buildRentalItem(item)),
                const SizedBox(height: 32),
              ],

              if (isCheckout) ...[
                _buildSectionHeader('CLEANLINESS CHECKLIST', Icons.verified_user_outlined),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    children: [
                      _buildChecklistRow('All linens and towels accounted for?'),
                      const Divider(height: 16),
                      _buildChecklistRow('Room sanitized and trash removed?'),
                      const Divider(height: 16),
                      _buildChecklistRow('Minibar audited and recorded?'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              _buildSectionHeader('FINAL OBSERVATIONS', Icons.notes_rounded),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any damages, losses, or special notes...',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        
        // Action Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCheckout ? Colors.purple[700] : Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isCheckout ? 'Verify & Complete' : 'Complete Mission', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_box_outline_blank_rounded, color: Colors.blue, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: Colors.blue[900], fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 1.5,
          color: Colors.grey[500],
        )),
      ],
    );
  }

  Widget _buildBillingOption(String value, String label, IconData icon, Color color) {
    bool isSelected = _billingStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _billingStatus = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey[400], size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                fontSize: 12, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.grey[800] : Colors.grey[500],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Total: ${item['quantity_assigned']}', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('USED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: (val) {
                        double used = double.tryParse(val) ?? 0;
                        setState(() {
                          item['quantity_used'] = used;
                          item['quantity_returned'] = (item['quantity_assigned'] - used).clamp(0, item['quantity_assigned']);
                        });
                      },
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0.0',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RETURNED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: item['quantity_returned'].toString()),
                      onChanged: (val) => item['quantity_returned'] = double.tryParse(val) ?? 0,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0.0',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLocationDropdown(item, 'return_location_id', 'Return To Location', (l) => l['is_inventory_point'] == true || l['location_type']?.toString().contains('WAREHOUSE') == true),
        ],
      ),
    );
  }

  Widget _buildRentalItem(Map<String, dynamic> item) {
    final totalQty = item['quantity_assigned'] as double;
    final good = item['available_stock'] as double;
    final damaged = item['damage_qty'] as double;
    double missing = totalQty - good - damaged;
    if (missing < 0) missing = 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple[50]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple)),
              Text('In Room: $totalQty', style: TextStyle(color: Colors.purple[300], fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildItemInput(
                  'GOOD / LAUNDRY', 
                  good.toString(), 
                  Colors.green,
                  (val) {
                    setState(() {
                      item['available_stock'] = double.tryParse(val) ?? 0;
                      // Sync for API mapping
                      item['quantity_returned'] = item['available_stock'];
                    });
                  }
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildItemInput(
                  'DAMAGED / WASTE', 
                  damaged.toString(), 
                  Colors.red,
                  (val) {
                    setState(() {
                      item['damage_qty'] = double.tryParse(val) ?? 0;
                      // Used = Damaged + Missing (logic for consumable mapping if needed)
                    });
                  }
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    const Text('MISSING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                    Text(missing.toInt().toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange[700])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Action Markers
          Row(
            children: [
              _buildCompactMarker('Mark Laundry', item['is_laundry'], Colors.blue, (val) => setState(() => item['is_laundry'] = val)),
              const SizedBox(width: 8),
              _buildCompactMarker('Mark Waste', item['is_waste'], Colors.red, (val) => setState(() => item['is_waste'] = val)),
              const SizedBox(width: 8),
              _buildCompactMarker('Replace', item['request_replacement'], Colors.orange, (val) => setState(() => item['request_replacement'] = val)),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (item['is_laundry'])
            _buildLocationDropdown(item, 'laundry_location_id', 'Send to Laundry', (l) => l['location_type']?.toString().contains('LAUNDRY') == true)
          else 
            _buildLocationDropdown(item, 'return_location_id', 'Return to Stock', (l) => l['is_inventory_point'] == true || l['location_type']?.toString().contains('WAREHOUSE') == true),
            
          if (item['is_waste'])
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildLocationDropdown(item, 'waste_location_id', 'Send to Waste/Repair', (l) => l['location_type']?.toString().contains('WASTE') == true || l['location_type']?.toString().contains('REPAIR') == true),
            ),
        ],
      ),
    );
  }

  Widget _buildItemInput(String label, String value, Color color, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        TextField(
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
          decoration: InputDecoration(
            hintText: '0',
            isDense: true,
            filled: true,
            fillColor: color.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.withOpacity(0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.withOpacity(0.1))),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactMarker(String label, bool value, Color color, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value ? color.withOpacity(0.3) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 14, color: value ? color : Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: value ? color : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDropdown(Map<String, dynamic> item, String field, String label, bool Function(dynamic) filter) {
    return Consumer<inventory_provider.InventoryProvider>(
      builder: (context, invProvider, _) {
        final locations = invProvider.locations.where(filter).toList();
        return DropdownButtonFormField<int>(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          value: item[field],
          items: locations.map<DropdownMenuItem<int>>((loc) {
            return DropdownMenuItem<int>(
              value: loc['id'],
              child: Text(loc['name'] ?? 'Store', style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (val) => setState(() => item[field] = val),
        );
      },
    );
  }

  Future<void> _handleComplete() async {
    setState(() => _isSubmitting = true);
    try {
      if (widget.request.id != 0) {
        await widget.provider.updateRequestStatus(
          widget.request.id, 
          'completed',
          billingStatus: _billingStatus,
          inventoryReturns: _inventoryReturns,
          notes: _notesController.text,
        );
      }

      // If there's a linked assigned service, update it too
      if (widget.request.assignedServiceId != null) {
        await widget.provider.updateAssignedServiceStatus(
          widget.request.assignedServiceId!,
          'completed',
          billingStatus: _billingStatus,
          inventoryReturns: _inventoryReturns,
          notes: _notesController.text,
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Mission Completed Successfully'),
              ],
            ), 
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

Widget _KpiCard({required String title, required String value, required IconData icon, required Color color}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ],
      ),
    ),
  );
}

Widget _StatBadge(String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ],
    ),
  );
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
      ],
    ),
  );
}
