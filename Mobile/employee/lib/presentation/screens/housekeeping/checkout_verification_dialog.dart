import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../data/services/api_service.dart';

// --- Premium Dialog Wrapper ---
class _PremiumDialogBase extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget content;
  final List<Widget> actions;
  final Color baseColor;

  const _PremiumDialogBase({
    required this.title,
    this.subtitle,
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: content,
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions.map((action) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: action,
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutVerificationDialog extends StatefulWidget {
  final String roomNumber;
  final Function() onSuccess;

  const CheckoutVerificationDialog({
    Key? key,
    required this.roomNumber,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<CheckoutVerificationDialog> createState() => _CheckoutVerificationDialogState();
}

class _CheckoutVerificationDialogState extends State<CheckoutVerificationDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  int? _requestId;
  
  List<Map<String, dynamic>> _fixedAssets = [];
  List<Map<String, dynamic>> _consumables = [];
  String _notes = "";

  @override
  void initState() {
    super.initState();
    _fetchRequestIdAndData();
  }

  Future<void> _fetchRequestIdAndData() async {
    try {
      final dio = ApiService().dio;
      final idRes = await dio.get('/bill/checkout-request/${widget.roomNumber}');
      
      if (idRes.statusCode == 200 && idRes.data != null && idRes.data['exists'] == true) {
         _requestId = idRes.data['request_id'];
         await _fetchInventoryDetails();
      } else {
         if (mounted) setState(() {
             _errorMessage = "No active checkout request found for Room ${widget.roomNumber}";
             _isLoading = false;
         });
      }
    } catch (e) {
      if (mounted) setState(() {
          _errorMessage = "Error finding checkout request: $e";
          _isLoading = false;
      });
    }
  }

  Future<void> _fetchInventoryDetails() async {
    try {
      final dio = ApiService().dio;
      final res = await dio.get('/bill/checkout-request/$_requestId/inventory-details');
      
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data;
        final items = (data['items'] as List?) ?? [];
        final fixed = <Map<String, dynamic>>[];
        final cons = <Map<String, dynamic>>[];
        
        for (var i in items) {
           final m = Map<String, dynamic>.from(i);
           if (m['is_fixed_asset'] == true) {
             m['damaged'] = false;
             m['notes'] = "";
             m['cost'] = m['replacement_cost'];
             fixed.add(m);
           } else {
             m['available'] = m['current_stock'];
             cons.add(m);
           }
        }
        
        if (mounted) {
          setState(() {
            _fixedAssets = fixed;
            _consumables = cons;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Failed to load inventory: $e");
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final dio = ApiService().dio;
      final assetDamages = _fixedAssets.where((a) => a['damaged'] == true).map((a) {
         return {
            'item_name': a['name'],
            'replacement_cost': double.tryParse(a['replacement_cost']?.toString() ?? '0') ?? 0.0,
            'notes': a['notes'],
            'item_id': a['item_id'],
         };
      }).toList();

      final items = _consumables.map((c) {
         double current = double.tryParse(c['current_stock']?.toString() ?? '0') ?? 0;
         double available = double.tryParse(c['available'].toString()) ?? 0;
         double used = (current - available).clamp(0, 1000);
         
         return {
           'item_id': c['item_id'],
           'used_qty': used, 
           'missing_qty': 0,
           'damage_qty': 0,
         };
      }).toList();

      final payload = {
        'inventory_notes': _notes,
        'items': items,
        'asset_damages': assetDamages,
      };

      await dio.post('/bill/checkout-request/$_requestId/check-inventory', data: payload);
      
      if (mounted) {
         Navigator.pop(context);
         widget.onSuccess();
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = "Submission Error: $e"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Loading inventory details...", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return _PremiumDialogBase(
      title: "Checkout Audit",
      subtitle: "Verifying Room ${widget.roomNumber}",
      icon: Icons.fact_check_outlined,
      baseColor: const Color(0xFF5E35B1),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             if (_errorMessage != null) 
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red[100]!)),
                 child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)))]),
               ),
             
             if (_fixedAssets.isNotEmpty) ...[
               _sectionHeader("Fixed Assets", Icons.tv),
               ..._fixedAssets.map(_buildFixedAssetRow),
               const SizedBox(height: 16),
             ],
             
             if (_consumables.isNotEmpty) ...[
               _sectionHeader("Consumables", Icons.liquor),
               ..._consumables.map(_buildConsumableRow),
               const SizedBox(height: 16),
             ],

             if (_fixedAssets.isEmpty && _consumables.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No items to verify for this room."))),
             
             const Text("Audit Notes", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
             const SizedBox(height: 8),
             TextField(
                decoration: InputDecoration(
                  hintText: "Enter any findings here...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (v) => _notes = v,
                maxLines: 2,
             ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: (_requestId == null) ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5E35B1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text("Complete Audit", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF5E35B1)),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5E35B1), fontSize: 12, letterSpacing: 1)),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildFixedAssetRow(Map<String, dynamic> item) {
     return Container(
       margin: const EdgeInsets.only(bottom: 8),
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: Colors.grey[200]!),
       ),
       child: Column(
         children: [
           Row(
             children: [
               Expanded(child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
               Checkbox(
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                 value: item['damaged'], 
                 onChanged: (v) => setState(() => item['damaged'] = v)
               ),
               const Text("Damaged", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
             ],
           ),
           if (item['damaged'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextField(
                   decoration: InputDecoration(
                     labelText: "Damage Details", 
                     isDense: true,
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                   ),
                   onChanged: (v) => item['notes'] = v,
                ),
              )
         ],
       ),
     );
  }

  Widget _buildConsumableRow(Map<String, dynamic> item) {
     double current = double.tryParse(item['current_stock']?.toString() ?? '0') ?? 0;
     double available = double.tryParse(item['available'].toString()) ?? current;
     double consumed = (current - available).clamp(0, 1000);
     double rate = double.tryParse(item['charge_per_unit']?.toString() ?? '0') ?? 0;
     double freeLimit = double.tryParse(item['complimentary_limit']?.toString() ?? '0') ?? 0;
     double chargeable = (consumed - freeLimit).clamp(0, 1000);
     double charge = chargeable * rate;

     return Container(
       margin: const EdgeInsets.only(bottom: 8),
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: Colors.grey[200]!),
       ),
       child: Column(
         children: [
           Row(
             children: [
               Expanded(child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
               Text("Stock: ${current.toInt()}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
             ],
           ),
           const SizedBox(height: 12),
           Row(
             children: [
               const Text("Available Now: ", style: TextStyle(fontSize: 13)),
               SizedBox(
                 width: 60, 
                 child: TextFormField(
                   initialValue: available.toString(),
                   keyboardType: TextInputType.number,
                   decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder()),
                   onChanged: (v) => setState(() => item['available'] = double.tryParse(v) ?? 0),
                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                 )
               ),
               const Spacer(),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                   if (consumed > 0) Text("Used: $consumed", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                   if (charge > 0) Text("Charge: ₹${charge.toStringAsFixed(0)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 13)),
                 ],
               )
             ],
           )
         ],
       ),
     );
  }
}
