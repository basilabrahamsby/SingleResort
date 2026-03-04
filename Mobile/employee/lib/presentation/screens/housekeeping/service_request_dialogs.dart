import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orchid_employee/data/models/service_request_model.dart';
import 'package:orchid_employee/data/models/inventory_item_model.dart';
import 'package:orchid_employee/core/constants/app_colors.dart';
import 'package:orchid_employee/presentation/providers/inventory_provider.dart';
import 'package:orchid_employee/presentation/providers/auth_provider.dart';
import 'package:intl/intl.dart';

// --- Premium Dialog Wrapper ---
class _PremiumDialogBase extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final List<Widget> actions;
  final Color baseColor;

  const _PremiumDialogBase({
    required this.title,
    required this.icon,
    required this.content,
    required this.actions,
    this.baseColor = const Color(0xFF1A73E8),
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [baseColor, baseColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: content,
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions.map((action) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: action,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ItemPickerDialog ---
class ItemPickerDialog extends StatefulWidget {
  final Function(InventoryItem item, double quantity) onPick;

  const ItemPickerDialog({super.key, required this.onPick});

  @override
  State<ItemPickerDialog> createState() => _ItemPickerDialogState();
}

class _ItemPickerDialogState extends State<ItemPickerDialog> {
  InventoryItem? _selectedItem;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final items = provider.sellableItems;

    return _PremiumDialogBase(
      title: "Pick Inventory Item",
      icon: Icons.inventory_2_outlined,
      baseColor: Colors.blueAccent,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select an item from the catalog",
            style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Autocomplete<InventoryItem>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return const Iterable<InventoryItem>.empty();
              return items.where((i) => i.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            displayStringForOption: (item) => "${item.name} (${item.unit})",
            onSelected: (val) => setState(() => _selectedItem = val),
            fieldViewBuilder: (ctx, controller, node, onComplete) {
              return TextField(
                controller: controller,
                focusNode: node,
                onEditingComplete: onComplete,
                decoration: InputDecoration(
                  labelText: "Search Item...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  decoration: InputDecoration(
                    labelText: "Quantity",
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixText: _selectedItem?.unit ?? '',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              if (_selectedItem != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Text(
                    "Unit: ${_selectedItem!.unit}",
                    style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: _selectedItem == null ? null : () {
            final qty = double.tryParse(_qtyController.text) ?? 1.0;
            widget.onPick(_selectedItem!, qty);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text("Add to List"),
        ),
      ],
    );
  }
}

// --- DeliveryStartDialog ---
class DeliveryStartDialog extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback onConfirm;

  const DeliveryStartDialog({
    super.key,
    required this.request,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumDialogBase(
      title: "Accept Delivery",
      icon: Icons.delivery_dining,
      baseColor: const Color(0xFF4CAF50), // Green for start/positive action
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.door_front_door_outlined, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Room ${request.roomNumber}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                      ),
                    ],
                  ),
                  if (request.guestName != null && request.guestName!.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          "Guest: ${request.guestName}",
                          style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (request.preparedByName != null && request.preparedByName!.isNotEmpty) ...[
              _buildInfoTile(Icons.storefront_outlined, "Collect From", request.preparedByName!),
              const SizedBox(height: 12),
            ],
            if (request.description.isNotEmpty) ...[
              const Text("Instructions:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                request.description,
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87),
              ),
              const SizedBox(height: 16),
            ],
            if (request.foodItems.isNotEmpty) ...[
              _buildSectionHeader(Icons.restaurant, "Food Items", Colors.orange),
              ...request.foodItems.map((item) => _buildItemRow(item['food_item_name']?.toString() ?? 'Item', item['quantity']?.toString() ?? '1', Colors.orange)),
              const SizedBox(height: 16),
            ],
            if (request.refillItems.isNotEmpty) ...[
              _buildSectionHeader(Icons.inventory_2_outlined, "Stock Items", Colors.blue),
              ...request.refillItems.map((item) => _buildItemRow(item['name']?.toString() ?? "Item", item['quantity']?.toString() ?? "1", Colors.blue)),
            ],
            if (request.foodItems.isEmpty && request.refillItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text("Are you ready to start this delivery task?"),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Later", style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_outlined),
              SizedBox(width: 8),
              Text("Accept & Start Now", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue[700]),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.blue[300], fontWeight: FontWeight.bold)),
              Text(value, style: TextStyle(fontSize: 13, color: Colors.blue[900], fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withOpacity(0.3))),
      ],
    );
  }

  Widget _buildItemRow(String name, String qty, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text("x$qty", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// --- PickInventoryDialog ---
class PickInventoryDialog extends StatefulWidget {
  final String requestId;
  final String roomNumber;
  final List<dynamic> preAssignedItems;
  final Function(List<Map<String, dynamic>> items) onStart;

  const PickInventoryDialog({
    super.key,
    required this.requestId,
    required this.roomNumber,
    this.preAssignedItems = const [],
    required this.onStart,
  });

  @override
  State<PickInventoryDialog> createState() => _PickInventoryDialogState();
}

class _PickInventoryDialogState extends State<PickInventoryDialog> {
  final List<Map<String, dynamic>> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().fetchLocations();
      context.read<InventoryProvider>().fetchSellableItems().then((_) {
        if (mounted && widget.preAssignedItems.isNotEmpty) {
           _populatePreAssignedItems();
        }
      });
    });
  }

  void _populatePreAssignedItems() {
    final invProvider = context.read<InventoryProvider>();
    final allItems = invProvider.allItems;
    final defaultLocId = invProvider.locations.isNotEmpty ? invProvider.locations.first['id'] : null;

    for (var pre in widget.preAssignedItems) {
      final itemId = pre['item_id'];
      final qty = pre['quantity'];
      if (itemId != null) {
        try {
          final item = allItems.firstWhere((i) => i.id == itemId);
          setState(() {
            _selectedItems.add({
              'item_id': item.id,
              'quantity': double.tryParse(qty.toString()) ?? 1.0,
              'name': item.name,
              'unit': item.unit,
              'location_id': defaultLocId,
            });
          });
        } catch (_) {}
      }
    }
  }

  void _addItem() {
    final invProvider = context.read<InventoryProvider>();
    final defaultLocId = invProvider.locations.isNotEmpty ? invProvider.locations.first['id'] : null;

    showDialog(
      context: context,
      builder: (ctx) => ItemPickerDialog(
        onPick: (item, qty) {
          setState(() {
            _selectedItems.add({
              'item_id': item.id,
              'quantity': qty,
              'name': item.name,
              'unit': item.unit,
              'location_id': defaultLocId,
            });
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invProvider = context.watch<InventoryProvider>();
    
    return _PremiumDialogBase(
      title: "Start Service",
      icon: Icons.play_circle_outline,
      baseColor: const Color(0xFF1565C0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.meeting_room_outlined, color: Colors.blue, size: 20),
                   const SizedBox(width: 8),
                   Text("Room ${widget.roomNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                 ],
               ),
            ),
            const SizedBox(height: 20),
            const Text("Pick inventory items (optional):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            if (invProvider.isLoading && invProvider.locations.isEmpty)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_selectedItems.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _selectedItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _selectedItems[i];
                      return ListTile(
                        dense: true,
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: item['location_id'],
                            isDense: true,
                            hint: const Text("Select Location", style: TextStyle(fontSize: 11)),
                            items: invProvider.locations.map<DropdownMenuItem<int>>((loc) {
                              return DropdownMenuItem<int>(
                                value: loc['id'],
                                child: Text(loc['name'] ?? 'Loc #${loc['id']}', style: const TextStyle(fontSize: 11)),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => item['location_id'] = val),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("${item['quantity']} ${item['unit'] ?? ''}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => _selectedItems.removeAt(i)),
                                child: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text("Add Inventory Item"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
             Navigator.pop(context);
             widget.onStart([]);
          },
          child: Text("Skip Inventory", style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedItems.isNotEmpty && _selectedItems.any((i) => i['location_id'] == null)) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select location for all items")));
               return;
            }
            Navigator.pop(context);
            widget.onStart(_selectedItems);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text("Confirm & Start", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// --- CompleteServiceDialog ---
class CompleteServiceDialog extends StatefulWidget {
  final String requestId;
  final String roomNumber;
  final List<dynamic> refillItems;
  final Function(List<Map<String, dynamic>> items, int? destId, String? billingStatus) onReturn;
  final Function(String? billingStatus) onJustComplete;
  final bool isFoodService;
  final String currentBillingStatus;

  const CompleteServiceDialog({
    super.key,
    required this.requestId,
    required this.roomNumber,
    this.refillItems = const [],
    required this.onReturn,
    required this.onJustComplete,
    this.isFoodService = false,
    this.currentBillingStatus = 'unbilled',
    this.foodOrderAmount = 0.0,
    this.foodOrderGst = 0.0,
    this.foodOrderTotal = 0.0,
  });

  final double foodOrderAmount;
  final double foodOrderGst;
  final double foodOrderTotal;

  @override
  State<CompleteServiceDialog> createState() => _CompleteServiceDialogState();
}

class _CompleteServiceDialogState extends State<CompleteServiceDialog> {
  bool _returnItems = false;
  List<Map<String, dynamic>> _itemsToReturn = [];
  int? _selectedDestId;
  String? _selectedBillingStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<InventoryProvider>();
      await provider.fetchSellableItems();
      if (provider.locations.isEmpty) await provider.fetchLocations();
      if (widget.refillItems.isNotEmpty && mounted) _populateRefillItems();
    });
  }

  void _populateRefillItems() {
     final allItems = context.read<InventoryProvider>().allItems;
     final locations = context.read<InventoryProvider>().locations;
     if (allItems.isEmpty) return;
     final List<Map<String, dynamic>> itemsToAdd = [];
     for (var ref in widget.refillItems) {
        final iId = ref['item_id'];
        final iQty = ref['quantity'];
        try {
           final item = allItems.firstWhere((i) => i.id == iId);
           itemsToAdd.add({
              'item_id': item.id,
              'name': item.name,
              'quantity': 0.0, 
              'unit': item.unit,
              'assigned_quantity': double.tryParse(iQty.toString()) ?? 0.0,
           });
        } catch (e) {}
     }
     if (itemsToAdd.isNotEmpty && mounted) {
        setState(() {
           _itemsToReturn = itemsToAdd;
           _returnItems = true;
           if (_selectedDestId == null && locations.isNotEmpty) _selectedDestId = locations.first['id'];
        });
     }
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (_) => ItemPickerDialog(
        onPick: (item, qty) {
          setState(() {
            _itemsToReturn.add({
              'item_id': item.id,
              'name': item.name,
              'quantity': qty,
              'unit': item.unit,
              'assigned_quantity': 0.0,
            });
          });
        },
      ),
    );
  }

  Map<String, double> _calculateTotal() {
     double net = widget.foodOrderAmount;
     double gst = widget.foodOrderGst;
     
     if (_returnItems) {
        final allItems = context.read<InventoryProvider>().allItems;
        for (var itemData in _itemsToReturn) {
           final assigned = itemData['assigned_quantity'] as double? ?? 0.0;
           final returned = double.tryParse(itemData['quantity'].toString()) ?? 0.0;
           final used = (assigned - returned).clamp(0.0, 1000.0);
           
           if (used > 0) {
              try {
                 final item = allItems.firstWhere((i) => i.id == itemData['item_id']);
                 if (item.isSellable) {
                    double itemPrice = item.price; // This is selling price
                    // If selling price is 0, we might need a fallback, but per business it should be set.
                    double itemGstRate = item.gstRate ?? 0.0;
                    
                    // We assume selling price is net (base), similar to food order logic.
                    // If it includes GST, we'd need to back-calculate. 
                    // But usually in our app, 'price' is net and we add GST.
                    double itemNet = itemPrice * used;
                    double itemGst = itemNet * (itemGstRate / 100);
                    
                    net += itemNet;
                    gst += itemGst;
                 }
              } catch (e) {}
           }
        }
     }
     
     return {
        'net': net,
        'gst': gst,
        'total': net + gst,
     };
  }

  @override
  Widget build(BuildContext context) {
    final invProvider = context.watch<InventoryProvider>();
    final locations = invProvider.locations;

    return _PremiumDialogBase(
      title: "Complete Service",
      icon: Icons.check_circle_outline,
      baseColor: const Color(0xFF2E7D32),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.meeting_room, color: Colors.green),
                   const SizedBox(width: 8),
                   Text("Room ${widget.roomNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (widget.refillItems.isNotEmpty)
              SwitchListTile(
                title: const Text("Return Unconsumed Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text("Check back items to inventory", style: TextStyle(fontSize: 11)),
                value: _returnItems,
                onChanged: (val) {
                   setState(() => _returnItems = val);
                   if (val && _selectedDestId == null && locations.isNotEmpty) _selectedDestId = locations.first['id'];
                },
              ),
            
            // Billing Summary
            () {
               final summary = _calculateTotal();
               if (summary['total']! <= 0) return const SizedBox.shrink();
               
               return Padding(
                 padding: const EdgeInsets.only(top: 20),
                 child: Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: Colors.blueGrey[50], 
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: Colors.blueGrey[100]!),
                   ),
                   child: Column(
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text("Base Amount", style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                           Text("₹${summary['net']!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                         ],
                       ),
                       const SizedBox(height: 4),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text("GST Amount", style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                           Text("₹${summary['gst']!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                         ],
                       ),
                       const Divider(height: 16),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text("Total (Incl. GST)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                           Text("₹${summary['total']!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                         ],
                       ),
                     ],
                   ),
                 ),
               );
            }(),
            
            if (widget.currentBillingStatus != 'paid') ...[
              const Divider(height: 32),
              const Text("Payment Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text("Collected Cash (Paid)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      secondary: const Icon(Icons.payments_outlined, color: Colors.green, size: 20),
                      value: 'paid',
                      groupValue: _selectedBillingStatus,
                      onChanged: (val) => setState(() => _selectedBillingStatus = val),
                      dense: true,
                    ),
                    RadioListTile<String>(
                      title: const Text("Charge to Room (Unpaid)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      secondary: const Icon(Icons.receipt_long_outlined, color: Colors.orange, size: 20),
                      value: 'unpaid',
                      groupValue: _selectedBillingStatus,
                      onChanged: (val) => setState(() => _selectedBillingStatus = val),
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],

            if (_returnItems) ...[
               const SizedBox(height: 24),
               const Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text("Items to Return", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                   Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
                 ],
               ),
               const SizedBox(height: 12),
               ..._itemsToReturn.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                              onPressed: () => setState(() => _itemsToReturn.remove(item)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text("Qty: ", style: TextStyle(fontSize: 13, color: Colors.grey)),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                onChanged: (val) => setState(() {
                                   item['quantity'] = double.tryParse(val) ?? 0.0;
                                }),
                                controller: TextEditingController.fromValue(
                                  TextEditingValue(
                                    text: item['quantity'].toString(),
                                    selection: TextSelection.collapsed(offset: item['quantity'].toString().length),
                                  ),
                                ),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(" ${item['unit']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (item['assigned_quantity'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Used: ${(item['assigned_quantity'] - item['quantity']).clamp(0.0, 1000.0).toStringAsFixed(2)} ${item['unit']}",
                            style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
               
               OutlinedButton.icon(
                 onPressed: _addItem,
                 icon: const Icon(Icons.add),
                 label: const Text("Add Extra Return Items"),
                 style: OutlinedButton.styleFrom(
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   minimumSize: const Size(double.infinity, 44),
                 ),
               ),
               const SizedBox(height: 16),
               const Text("Default Return Location:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
               const SizedBox(height: 4),
               DropdownButtonFormField<int>(
                  value: _selectedDestId,
                  decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: locations.map<DropdownMenuItem<int>>((loc) => DropdownMenuItem<int>(value: loc['id'], child: Text(loc['name'] ?? 'Loc', style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setState(() => _selectedDestId = val),
               ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.grey[600]))),
        if (_returnItems)
          ElevatedButton(
            onPressed: () {
               bool needsPaymentChoice = widget.isFoodService || widget.refillItems.isNotEmpty;
               if (needsPaymentChoice && widget.currentBillingStatus != 'paid' && _selectedBillingStatus == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a payment status (Paid/Unpaid)")));
                  return;
               }
              Navigator.pop(context);
              widget.onJustComplete(_selectedBillingStatus);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Partial Done"),
          ),
        ElevatedButton(
          onPressed: () {
             bool needsPaymentChoice = widget.isFoodService || widget.refillItems.isNotEmpty;
             if (needsPaymentChoice && widget.currentBillingStatus != 'paid' && _selectedBillingStatus == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a payment status (Paid/Unpaid)")));
                return;
             }
            if (_returnItems) {
               if (_selectedDestId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select location"))); return; }
               if (_itemsToReturn.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add items to return"))); return; }
               Navigator.pop(context);
               widget.onReturn(_itemsToReturn, _selectedDestId, _selectedBillingStatus);
            } else {
               Navigator.pop(context);
               widget.onJustComplete(_selectedBillingStatus);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          child: Text(_returnItems ? "Sync & Close" : "Mark Complete", style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
