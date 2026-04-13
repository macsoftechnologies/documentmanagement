import 'package:flutter/material.dart';
import '../models/document_model.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;

  const DocumentCard({super.key, required this.document});

  Color get _statusColor {
    switch (document.status) {
      case 'expired':
        return Colors.red;
      case 'expiring_soon':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Color get _statusBgColor {
    switch (document.status) {
      case 'expired':
        return Colors.red.shade50;
      case 'expiring_soon':
        return Colors.orange.shade50;
      default:
        return Colors.green.shade50;
    }
  }

  IconData get _statusIcon {
    switch (document.status) {
      case 'expired':
        return Icons.cancel_outlined;
      case 'expiring_soon':
        return Icons.warning_amber_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  String get _statusLabel {
    switch (document.status) {
      case 'expired':
        return 'Expired';
      case 'expiring_soon':
        return 'Expiring Soon';
      default:
        return 'Active';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ✅ Top color bar based on status
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: _statusColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Title row + status chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        document.documentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _statusColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon,
                              size: 13, color: _statusColor),
                          const SizedBox(width: 4),
                          Text(
                            _statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // ✅ Info grid
                Row(
                  children: [
                    Expanded(
                      child: _infoItem(
                        Icons.currency_rupee,
                        'Price',
                        '₹${document.price}',
                      ),
                    ),
                    Expanded(
                      child: _infoItem(
                        Icons.calendar_today_outlined,
                        'Start Date',
                        document.startDate,
                      ),
                    ),
                    Expanded(
                      child: _infoItem(
                        Icons.event_outlined,
                        'Expiry',
                        document.endDate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}