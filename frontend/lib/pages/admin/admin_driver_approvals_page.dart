import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import '../../config/app_config.dart';
import '../../theme/app_theme.dart';

class AdminDriverApprovalsPage extends StatefulWidget {
  const AdminDriverApprovalsPage({super.key});

  @override
  State<AdminDriverApprovalsPage> createState() =>
      _AdminDriverApprovalsPageState();
}

class _AdminDriverApprovalsPageState extends State<AdminDriverApprovalsPage> {
  List<Map<String, dynamic>> _pendingDrivers = [];
  List<Map<String, dynamic>> _allDrivers = [];
  bool _isLoading = true;
  bool _isArabic = true;
  String _selectedFilter = 'pending';
  final TextEditingController _rejectionReasonController =
      TextEditingController();

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'موافقة السائقين',
      'pending': 'قيد الانتظار',
      'approved': 'موافق عليه',
      'rejected': 'مرفوض',
      'all': 'الكل',
      'noDrivers': 'لا يوجد سائقين',
      'loading': 'جاري التحميل...',
      'approve': 'موافقة',
      'reject': 'رفض',
      'rejectionReason': 'سبب الرفض',
      'rejectionReasonRequired': 'يرجى إدخال سبب الرفض',
      'confirmApprove': 'هل أنت متأكد من الموافقة على هذا السائق؟',
      'confirmReject': 'هل أنت متأكد من رفض هذا السائق؟',
      'yes': 'نعم',
      'no': 'لا',
      'cancel': 'إلغاء',
      'driverApproved': 'تم الموافقة على السائق بنجاح',
      'driverRejected': 'تم رفض السائق بنجاح',
      'error': 'خطأ',
      'failed': 'فشلت العملية',
      'name': 'الاسم',
      'email': 'البريد الإلكتروني',
      'license': 'رقم الرخصة',
      'line': 'الخط',
      'status': 'الحالة',
      'actions': 'الإجراءات',
      'filterByStatus': 'تصفية حسب الحالة',
      'phone': 'رقم الهاتف',
    },
    'en': {
      'title': 'Driver Approvals',
      'pending': 'Pending',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'all': 'All',
      'noDrivers': 'No drivers found',
      'loading': 'Loading...',
      'approve': 'Approve',
      'reject': 'Reject',
      'rejectionReason': 'Rejection Reason',
      'rejectionReasonRequired': 'Please enter rejection reason',
      'confirmApprove': 'Are you sure you want to approve this driver?',
      'confirmReject': 'Are you sure you want to reject this driver?',
      'yes': 'Yes',
      'no': 'No',
      'cancel': 'Cancel',
      'driverApproved': 'Driver approved successfully',
      'driverRejected': 'Driver rejected successfully',
      'error': 'Error',
      'failed': 'Operation failed',
      'name': 'Name',
      'email': 'Email',
      'license': 'License ID',
      'line': 'Line',
      'status': 'Status',
      'actions': 'Actions',
      'filterByStatus': 'Filter by Status',
      'phone': 'Phone',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadLanguagePreference();
    _loadDrivers();
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    if (mounted) setState(() {});
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    if (mounted) {
      setState(() {
        _isArabic = isArabic;
      });
    }
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await ApiService.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('error')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      String url;
      if (_selectedFilter == 'pending') {
        url = '${AppConfig.apiBaseUrl}/admin/drivers/pending';
      } else if (_selectedFilter == 'all') {
        url = '${AppConfig.apiBaseUrl}/admin/drivers';
      } else {
        url =
            '${AppConfig.apiBaseUrl}/admin/drivers?approval_status=$_selectedFilter';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final drivers =
            (data['drivers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        if (mounted) {
          setState(() {
            if (_selectedFilter == 'pending') {
              _pendingDrivers = drivers;
            } else {
              _allDrivers = drivers;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveDriver(String driverid) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/admin/drivers/$driverid/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('driverApproved')),
              backgroundColor: Colors.green,
            ),
          );
          _loadDrivers();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectDriver(String driverid, String reason) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/admin/drivers/$driverid/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'rejection_reason': reason}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('driverRejected')),
              backgroundColor: Colors.orange,
            ),
          );
          _loadDrivers();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(Map<String, dynamic> driver) {
    _rejectionReasonController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          t('reject'),
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t('name')}: ${driver['user']?['fullname'] ?? 'N/A'}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: t('rejectionReason'),
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel'),
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_rejectionReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t('rejectionReasonRequired')),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _rejectDriver(
                driver['driverid'] as String,
                _rejectionReasonController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(t('reject')),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          t('approve'),
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '${t('confirmApprove')}\n\n${t('name')}: ${driver['user']?['fullname'] ?? 'N/A'}',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel'),
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _approveDriver(driver['driverid'] as String);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(t('yes')),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'approved':
        return t('approved');
      case 'rejected':
        return t('rejected');
      case 'pending':
        return t('pending');
      default:
        return status ?? 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            t('title'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.appBarColor,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Filter Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 32,
                  ),
                  child: SegmentedButton<String>(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.blue.withOpacity(0.2);
                          }
                          return Colors.transparent;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.blue;
                          }
                          return AppTheme.textSecondary;
                        },
                      ),
                      side: WidgetStateProperty.all(
                        BorderSide(color: AppTheme.borderColor),
                      ),
                    ),
                    segments: [
                      ButtonSegment(
                        value: 'pending',
                        label: Text(t('pending'), softWrap: false),
                        icon: const Icon(Icons.hourglass_empty_rounded),
                      ),
                      ButtonSegment(
                        value: 'approved',
                        label: Text(t('approved'), softWrap: false),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                      ),
                      ButtonSegment(
                        value: 'rejected',
                        label: Text(t('rejected'), softWrap: false),
                        icon: const Icon(Icons.cancel_outlined),
                      ),
                      ButtonSegment(
                        value: 'all',
                        label: Text(t('all'), softWrap: false),
                        icon: const Icon(Icons.list_alt_rounded),
                      ),
                    ],
                    selected: {_selectedFilter},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedFilter = newSelection.first;
                      });
                      _loadDrivers();
                    },
                  ),
                ),
              ),
            ),

            // Drivers List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDriversList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriversList() {
    final drivers =
        _selectedFilter == 'pending' ? _pendingDrivers : _allDrivers;

    if (drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined,
                size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              t('noDrivers'),
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: drivers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final driver = drivers[index];
        final user = driver['user'] as Map<String, dynamic>?;
        final line = driver['line'] as Map<String, dynamic>?;
        final status = driver['approval_status'] as String?;
        final fullName = user?['fullname'] ?? 'N/A';
        final email = user?['email'] ?? 'N/A';
        final phone = user?['phone'] ?? 'N/A';

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with Avatar and Name
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      status == 'approved'
                                          ? Icons.check_circle_rounded
                                          : status == 'rejected'
                                              ? Icons.cancel_rounded
                                              : Icons.access_time_rounded,
                                      size: 14,
                                      color: _getStatusColor(status),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getStatusText(status),
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Details Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDetailRow(
                        Icons.email_outlined, t('email'), email),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                        Icons.phone_outlined, t('phone'), phone),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.badge_outlined, t('license'),
                        driver['licenseid'] ?? 'N/A'),
                    if (line != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.route_outlined, t('line'),
                          line['name'] ?? 'N/A'),
                    ],
                    if (status == 'rejected' &&
                        driver['rejection_reason'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.red.shade700, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  t('rejectionReason'),
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              driver['rejection_reason'],
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions Section (Only for pending)
              if (status == 'pending') ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(driver),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: Text(t('reject')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApproveDialog(driver),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(t('approve')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
