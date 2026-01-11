import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InvoiceManagementPage extends StatefulWidget {
  const InvoiceManagementPage({Key? key}) : super(key: key);

  @override
  State<InvoiceManagementPage> createState() => _InvoiceManagementPageState();
}

class _InvoiceManagementPageState extends State<InvoiceManagementPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _invoices = [];
  bool _isLoading = false;
  
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStatus;
  final List<String> _statuses = ['All', 'processing', 'in-transit', 'delivered', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await _apiService.getInvoices(
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
        status: _selectedStatus == 'All' ? null : _selectedStatus,
      );
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load invoices: $e', isError: true);
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _loadInvoices();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _loadInvoices();
    }
  }

  Future<void> _downloadPDF(String orderId) async {
    try {
      final response = await _apiService.downloadInvoicePDF(orderId);
      if (response != null && response.statusCode == 200) {
        // Convert response body bytes to Uint8List
        final bytes = response.bodyBytes;
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        
        // Create anchor element and trigger download
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'invoice_$orderId.pdf')
          ..style.display = 'none';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        
        // Clean up
        html.Url.revokeObjectUrl(url);
        _showSnackBar('Invoice PDF downloaded successfully');
      } else {
        _showSnackBar('Failed to download PDF', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error downloading PDF: $e', isError: true);
    }
  }

  Future<void> _printInvoice(String orderId) async {
    try {
      final response = await _apiService.downloadInvoicePDF(orderId);
      if (response != null && response.statusCode == 200) {
        // Convert response body bytes to Uint8List
        final bytes = response.bodyBytes;
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        
        // Open PDF in new window for printing
        html.window.open(url, '_blank');
        
        // Note: Don't revoke URL immediately, let browser handle it
        Future.delayed(Duration(seconds: 2), () {
          html.Url.revokeObjectUrl(url);
        });
        
        _showSnackBar('Invoice opened for printing');
      } else {
        _showSnackBar('Failed to load PDF for printing', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error printing invoice: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        title: Text(
          'Invoice Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFFF7733),
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadInvoices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectStartDate,
                        icon: Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _startDate == null
                              ? 'Start Date'
                              : _formatDate(_startDate!.toIso8601String()),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectEndDate,
                        icon: Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _endDate == null
                              ? 'End Date'
                              : _formatDate(_endDate!.toIso8601String()),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus ?? 'All',
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _statuses.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                          _loadInvoices();
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                          _selectedStatus = 'All';
                        });
                        _loadInvoices();
                      },
                      icon: Icon(Icons.clear),
                      label: Text('Clear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Invoices List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)))
                : _invoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No invoices found', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInvoices,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _invoices[index];
                            return _buildInvoiceCard(invoice);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final orderId = invoice['order_id'] ?? 'N/A';
    final user = invoice['user'] ?? {};
    final userName = user['name'] ?? 'Unknown Customer';
    final userEmail = user['email'] ?? 'N/A';
    final totalAmount = (invoice['total_amount'] ?? 0).toDouble();
    final status = invoice['status'] ?? 'unknown';
    final date = _formatDate(invoice['created_at']);
    final items = invoice['items'] ?? [];
    
    Color statusColor;
    switch (status) {
      case 'delivered':
        statusColor = Colors.green;
        break;
      case 'processing':
        statusColor = Colors.orange;
        break;
      case 'in-transit':
        statusColor = Colors.blue;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice #$orderId',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userName,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.email, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userEmail,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items: ${items.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Total: \$${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7733),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.print, color: Color(0xFFFF7733)),
                      onPressed: () => _printInvoice(orderId.toString()),
                      tooltip: 'Print',
                    ),
                    IconButton(
                      icon: Icon(Icons.download, color: Color(0xFFFF7733)),
                      onPressed: () => _downloadPDF(orderId.toString()),
                      tooltip: 'Download PDF',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

