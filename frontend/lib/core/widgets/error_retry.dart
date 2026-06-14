import 'package:flutter/material.dart';

const _red = Color(0xFFFF1E1E);

/// Full-screen error state shown when an API call fails.
/// Detects network vs server errors and shows an appropriate icon + message.
class ErrorRetryWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final String? retryLabel;

  const ErrorRetryWidget({
    super.key,
    required this.error,
    required this.onRetry,
    this.retryLabel,
  });

  bool get _isNetworkError {
    final lower = error.toLowerCase();
    return lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('refused') ||
        lower.contains('timeout') ||
        lower.contains('unreachable') ||
        lower.contains('host');
  }

  @override
  Widget build(BuildContext context) {
    final isNetwork = _isNetworkError;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                color: Colors.grey[600],
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isNetwork ? "Can't reach the server" : 'Something went wrong',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isNetwork
                  ? 'Check your connection and try again.'
                  : 'An unexpected error occurred. Please retry.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            // Subtle technical detail
            Text(
              error,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(retryLabel ?? 'Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
