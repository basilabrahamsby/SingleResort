import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';

class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}


class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _groups = [];
  List<dynamic> _ledgers = [];
  int? _selectedGroupId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final groups = await provider.fetchAccountGroups();
    final ledgers = await provider.fetchAccountLedgers();
    
    if (mounted) {
      setState(() {
        _groups = groups;
        _ledgers = ledgers;
        _isLoading = false;
        if (_groups.isNotEmpty && _selectedGroupId == null) {
          _selectedGroupId = _groups.first['id'];
        }
      });
      _animationController.forward(from: 0.0);
    }
  }

  Color _getCategoryColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'asset': return Colors.blue.shade700;
      case 'liability': return Colors.red.shade700;
      case 'revenue': return Colors.green.shade700;
      case 'expense': return Colors.orange.shade700;
      case 'tax': return Colors.purple.shade700;
      default: return Colors.indigo.shade700;
    }
  }

  IconData _getCategoryIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'asset': return Icons.account_balance_wallet_rounded;
      case 'liability': return Icons.credit_card_off_rounded;
      case 'revenue': return Icons.trending_up_rounded;
      case 'expense': return Icons.trending_down_rounded;
      case 'tax': return Icons.receipt_long_rounded;
      default: return Icons.account_balance_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 3),
              SizedBox(height: 16),
              Text('Loading your Chart of Accounts...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final currentGroup = _groups.firstWhere((g) => g['id'] == _selectedGroupId, orElse: () => null);
    
    final filteredLedgers = _ledgers.where((l) {
      final matchesGroup = _selectedGroupId == null || l['group_id'] == _selectedGroupId;
      final matchesSearch = l['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          (l['code']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesGroup && matchesSearch;
    }).toList();

    double totalBalance = filteredLedgers.fold(0.0, (sum, l) => sum + (double.tryParse(l['opening_balance']?.toString() ?? '0') ?? 0.0));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Chart of Accounts', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.indigo),
            onPressed: () => _showAddOptions(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search accounts by name or code...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // Group Selection (Horizontal Scroll)
          Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                final isSelected = _selectedGroupId == group['id'];
                final typeColor = _getCategoryColor(group['account_type']);
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedGroupId = group['id']);
                      _animationController.forward(from: 0.0);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? typeColor : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? typeColor : Colors.grey.shade200,
                          width: 1.5,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: typeColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ] : [],
                      ),
                      child: Center(
                        child: Text(
                          group['name'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Summary Card for Selected Group
          if (_selectedGroupId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getCategoryColor(currentGroup?['account_type']),
                      _getCategoryColor(currentGroup?['account_type']).withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _getCategoryColor(currentGroup?['account_type']).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentGroup?['name']?.toUpperCase() ?? 'TOTAL',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        Icon(_getCategoryIcon(currentGroup?['account_type']), color: Colors.white54, size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text('₹', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 4),
                        Text(
                          totalBalance.toStringAsFixed(2),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${filteredLedgers.length} Accounts in this category',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: filteredLedgers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No ledgers in this group' : 'No matches found',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : FadeTransition(
                    opacity: _animationController,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filteredLedgers.length,
                      itemBuilder: (context, index) {
                        final ledger = filteredLedgers[index];
                        final type = currentGroup?['account_type'];
                        final color = _getCategoryColor(type);
                        
                        return Container(
                          margin: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_getCategoryIcon(type), color: color, size: 22),
                              ),
                              title: Text(
                                ledger['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        ledger['code'] ?? '-',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (ledger['tax_type'] != null && ledger['tax_type'].toString().isNotEmpty)
                                      Icon(Icons.verified_user_rounded, size: 14, color: Colors.green[400]),
                                  ],
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${ledger['opening_balance']?.toStringAsFixed(2) ?? '0.00'}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: (double.tryParse(ledger['opening_balance']?.toString() ?? '0') ?? 0) >= 0 ? Colors.black87 : Colors.red[700],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ledger['balance_type']?.toUpperCase() ?? 'DEBIT',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                              onTap: () {
                                // View ledger details
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }


  void _showAddOptions() {
     showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Add New Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.group_add_rounded, color: Colors.indigo),
              ),
              title: const Text('New Account Group', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Create a high-level category like "Staff Costs"'),
              onTap: () {
                Navigator.pop(context);
                _showAddGroupDialog();
              },
            ),
            const Divider(indent: 70),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_rounded, color: Colors.green),
              ),
              title: const Text('New Account Ledger', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Create a specific account like "Wages Payable"'),
              onTap: () {
                Navigator.pop(context);
                _showAddLedgerDialog();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAddGroupDialog() {
    final nameController = TextEditingController();
    String accountType = 'Revenue';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Account Group', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: accountType,
                items: const [
                  DropdownMenuItem(value: 'Revenue', child: Text('Revenue')),
                  DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                  DropdownMenuItem(value: 'Asset', child: Text('Asset')),
                  DropdownMenuItem(value: 'Liability', child: Text('Liability')),
                  DropdownMenuItem(value: 'Tax', child: Text('Tax')),
                ],
                onChanged: (val) => setDialogState(() => accountType = val!),
                decoration: InputDecoration(
                  labelText: 'Account Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final success = await Provider.of<DashboardProvider>(context, listen: false).createAccountGroup({
                  'name': nameController.text,
                  'account_type': accountType,
                });
                if (success && mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text('Create Group', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLedgerDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final balanceController = TextEditingController();
    int? groupId = _selectedGroupId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Account Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Ledger Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.account_box_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Ledger Code (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.code_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: groupId,
                  items: _groups.map((g) => DropdownMenuItem(
                    value: g['id'] as int,
                    child: Text(g['name']),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => groupId = val),
                  decoration: InputDecoration(
                    labelText: 'Parent Group',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.folder_open_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Opening Balance',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.money_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (groupId == null || nameController.text.isEmpty) return;
                final success = await Provider.of<DashboardProvider>(context, listen: false).createAccountLedger({
                  'name': nameController.text,
                  'code': codeController.text,
                  'group_id': groupId,
                  'opening_balance': double.tryParse(balanceController.text) ?? 0.0,
                  'balance_type': 'debit',
                });
                if (success && mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text('Create Ledger', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
