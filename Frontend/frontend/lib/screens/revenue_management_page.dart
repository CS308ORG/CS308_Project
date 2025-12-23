import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class RevenueManagementPage extends StatefulWidget {
  const RevenueManagementPage({Key? key}) : super(key: key);

  @override
  State<RevenueManagementPage> createState() => _RevenueManagementPageState();
}

class _RevenueManagementPageState extends State<RevenueManagementPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  
  DateTime? _startDate;
  DateTime? _endDate;
  
  Map<String, dynamic>? _revenueData;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to last 30 days
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(Duration(days: 30));
    _loadRevenue();
  }

  Future<void> _loadRevenue() async {
    if (_startDate == null || _endDate == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final data = await _apiService.getRevenue(
        startDate: _startDate!.toIso8601String().split('T')[0],
        endDate: _endDate!.toIso8601String().split('T')[0],
      );
      setState(() {
        _revenueData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _loadRevenue();
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
      _loadRevenue();
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        title: Text('Revenue & Profit Analysis'),
        backgroundColor: Color(0xFFFF7733),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRevenue,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Selector
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectStartDate,
                    icon: Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _startDate == null
                          ? 'Start Date'
                          : _formatDate(_startDate!),
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
                          : _formatDate(_endDate!),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadRevenue,
                  icon: Icon(Icons.calculate),
                  label: Text('Calculate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF7733),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red),
                            SizedBox(height: 16),
                            Text('Error: $_error', style: TextStyle(color: Colors.red)),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadRevenue,
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _revenueData == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('Select date range and calculate', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadRevenue,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Summary Cards
                                  _buildSummaryCards(),
                                  SizedBox(height: 24),
                                  
                                  // Chart
                                  _buildChart(),
                                ],
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_revenueData == null) return SizedBox();
    
    final summary = _revenueData!['summary'] ?? {};
    final totalRevenue = summary['total_revenue'] ?? 0.0;
    final totalCost = summary['total_cost'] ?? 0.0;
    final totalProfit = summary['total_profit'] ?? 0.0;
    final profitMargin = summary['profit_margin'] ?? 0.0;
    final orderCount = _revenueData!['order_count'] ?? 0;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Revenue',
                '\$${totalRevenue.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Total Cost',
                '\$${totalCost.toStringAsFixed(2)}',
                Icons.shopping_cart,
                Colors.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Profit',
                '\$${totalProfit.toStringAsFixed(2)}',
                Icons.trending_up,
                totalProfit >= 0 ? Colors.blue : Colors.red,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Profit Margin',
                '${profitMargin.toStringAsFixed(2)}%',
                Icons.percent,
                Colors.purple,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, color: Color(0xFFFF7733)),
              SizedBox(width: 8),
              Text(
                'Orders: $orderCount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
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
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_revenueData == null) return SizedBox();
    
    final dailyData = _revenueData!['daily_data'] ?? [];
    if (dailyData.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No data available for selected date range',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Revenue & Profit Chart',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getMaxValue(dailyData) / 5,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: dailyData.length > 15 ? 2.0 : 1.0,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        // Only show labels for valid integer indices
                        if (index >= 0 && index < dailyData.length && value == index.toDouble()) {
                          final dateStr = (dailyData[index] as Map<String, dynamic>)['date'] as String;
                          if (dateStr != null && dateStr.isNotEmpty) {
                            try {
                              final dateParts = dateStr.split('-');
                              if (dateParts.length >= 3) {
                                final day = dateParts[2];
                                final month = dateParts[1];
                                // Show day/month for better readability
                                return Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    '$day/$month',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                            } catch (e) {
                              // Fallback to day only
                              return Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  dateStr.split('-')[2],
                                  style: TextStyle(fontSize: 10),
                                ),
                              );
                            }
                          }
                        }
                        return Text('');
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  // Revenue line
                  LineChartBarData(
                    spots: List<FlSpot>.from(
                      dailyData.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          ((entry.value as Map<String, dynamic>)['revenue'] ?? 0).toDouble(),
                        );
                      }),
                    ),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Profit line
                  LineChartBarData(
                    spots: List<FlSpot>.from(
                      dailyData.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          ((entry.value as Map<String, dynamic>)['profit'] ?? 0).toDouble(),
                        );
                      }),
                    ),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                minX: -0.5,
                maxX: (dailyData.length - 1).toDouble() + 0.5,
                minY: 0,
                maxY: _getMaxValue(dailyData) * 1.1,
              ),
            ),
          ),
          SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Revenue', Colors.green),
              SizedBox(width: 24),
              _buildLegendItem('Profit', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }

  double _getMaxValue(List<dynamic> dailyData) {
    if (dailyData.isEmpty) return 100;
    double max = 0;
    for (var data in dailyData) {
      final revenue = (data['revenue'] ?? 0).toDouble();
      final profit = (data['profit'] ?? 0).toDouble();
      max = max > revenue ? max : revenue;
      max = max > profit ? max : profit;
    }
    return max > 0 ? max : 100;
  }
}

