import 'package:flutter/material.dart';
import '../services/review_service.dart';  // Use existing service!

class ReviewModerationPage extends StatefulWidget {
  @override
  _ReviewModerationPageState createState() => _ReviewModerationPageState();
}

class _ReviewModerationPageState extends State<ReviewModerationPage> {
  final ReviewService _service = ReviewService();  // Use your existing service!
  List<dynamic> _reviews = [];
  Map<String, bool> _eligibilityCache = {};
  Map<String, Map<String, dynamic>> _productCache = {};
  bool _loading = true;
  String? _error;
  bool _showOnlyEligible = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Clear eligibility cache to force fresh check
      _eligibilityCache.clear();
      
      // Use the new backend method from your extended service
      final reviews = await _service.getPendingReviewsFromBackend();
      
      // Check eligibility for each review
      for (var review in reviews) {
        final userId = review['user_id'].toString();
        final productId = review['product_id'].toString();
        final key = '$userId-$productId';
        
        try {
          // Always check eligibility fresh (don't use cache)
          final eligible = await _service.checkReviewEligibility(userId, productId);
          _eligibilityCache[key] = eligible;
          
          // Load product details
          final product = await _service.getProductDetails(productId);
          _productCache[productId] = product;
        } catch (e) {
          print("Error checking eligibility for review: $e");
          _eligibilityCache[key] = false;
        }
      }

      setState(() {
        _reviews = reviews;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isEligible(Map<String, dynamic> review) {
    final key = '${review['user_id']}-${review['product_id']}';
    return _eligibilityCache[key] ?? false;
  }

  List<dynamic> get _filteredReviews {
    if (_showOnlyEligible) {
      return _reviews.where((review) => _isEligible(review)).toList();
    }
    return _reviews;
  }

  Future<void> _handleApprove(Map<String, dynamic> review) async {
    final eligible = _isEligible(review);
    
    if (!eligible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot approve: User has not received this product',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Review'),
        content: Text(
          'Are you sure you want to approve this review?\n\n'
          'Product: ${_productCache[review['product_id'].toString()]?['name'] ?? 'Unknown'}\n'
          'Rating: ${review['rating']} ⭐\n'
          'User: ${review['author_name']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.approveReview(review['review_id']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReviews();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> review) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a reason for rejection:'),
            SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g., Inappropriate content, spam, etc.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please provide a reason for rejection'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        await _service.rejectReview(review['review_id'], reason);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadReviews();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibleCount = _reviews.where((r) => _isEligible(r)).length;
    final ineligibleCount = _reviews.length - eligibleCount;

    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        backgroundColor: Color(0xFFFF7733),
        title: Text('Review Moderation'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReviews,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats and Filter Bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(
                      'Pending',
                      _reviews.length,
                      Colors.orange,
                      Icons.pending_actions,
                    ),
                    _buildStatCard(
                      'Eligible',
                      eligibleCount,
                      Colors.green,
                      Icons.check_circle,
                    ),
                    _buildStatCard(
                      'Ineligible',
                      ineligibleCount,
                      Colors.red,
                      Icons.block,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SwitchListTile(
                  title: Text('Show only eligible reviews'),
                  value: _showOnlyEligible,
                  activeColor: Color(0xFFFF7733),
                  onChanged: (value) {
                    setState(() => _showOnlyEligible = value);
                  },
                ),
              ],
            ),
          ),

          // Reviews List
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF7733),
                    ),
                  )
                : _error != null
                    ? _buildError()
                    : _filteredReviews.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.green,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  _showOnlyEligible
                                      ? 'No eligible reviews to moderate'
                                      : 'No pending reviews',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _filteredReviews.length,
                            itemBuilder: (context, index) {
                              return _buildReviewCard(_filteredReviews[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final eligible = _isEligible(review);
    final productId = review['product_id'].toString();
    final product = _productCache[productId];
    final rating = review['rating'] ?? 0;
    final comment = review['comment'] ?? '';
    final authorName = review['author_name'] ?? 'Anonymous';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: eligible ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 2,
        ),
      ),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with eligibility badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product?['name'] ?? 'Product #$productId',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7733),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'by $authorName',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: eligible
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: eligible ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        eligible ? Icons.check_circle : Icons.block,
                        size: 16,
                        color: eligible ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: 6),
                      Text(
                        eligible ? 'ELIGIBLE' : 'INELIGIBLE',
                        style: TextStyle(
                          color: eligible ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Rating
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 24,
                  );
                }),
                SizedBox(width: 8),
                Text(
                  '($rating/5)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (comment.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  comment,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],

            // Eligibility warning
            if (!eligible) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'User has not received this product yet. Cannot approve until delivery is confirmed.',
                        style: TextStyle(
                          color: Colors.red[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(review),
                    icon: Icon(Icons.check),
                    label: Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: eligible ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(review),
                    icon: Icon(Icons.close),
                    label: Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Error loading reviews'),
          SizedBox(height: 8),
          Text(_error ?? ''),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadReviews,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF7733),
            ),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}