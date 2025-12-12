import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget? emptyState;

  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getCardBorder(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            child,
        ],
      ),
    );
  }
}

