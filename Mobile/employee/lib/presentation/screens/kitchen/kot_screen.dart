import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/kot_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../presentation/providers/kitchen_provider.dart';
import 'kot_history_screen.dart';
import 'package:intl/intl.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/attendance_provider.dart';

import '../../../presentation/widgets/app_drawer.dart';

class KOTScreen extends StatefulWidget {
  const KOTScreen({super.key});

  @override
  State<KOTScreen> createState() => _KOTScreenState();
}

class _KOTScreenState extends State<KOTScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final employeeId = context.read<AuthProvider>().employeeId;
      context.read<KitchenProvider>().fetchActiveOrders(employeeId: employeeId);
      context.read<KitchenProvider>().fetchEmployees();
    });
  }

  Future<void> _updateStatus(int orderId, String newStatus) async {
    String? billingStatus;

    // Show payment prompt only when marking as completed
    if (newStatus == 'completed' && mounted) {
      billingStatus = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Finalize Order"),
          content: const Text("Is this order paid?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'unpaid'),
              child: const Text("UNPAID", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'paid'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text("PAID"),
            ),
          ],
        ),
      );

      if (billingStatus == null) return; // User cancelled
    }

    if (!mounted) return;
    final success = await context.read<KitchenProvider>().updateStatus(orderId, newStatus, billingStatus: billingStatus);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(success ? Icons.check_circle : Icons.error, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(success 
                ? "Order ${newStatus == 'completed' ? 'finalized' : 'updated to ' + newStatus.toUpperCase()}" 
                : "Failed to update order"),
            ],
          ),
          backgroundColor: success ? Colors.green.shade600 : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showRecipeBottomSheet(BuildContext context, KOTItem item, KitchenProvider kitchen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.menu_book, color: Colors.orange.shade700, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Recipe & Ingredients",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Qty: ${item.quantity}",
                        style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Recipe content
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: kitchen.fetchRecipe(item.foodItemId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Loading recipe...", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }
                    final recipe = snapshot.data;
                    if (recipe == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.no_meals, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text("No Recipe Found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              "No recipe has been set up for this item yet.",
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    final ingredients = (recipe['ingredients'] as List?) ?? [];
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Recipe name
                        if (recipe['name'] != null) ...[
                          _sectionHeader("Recipe Name", Icons.restaurant_menu),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade100),
                            ),
                            child: Text(
                              recipe['name']?.toString() ?? '',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Description
                        if (recipe['description'] != null && recipe['description'].toString().isNotEmpty) ...[
                          _sectionHeader("Description", Icons.notes),
                          const SizedBox(height: 8),
                          Text(
                            recipe['description']?.toString() ?? '',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.5),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Servings / prep time
                        if (recipe['serving_size'] != null || recipe['prep_time'] != null) ...[
                          Row(
                            children: [
                              if (recipe['serving_size'] != null)
                                Expanded(child: _infoChip(Icons.people, "Serves", recipe['serving_size'].toString())),
                              if (recipe['prep_time'] != null)
                                Expanded(child: _infoChip(Icons.timer, "Prep Time", "${recipe['prep_time']} min")),
                              if (recipe['cook_time'] != null)
                                Expanded(child: _infoChip(Icons.local_fire_department, "Cook Time", "${recipe['cook_time']} min")),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Ingredients
                        _sectionHeader("Ingredients", Icons.shopping_basket),
                        const SizedBox(height: 12),
                        if (ingredients.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "No ingredients listed",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ...ingredients.asMap().entries.map((entry) {
                            final i = entry.key;
                            final ing = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: i.isEven ? Colors.grey.shade50 : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        "${i + 1}",
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      ing['inventory_item_name']?.toString() ?? 'Unknown',
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${ing['quantity']} ${ing['unit'] ?? ''}",
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        // Steps / instructions
                        if (recipe['instructions'] != null && recipe['instructions'].toString().isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _sectionHeader("Instructions", Icons.format_list_numbered),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Text(
                              recipe['instructions']?.toString() ?? '',
                              style: const TextStyle(fontSize: 14, height: 1.7),
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }

  void _showOrderActionDialog(BuildContext context, KOT kot, bool isNew, KitchenProvider kitchen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: isNew ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isNew ? Colors.orange : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isNew ? Icons.soup_kitchen : Icons.check_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNew ? "Accept & Start Cooking" : "Mark as Ready",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Order #${kot.id} • ${kot.roomNumber}",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (kot.orderType == 'room_service')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "ROOM\nSERVICE",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Items with recipe buttons
                    Row(
                      children: [
                        Icon(Icons.restaurant_menu, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          "${kot.items.length} Item${kot.items.length != 1 ? 's' : ''}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...kot.items.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${item.quantity}x",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.itemName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          // Recipe button
                          TextButton.icon(
                            onPressed: () => _showRecipeBottomSheet(context, item, kitchen),
                            icon: const Icon(Icons.menu_book, size: 16),
                            label: const Text("Recipe"),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                    )),
                    // Notes / special request
                    if (kot.deliveryRequest != null && kot.deliveryRequest!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.note_alt, color: Colors.amber.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Special Instructions",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    kot.deliveryRequest!,
                                    style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Order info
                    const SizedBox(height: 20),
                    _buildInfoRow(Icons.access_time, "Time", DateFormat('hh:mm a, MMM d').format(kot.createdAt)),
                    _buildInfoRow(Icons.person_outline, "Created by", kot.creatorName ?? 'N/A'),
                    if (kot.assignedEmployeeId != null)
                      _buildInfoRow(Icons.delivery_dining, "Assigned to", kot.waiterName ?? 'N/A'),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Action buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: Icon(isNew ? Icons.soup_kitchen : Icons.check_circle),
                        label: Text(isNew ? "START COOKING" : "MARK AS READY"),
                        onPressed: () async {
                          final newStatus = isNew ? 'cooking' : 'ready';
                          Navigator.pop(ctx);
                          await _updateStatus(kot.id, newStatus);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isNew ? Colors.orange.shade600 : Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text("$label: ", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  void _showAssignDialog(KOT kot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.delivery_dining, size: 24, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Assign Delivery Staff", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Order #${kot.id} • ${kot.roomNumber}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer<KitchenProvider>(
                builder: (context, kitchen, _) {
                  if (kitchen.isLoading && kitchen.employees.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (kitchen.employees.isEmpty) {
                    return const Center(child: Text("No employees available"));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: kitchen.employees.length,
                    itemBuilder: (context, index) {
                      final emp = kitchen.employees[index];
                      final bool isActive = emp['status'] == 'on_duty';
                      final bool isAssigned = kot.assignedEmployeeId == emp['id'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isAssigned ? Colors.green.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAssigned ? Colors.green.shade200 : Colors.grey.shade200,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.shade100 : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                emp['name'].toString().substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(emp['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (isActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text("ON DUTY", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(emp['role'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          trailing: isAssigned
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () async {
                            final success = await kitchen.assignOrder(kot.id, emp['id']);
                            if (success && mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Assigned to ${emp['name']}"),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Kitchen Orders (KOT)"),
                if (auth.userName != null)
                  Text(
                    "Chef: ${auth.userName}",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                  ),
              ],
            );
          },
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final employeeId = context.read<AuthProvider>().employeeId;
              context.read<KitchenProvider>().fetchActiveOrders(employeeId: employeeId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KOTHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 5,
        child: Consumer3<KitchenProvider, AttendanceProvider, AuthProvider>(
          builder: (context, kitchen, attendance, auth, child) {
            if (kitchen.isLoading && kitchen.activeKots.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final pendingOrders = kitchen.activeKots.where((k) => 
                k.status.toLowerCase() == 'pending' || k.status.toLowerCase() == 'accepted').toList();
            final cookingOrders = kitchen.activeKots.where((k) => 
                k.status.toLowerCase() == 'cooking' || k.status.toLowerCase() == 'preparing').toList();
            final readyOrders = kitchen.activeKots.where((k) => k.status.toLowerCase() == 'ready').toList();

            return Column(
              children: [
                _buildKpiSection(pendingOrders.length, cookingOrders.length, readyOrders.length),
                if (!attendance.isClockedIn)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.red.shade100,
                    child: const Text(
                      "⚠️  CLOCK IN REQUIRED TO MANAGE ORDERS",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                Container(
                  color: Colors.white,
                  child: const TabBar(
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.grey,
                    isScrollable: true,
                    tabs: [
                      Tab(text: "All"),
                      Tab(text: "Pending"),
                      Tab(text: "Cooking"),
                      Tab(text: "Ready"),
                      Tab(text: "Completed"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOrdersList(kitchen, kitchen.activeKots, attendance.isClockedIn, auth),
                      _buildOrdersList(kitchen, pendingOrders, attendance.isClockedIn, auth),
                      _buildOrdersList(kitchen, cookingOrders, attendance.isClockedIn, auth),
                      _buildOrdersList(kitchen, readyOrders, attendance.isClockedIn, auth),
                      _buildOrdersList(kitchen, kitchen.orderHistory.where((k) => k.status.toLowerCase() == 'completed').toList(), attendance.isClockedIn, auth),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrdersList(KitchenProvider kitchen, List<KOT> orders, bool isOnDuty, AuthProvider auth) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No orders found", style: TextStyle(color: Colors.grey, fontSize: 18)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        final employeeId = context.read<AuthProvider>().employeeId;
        await kitchen.fetchActiveOrders(employeeId: employeeId);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final kot = orders[index];
          return _buildKOTCard(kot, isOnDuty, kitchen, auth);
        },
      ),
    );
  }

  Widget _buildKpiSection(int pending, int cooking, int ready) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _buildKpiCard("Pending", pending, Colors.red, Icons.hourglass_empty),
          const SizedBox(width: 8),
          _buildKpiCard("Cooking", cooking, Colors.orange, Icons.soup_kitchen),
          const SizedBox(width: 8),
          _buildKpiCard("Ready", ready, Colors.green, Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              "$count",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKOTCard(KOT kot, bool isOnDuty, KitchenProvider kitchen, AuthProvider auth) {
    Color statusColor;
    IconData statusIcon;
    switch (kot.status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.red;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'accepted':
      case 'cooking':
      case 'preparing':
        statusColor = Colors.orange;
        statusIcon = Icons.soup_kitchen;
        break;
      case 'ready':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: statusColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            kot.roomNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Order #${kot.id}",
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                      Text(
                        "${kot.items.length} item${kot.items.length != 1 ? 's' : ''} • ${kot.orderType.replaceAll('_', ' ').toUpperCase()}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Wrap(
                      spacing: 4,
                      alignment: WrapAlignment.end,
                      children: [
                        if (kot.billingStatus != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: kot.billingStatus?.toLowerCase() == 'paid' ? Colors.green.shade100 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kot.billingStatus?.toLowerCase() == 'paid' ? Colors.green.shade300 : Colors.grey.shade300),
                            ),
                            child: Text(
                              kot.billingStatus!.toUpperCase(),
                              style: TextStyle(
                                color: kot.billingStatus?.toLowerCase() == 'paid' ? Colors.green.shade800 : Colors.grey.shade700,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                kot.status.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('hh:mm a').format(kot.createdAt),
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Items list with recipe buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: kot.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        "${item.quantity}x",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item.itemName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    // Recipe icon button
                    InkWell(
                      onTap: () => _showRecipeBottomSheet(context, item, kitchen),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              "Recipe",
                              style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
          // Special notes
          if (kot.deliveryRequest != null && kot.deliveryRequest!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note_alt, size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        kot.deliveryRequest!,
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Assignment info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    kot.assignedEmployeeId != null
                        ? "${kot.orderType == 'room_service' ? 'Delivery: ' : 'Staff: '}${kot.waiterName}"
                        : "No delivery staff assigned",
                    style: TextStyle(
                      color: kot.assignedEmployeeId != null ? Colors.blue.shade700 : Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: kot.assignedEmployeeId != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(Icons.soup_kitchen, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  kot.chefName ?? "Not assigned",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                // Assign staff button (manager only)
                if (kot.status.toLowerCase() != 'completed' && kot.status.toLowerCase() != 'cancelled' && auth.role == UserRole.manager)
                  TextButton.icon(
                    onPressed: () => _showAssignDialog(kot),
                    icon: const Icon(Icons.edit, size: 12),
                    label: const Text("Assign", style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // View full details button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showOrderActionDialog(context, kot, kot.status == 'pending', kitchen),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text("Details"),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Primary action
                if (kot.status.toLowerCase() == 'pending')
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isOnDuty ? () => _updateStatus(kot.id, 'cooking') : null,
                      icon: const Icon(Icons.soup_kitchen, size: 16),
                      label: const Text("Accept & Cook"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnDuty ? Colors.orange.shade600 : Colors.grey,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (kot.status.toLowerCase() == 'cooking' || kot.status.toLowerCase() == 'accepted' || kot.status.toLowerCase() == 'preparing')
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isOnDuty ? () => _updateStatus(kot.id, 'ready') : null,
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text("Mark Ready"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnDuty ? Colors.green.shade600 : Colors.grey,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (kot.status.toLowerCase() == 'ready')
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isOnDuty ? () => _updateStatus(kot.id, 'completed') : null,
                      icon: const Icon(Icons.delivery_dining, size: 16),
                      label: const Text("Out for Delivery"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnDuty ? Colors.blue.shade600 : Colors.grey,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
