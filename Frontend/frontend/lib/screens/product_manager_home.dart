import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProductManagerHome extends StatefulWidget {
  final String username;
  final String role;

  const ProductManagerHome({super.key, required this.username, required this.role});

  @override
  State<ProductManagerHome> createState() => _ProductManagerHomeState();
}

class _ProductManagerHomeState extends State<ProductManagerHome> {
  final ApiService _apiService = ApiService();
  final Set<String> _busyReviews = {};

  List<dynamic> _pendingReviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPendingReviews();
  }

  Future<void> _fetchPendingReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final reviews = await _apiService.getPendingReviewsForModeration();
    if (!mounted) return;
    setState(() {
      _pendingReviews = reviews;
      _loading = false;
      if (reviews.isEmpty) {
        _error = null;
      }
    });
  }

  Future<void> _handleDecision(String reviewId, String decision) async {
    setState(() {
      _busyReviews.add(reviewId);
    });

    final success = await _apiService.updateReviewApproval(reviewId, decision);

    if (!mounted) return;
    setState(() {
      _busyReviews.remove(reviewId);
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review ${decision == 'approved' ? 'approved' : 'rejected'}')),
      );
      await _fetchPendingReviews();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update review')),
      );
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '-';
    try {
      final parsed = DateTime.parse(isoString);
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)))
        : _pendingReviews.isEmpty
            ? Center(
                child: Text(
                  _error ?? 'No reviews awaiting approval.',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pendingReviews.length,
                itemBuilder: (context, index) {
                  final review = _pendingReviews[index] as Map<String, dynamic>;
                  final reviewId =
                      review['review_id']?.toString() ?? review['id']?.toString() ?? '';
                  return _ReviewCard(
                    review: review,
                    busy: _busyReviews.contains(reviewId),
                    onApprove: () => _handleDecision(reviewId, 'approved'),
                    onReject: () => _handleDecision(reviewId, 'rejected'),
                    formatDate: _formatDate,
                  );
                },
              );

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6),
      appBar: AppBar(
        title: const Text('Product Manager Dashboard'),
        backgroundColor: const Color(0xFFFF7733),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPendingReviews,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF7733),
        onRefresh: _fetchPendingReviews,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Column(
              children: [
                const Icon(Icons.inventory, size: 80, color: Color(0xFFFF7733)),
                const SizedBox(height: 16),
                const Text(
                  'Product Manager Portal',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Username: ${widget.username}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Chip(
                  backgroundColor: const Color(0xFFFF7733),
                  label: Text(
                    'Role: ${widget.role}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Pending Reviews',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool busy;
  final String Function(String?) formatDate;

  const _ReviewCard({
    required this.review,
    required this.onApprove,
    required this.onReject,
    required this.busy,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = review['comment']?.toString() ?? '';
    final author = review['author_name'] ?? 'Customer';
    final productId = review['product_id'];
    final created = formatDate(review['timestamp']?.toString());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Product ID: $productId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  created,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(author, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              comment.isEmpty ? '(No comment provided)' : comment,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: const Icon(Icons.check),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close, color: Colors.red),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
