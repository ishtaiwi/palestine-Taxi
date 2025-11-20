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

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF060A1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B132B),
          foregroundColor: Colors.white,
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
                style: const TextStyle(color: Colors.white70),
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
          style: const TextStyle(color: Colors.white70),
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
              color: Colors.white70,
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
        collapsedIconColor: Colors.white70,
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
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              '${t('status')}: $status',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          _buildTripStatsRow(trip),
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
                  color: Colors.white70,
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
            style: const TextStyle(color: Colors.white54),
          )
        else if (reservations.isEmpty)
          Text(
            t('none'),
            style: const TextStyle(color: Colors.white54),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                status,
                style: const TextStyle(
                  color: Colors.white54,
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
                      : () => _updateReservationStatus(tripId, bookingId, 'checkin'),
                  child: isMutating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t('checkin')),
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

