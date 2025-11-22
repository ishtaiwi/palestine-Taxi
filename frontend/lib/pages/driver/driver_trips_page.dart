import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class DriverTripsPage extends StatefulWidget {
  const DriverTripsPage({super.key});

  @override
  State<DriverTripsPage> createState() => _DriverTripsPageState();
}

class _DriverTripsPageState extends State<DriverTripsPage> {
  bool _isArabic = true;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _trips = [];
  final Map<String, List<Map<String, dynamic>>> _reservations = {};
  final Set<String> _loadingReservations = {};
  final Set<String> _mutatingReservations = {};

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'رحلاتي',
      'subtitle': 'تابع رحلاتك القادمة وطلبات الركاب',
      'noTrips': 'لا توجد رحلات قادمة حالياً',
      'departure': 'موعد الانطلاق',
      'line': 'الخط',
      'status': 'الحالة',
      'seats': 'المقاعد المتاحة',
      'bookings': 'الحجوزات',
      'reservations': 'طلبات الحجز',
      'passenger': 'الراكب',
      'seat': 'المقعد',
      'accept': 'قبول',
      'reject': 'رفض',
      'checkin': 'تأكيد الصعود',
      'pending': 'بانتظار تأكيدك',
      'approved': 'تمت الموافقة',
      'rejected': 'مرفوض',
      'none': 'لا توجد طلبات حالياً',
      'refresh': 'تحديث',
      'checkinQR': 'مسح QR Code',
      'startTrip': 'بدء الرحلة',
      'endTrip': 'إنهاء الرحلة',
      'assignedDriver': 'السائق المخصص',
      'distributedPassengers': 'الركاب الموزعين',
      'enterBookingId': 'أدخل رقم الحجز',
      'checked_in': 'تم الصعود',
    },
    'en': {
      'title': 'My Trips',
      'subtitle': 'Track upcoming trips and passenger requests',
      'noTrips': 'No upcoming trips yet',
      'departure': 'Departure',
      'line': 'Line',
      'status': 'Status',
      'seats': 'Seats left',
      'bookings': 'Bookings',
      'reservations': 'Seat requests',
      'passenger': 'Passenger',
      'seat': 'Seat',
      'accept': 'Approve',
      'reject': 'Reject',
      'checkin': 'Check-in',
      'pending': 'Waiting for your approval',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'none': 'No reservations yet',
      'refresh': 'Refresh',
      'checkinQR': 'Scan QR Code',
      'startTrip': 'Start Trip',
      'endTrip': 'End Trip',
      'assignedDriver': 'Assigned Driver',
      'distributedPassengers': 'Distributed Passengers',
      'enterBookingId': 'Enter Booking ID',
      'checked_in': 'Checked In',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final isArabic = await ApiService.getLanguagePreference();
    if (mounted) {
      setState(() {
        _isArabic = isArabic;
      });
    }
    await _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trips = await ApiService.fetchDriverTrips(upcomingOnly: true);
      if (!mounted) return;
      setState(() {
        _trips = trips;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReservations(String tripId) async {
    if (_loadingReservations.contains(tripId)) {
      return;
    }

    setState(() {
      _loadingReservations.add(tripId);
    });

    final result = await ApiService.fetchDriverTripReservations(tripId);
    if (!mounted) return;

    setState(() {
      _loadingReservations.remove(tripId);
      if (result['success'] == true) {
        final reservations = (result['reservations'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        _reservations[tripId] = reservations;
      } else if (result['message'] != null) {
        _error = result['message'].toString();
      }
    });
  }

  Future<void> _updateReservationStatus(
      String tripId, String bookingId, String action) async {
    setState(() {
      _mutatingReservations.add(bookingId);
    });

    final result = await ApiService.updateDriverReservationStatus(
      tripId: tripId,
      bookingId: bookingId,
      action: action,
    );

    if (!mounted) return;

    setState(() {
      _mutatingReservations.remove(bookingId);
      if (result['success'] == true && result['reservation'] is Map) {
        final updated = Map<String, dynamic>.from(result['reservation']);
        final list = _reservations[tripId];
        if (list != null) {
          final index =
              list.indexWhere((item) => item['bookingid'] == bookingId);
          if (index != -1) {
            list[index] = updated;
          }
        }
      } else if (result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'].toString())),
        );
      }
    });
  }

  Future<void> _checkInReservation(String bookingId) async {
    try {
      final result = await ApiService.checkInReservation(bookingId);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('checkin')),
              backgroundColor: Colors.green,
            ),
          );
          // Reload reservations
          for (final tripId in _reservations.keys) {
            _loadReservations(tripId);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCheckInDialog(String tripId) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          t('checkin'),
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: t('enterBookingId'),
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'Booking ID',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white54),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white54),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            onPressed: () {
              final bookingId = controller.text.trim();
              if (bookingId.isNotEmpty) {
                Navigator.pop(context);
                _checkInReservation(bookingId);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(t('checkin')),
          ),
        ],
      ),
    );
  }

  Future<void> _startTrip(String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          t('startTrip'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _isArabic
              ? 'هل أنت متأكد من بدء هذه الرحلة؟'
              : 'Are you sure you want to start this trip?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(t('startTrip')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.startTrip(tripId);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('startTrip')),
              backgroundColor: Colors.green,
            ),
          );
          _loadTrips();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endTrip(String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          t('endTrip'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _isArabic
              ? 'هل أنت متأكد من إنهاء هذه الرحلة؟'
              : 'Are you sure you want to end this trip?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(t('endTrip')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.endTrip(tripId);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('endTrip')),
              backgroundColor: Colors.green,
            ),
          );
          _loadTrips();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF060A1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A5F), // خلفية فاتحة أكثر
          foregroundColor: Colors.white,
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            t('title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isArabic ? Icons.language : Icons.translate,
                color: Colors.white,
              ),
              onPressed: () async {
                final next = !_isArabic;
                await ApiService.saveLanguagePreference(next);
                if (mounted) {
                  setState(() {
                    _isArabic = next;
                  });
                }
              },
              tooltip: _isArabic ? 'English' : 'العربية',
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadTrips,
              tooltip: t('refresh'),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white), // نص أبيض على خلفية غامقة
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadTrips,
                child: Text(t('refresh')),
              ),
            ],
          ),
        ),
      );
    }

    if (_trips.isEmpty) {
      return Center(
        child: Text(
          t('noTrips'),
          style: const TextStyle(color: Colors.white), // نص أبيض على خلفية غامقة
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _loadTrips,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t('subtitle'),
            style: const TextStyle(
              color: Colors.white, // نص أبيض على خلفية غامقة
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ..._trips.map(_buildTripTile),
        ],
      ),
    );
  }

  Widget _buildTripTile(Map<String, dynamic> trip) {
    final tripId = trip['tripid']?.toString() ?? '';
    final line = trip['line'] as Map<String, dynamic>? ?? {};
    final departureTime = _formatDateTime(trip['deptime']);
    final status = trip['status']?.toString() ?? 'scheduled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) {
            _loadReservations(tripId);
          }
        },
        collapsedIconColor: Colors.white,
        iconColor: Colors.orange,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line['linename']?.toString() ?? '---',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${t('departure')}: $departureTime',
              style: const TextStyle(color: Colors.white, fontSize: 12), // نص أبيض على خلفية غامقة
            ),
            const SizedBox(height: 2),
            Text(
              '${t('status')}: $status',
              style: const TextStyle(color: Colors.white, fontSize: 12), // نص أبيض على خلفية غامقة
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          _buildTripStatsRow(trip),
          // Assigned Driver Info
          if (trip['assigned_driverid'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    t('assignedDriver'),
                    style: const TextStyle(color: Colors.white, fontSize: 14), // نص أبيض على خلفية غامقة
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Trip Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCheckInDialog(tripId),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(t('checkinQR')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (status == 'open' || status == 'scheduled')
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _startTrip(tripId),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(t('startTrip')),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (status == 'in_progress')
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _endTrip(tripId),
                    icon: const Icon(Icons.stop),
                    label: Text(t('endTrip')),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildReservationsSection(tripId),
        ],
      ),
    );
  }

  Widget _buildTripStatsRow(Map<String, dynamic> trip) {
    final availSeats = trip['availableseats']?.toString() ?? '--';
    final totalBookings = trip['totalbookings']?.toString() ?? '0';

    Widget buildStat(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white, // نص أبيض على خلفية غامقة
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildStat(t('seats'), availSeats),
        const SizedBox(width: 12),
        buildStat(t('bookings'), totalBookings),
      ],
    );
  }

  Widget _buildReservationsSection(String tripId) {
    final loading = _loadingReservations.contains(tripId);
    final reservations = _reservations[tripId];

    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('reservations'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (reservations == null)
          Text(
            t('none'),
            style: const TextStyle(color: Colors.white), // نص أبيض على خلفية غامقة
          )
        else if (reservations.isEmpty)
          Text(
            t('none'),
            style: const TextStyle(color: Colors.white), // نص أبيض على خلفية غامقة
          )
        else
          Column(
            children: reservations.map((reservation) {
              return _buildReservationCard(tripId, reservation);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildReservationCard(
    String tripId,
    Map<String, dynamic> reservation,
  ) {
    final passenger = reservation['passenger'] as Map<String, dynamic>? ?? {};
    final user = passenger['user'] as Map<String, dynamic>? ?? {};
    final status = reservation['status']?.toString() ?? '';
    final driverStatus = reservation['driver_status']?.toString() ?? 'pending';
    final bookingId = reservation['bookingid']?.toString() ?? '';
    final isMutating = _mutatingReservations.contains(bookingId);
    final seat = reservation['seatlocation']?.toString() ?? '-';

    String driverStatusText;
    Color driverStatusColor;
    switch (driverStatus) {
      case 'approved':
        driverStatusText = t('approved');
        driverStatusColor = Colors.greenAccent;
        break;
      case 'rejected':
        driverStatusText = t('rejected');
        driverStatusColor = Colors.redAccent;
        break;
      default:
        driverStatusText = t('pending');
        driverStatusColor = Colors.orangeAccent;
    }

    final isCheckedIn = status == 'checked_in';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.2),
                child: Text(
                  (user['fullname']?.toString().isNotEmpty ?? false)
                      ? user['fullname'].toString()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['fullname']?.toString() ?? t('passenger'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${t('seat')}: $seat',
                      style: const TextStyle(color: Colors.white, fontSize: 12), // نص أبيض على خلفية غامقة
                    ),
                  ],
                ),
              ),
              Text(
                status,
                style: const TextStyle(
                  color: Colors.white, // نص أبيض على خلفية غامقة
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: driverStatusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              driverStatusText,
              style: TextStyle(
                color: driverStatusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (driverStatus != 'approved' && driverStatus != 'rejected')
                FilledButton(
                  onPressed: isMutating
                      ? null
                      : () => _updateReservationStatus(tripId, bookingId, 'approve'),
                  child: isMutating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t('accept')),
                ),
              if (driverStatus != 'rejected' && status != 'cancelled')
                FilledButton.tonal(
                  onPressed: isMutating
                      ? null
                      : () => _updateReservationStatus(tripId, bookingId, 'reject'),
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: isMutating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t('reject')),
                ),
              if (driverStatus == 'approved' && status != 'checked_in')
                FilledButton.tonal(
                  onPressed: isMutating
                      ? null
                      : () {
                          setState(() {
                            _mutatingReservations.add(bookingId);
                          });
                          _checkInReservation(bookingId).then((_) {
                            if (mounted) {
                              setState(() {
                                _mutatingReservations.remove(bookingId);
                              });
                              _loadReservations(tripId);
                            }
                          });
                        },
                  child: isMutating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t('checkin')),
                ),
              if (isCheckedIn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        t('checked_in'),
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '--';
    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value.toString();
    }
  }
}

