import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class RefundManagementPage extends StatefulWidget {
  @override
  _RefundManagementPageState createState() => _RefundManagementPageState();
}

class _RefundManagementPageState extends State<RefundManagementPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _allRefunds = [];
  List<dynamic> _filteredRefunds = [];
  bool _loading = true;
  String _filterStatus = 'all'; // all, requested, refunded, rejected

  @override
  void initState() {
    super.initState();
    _fetchRefunds();
  }

  Future<void> _fetchRefunds() async {
    setState(() => _loading = true);
    try {
      // Always fetch all refunds, then filter in memory
      List<dynamic> refunds = await _apiService.getAllRefunds();
      setState(() {
        _allRefunds = refunds;
        _loading = false;
      });
      // Apply filter after state update
      setState(() {
        _applyFilter();
      });
    } catch (e) {
      print("Error fetching refunds: $e");
      if (mounted) {
        setState(() {
          _allRefunds = [];
          _filteredRefunds = [];
          _loading = false;
        });
      }
    }
  }

  void _applyFilter() {
    List<dynamic> filtered;
    if (_filterStatus == 'all') {
      filtered = List.from(_allRefunds);
    } else {
      filtered = _allRefunds.where((refund) {
        final status = refund['status']?.toString().toLowerCase() ?? '';
        return status == _filterStatus.toLowerCase();
      }).toList();
    }
    
    // Sort by requested_at (date and hour) from newest to oldest
    // Every refund should have a requested_at field
    filtered.sort((a, b) {
      DateTime? dateA;
      DateTime? dateB;
      
      // Get requested_at (required field for all refunds)
      try {
        if (a['requested_at'] != null) {
          final dateStr = a['requested_at'].toString();
          // Handle ISO string format (e.g., "2025-12-25T14:30:45.123Z")
          dateA = DateTime.tryParse(dateStr);
          if (dateA == null && dateStr.isNotEmpty) {
            // Try parsing as milliseconds timestamp
            final timestamp = int.tryParse(dateStr);
            if (timestamp != null) {
              dateA = DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
          }
        }
        if (b['requested_at'] != null) {
          final dateStr = b['requested_at'].toString();
          // Handle ISO string format
          dateB = DateTime.tryParse(dateStr);
          if (dateB == null && dateStr.isNotEmpty) {
            // Try parsing as milliseconds timestamp
            final timestamp = int.tryParse(dateStr);
            if (timestamp != null) {
              dateB = DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
          }
        }
      } catch (e) {
        print('Error parsing requested_at: $e');
      }
      
      // Compare dates (newest first - descending order)
      if (dateA != null && dateB != null) {
        // Use millisecondsSinceEpoch for accurate comparison
        final diff = dateB.millisecondsSinceEpoch - dateA.millisecondsSinceEpoch;
        return diff > 0 ? 1 : (diff < 0 ? -1 : 0);
      } else if (dateA != null) {
        return -1; // A has date, comes first
      } else if (dateB != null) {
        return 1; // B has date, comes first
      }
      return 0; // Both missing dates (shouldn't happen)
    });
    
    _filteredRefunds = filtered;
  }

  Future<void> _processRefund(String refundId, String decision, {String? reason}) async {
    try {
      final success = await _apiService.processRefund(refundId, decision, reason: reason);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Refund ${decision == 'approved' ? 'approved' : 'rejected'} successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          _fetchRefunds();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to process refund'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProcessDialog(BuildContext context, Map<String, dynamic> refund) {
    final TextEditingController reasonController = TextEditingController();
    final refundId = refund['id']?.toString() ?? refund['refund_id']?.toString() ?? '';
    final productName = _safeGetString(refund, 'product', 'name') ?? 'Product';
    final customerName = _safeGetString(refund, 'user', 'name') ?? 'Customer';
    final customerEmail = _safeGetString(refund, 'user', 'email') ?? 'N/A';
    final amount = (refund['total_refund_amount'] as num?)?.toDouble() ?? 0.0;
    final quantity = refund['quantity'] ?? 1;
    final orderId = refund['order_id']?.toString() ?? 'N/A';
    final currentReason = _safeGetString(refund, null, 'reason') ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxWidth: 600),
          padding: EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Color(0xFFFF7733), size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Process Refund Request',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Refund ID', '#${refund['refund_id'] ?? refund['id']}'),
                      _buildInfoRow('Order ID', '#$orderId'),
                      _buildInfoRow('Customer', customerName),
                      _buildInfoRow('Email', customerEmail),
                      SizedBox(height: 12),
                      Divider(),
                      SizedBox(height: 12),
                      _buildInfoRow('Product', productName),
                      _buildInfoRow('Quantity', quantity.toString()),
                      _buildInfoRow('Refund Amount', '\$${amount.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Customer Reason:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    currentReason.isEmpty ? 'No reason provided' : currentReason,
                    style: TextStyle(
                      fontSize: 14,
                      color: currentReason.isEmpty ? Colors.grey : Colors.black87,
                      fontStyle: currentReason.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Your Notes / Decision Reason:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Add notes or reason for your decision...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 4,
                ),
                SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _processRefund(refundId, 'rejected', reason: reasonController.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Reject', style: TextStyle(fontSize: 16)),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _processRefund(refundId, 'approved', reason: reasonController.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Approve', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _safeGetString(Map<String, dynamic> map, String? parentKey, String key) {
    try {
      if (parentKey != null) {
        final parent = map[parentKey];
        if (parent is Map) {
          final value = parent[key];
          return value?.toString();
        }
        return null;
      } else {
        final value = map[key];
        return value?.toString();
      }
    } catch (e) {
      return null;
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'requested':
        return Colors.orange;
      case 'refunded':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return "-";
    try {
      String dateStr = dateValue.toString();
      DateTime date;
      // Ensure UTC is properly recognized and converted to local time (UTC+3 for Turkey)
      if (dateStr.endsWith('Z') || dateStr.contains('+00:00')) {
        date = DateTime.parse(dateStr.replaceAll('+00:00', 'Z')).toLocal();
      } else {
        final parsed = DateTime.parse(dateStr);
        date = parsed.isUtc ? parsed.toLocal() : parsed;
      }
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
    } catch (e) {
      return "-";
    }
  }
  
  String _formatDateWithTime(dynamic dateValue) {
    if (dateValue == null) return "Not set";
    try {
      String dateStr = dateValue.toString();
      DateTime date;
      // Ensure UTC is properly recognized and converted to local time (UTC+3 for Turkey)
      if (dateStr.endsWith('Z') || dateStr.contains('+00:00')) {
        date = DateTime.parse(dateStr.replaceAll('+00:00', 'Z')).toLocal();
      } else {
        final parsed = DateTime.parse(dateStr);
        date = parsed.isUtc ? parsed.toLocal() : parsed;
      }
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthName = monthNames[date.month - 1];
      return "${date.day} $monthName ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Invalid date";
    }
  }

  String _getEmptyMessage() {
    switch (_filterStatus) {
      case 'requested':
        return 'No pending refund requests';
      case 'refunded':
        return 'No approved refunds';
      case 'rejected':
        return 'No rejected refunds';
      default:
        return 'No refunds found';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreLayout(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 60),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header section
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Row(
                    children: [
                      Icon(Icons.money_off, color: Color(0xFFFF7733), size: 32),
                      SizedBox(width: 12),
                      Text(
                        'Refund Management',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7733),
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Color(0xFFFF7733)),
                        onPressed: _fetchRefunds,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),
                // Elegant filter section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildFilterChip('All', 'all'),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildFilterChip('Requested', 'requested'),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildFilterChip('Refunded', 'refunded'),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildFilterChip('Rejected', 'rejected'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                // Refunds list
                _loading
                    ? Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFFFF7733)),
                        ),
                      )
                    : _filteredRefunds.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 80,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    _getEmptyMessage(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFFF7733),
                            onRefresh: _fetchRefunds,
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              itemCount: _filteredRefunds.length,
                              itemBuilder: (context, index) {
                                return _buildRefundCard(_filteredRefunds[index]);
                              },
                            ),
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return InkWell(
      onTap: () {
        setState(() {
          _filterStatus = value;
          _applyFilter();
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFFF7733) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildRefundCard(Map<String, dynamic> refund) {
    final status = _safeGetString(refund, null, 'status') ?? 'unknown';
    final productName = _safeGetString(refund, 'product', 'name') ?? 'Unknown Product';
    final customerName = _safeGetString(refund, 'user', 'name') ?? 'Unknown Customer';
    final customerEmail = _safeGetString(refund, 'user', 'email') ?? 'N/A';
    final amount = (refund['total_refund_amount'] as num?)?.toDouble() ?? 0.0;
    final quantity = refund['quantity'] ?? 1;
    final orderId = refund['order_id']?.toString() ?? 'N/A';
    final reason = _safeGetString(refund, null, 'reason') ?? '';
    final requestedAt = _formatDateWithTime(refund['requested_at']);
    final approvedAt = refund['approved_at'] != null 
        ? _formatDateWithTime(refund['approved_at'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refund #${refund['refund_id'] ?? refund['id']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #$orderId',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Customer', customerName),
                  _buildInfoRow('Email', customerEmail),
                  _buildInfoRow('Product', productName),
                  _buildInfoRow('Quantity', quantity.toString()),
                  _buildInfoRow('Amount', '\$${amount.toStringAsFixed(2)}'),
                  if (reason.isNotEmpty) _buildInfoRow('Reason', reason),
                  Divider(height: 16),
                  _buildInfoRow('Requested At', requestedAt),
                  if (approvedAt != null) _buildInfoRow('Processed At', approvedAt),
                ],
              ),
            ),
            if (status == 'requested') ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _showProcessDialog(context, refund),
                  icon: Icon(Icons.edit, size: 18),
                  label: Text('Process Refund'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF7733),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
