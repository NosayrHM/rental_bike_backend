import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/user_service.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  bool _loading = true;
  String? _error;
  int _days = 30;
  List<_IncomePoint> _points = const <_IncomePoint>[];
  double _total = 0;
  double _fees = 0;
  double _net = 0;
  String _currency = 'usd';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await UserService().fetchStripeIncome(days: _days);
      final series =
          (data['series'] as List<dynamic>? ??
                  <dynamic>[]) // ignore: cast_nullable_to_non_nullable
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => _IncomePoint(
                  date: (item['date'] as String?) ?? '',
                  amount: (item['amount'] as num?)?.toDouble() ?? 0,
                ),
              )
              .where((p) => p.date.isNotEmpty)
              .toList();

      setState(() {
        _points = series;
        _total = (data['total'] as num?)?.toDouble() ?? 0;
        _fees = (data['totalFees'] as num?)?.toDouble() ?? 0;
        _net = (data['totalNet'] as num?)?.toDouble() ?? (_total - _fees);
        _currency = (data['currency'] as String?)?.toUpperCase() ?? 'USD';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        title: const Text('Ingresos Stripe'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Últimos $_days días',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DropdownButton<int>(
                    value: _days,
                    dropdownColor: const Color(0xFF1F2937),
                    style: const TextStyle(color: Colors.white),
                    items: const [7, 30, 90, 180]
                        .map(
                          (d) => DropdownMenuItem<int>(
                            value: d,
                            child: Text('$d días'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _days = value;
                      });
                      _load();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total ingresado',
                      amount: _total,
                      currency: _currency,
                      loading: _loading,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Costes Stripe',
                      amount: _fees,
                      currency: _currency,
                      loading: _loading,
                      color: const Color(0xFFF87171),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SummaryCard(
                title: 'Neto',
                amount: _net,
                currency: _currency,
                loading: _loading,
                color: const Color(0xFF34D399),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF38BDF8),
                          ),
                        )
                      : _error != null
                      ? Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        )
                      : _points.isEmpty
                      ? const Text(
                          'Sin movimientos en el periodo seleccionado.',
                          style: TextStyle(color: Colors.white70),
                        )
                      : _IncomeChart(points: _points, currency: _currency),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.currency,
    required this.loading,
    required this.color,
  });

  final String title;
  final double amount;
  final String currency;
  final bool loading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            loading
                ? '...'
                : '${amount.toStringAsFixed(2)} $currency'.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeChart extends StatelessWidget {
  const _IncomeChart({required this.points, required this.currency});

  final List<_IncomePoint> points;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final spots = points
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.amount))
        .toList();

    final minY = spots.isEmpty
        ? 0.0
        : spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.isEmpty
        ? 0.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final singleOrFlat = spots.length <= 1 || (maxY - minY).abs() < 1e-6;
    final padding = singleOrFlat
        ? (maxY == 0 ? 1.0 : (maxY * 0.2).clamp(0.5, 20.0))
        : (maxY - minY).abs() * 0.1;
    final minYValue = (minY - padding).clamp(0.0, double.infinity).toDouble();
    final maxYValue = (maxY + padding).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                horizontalInterval: (maxY / 4).clamp(1, double.infinity),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length)
                        return const SizedBox.shrink();
                      final date = points[index].date;
                      final label = date.length >= 10
                          ? date.substring(5)
                          : date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: minYValue,
              maxY: maxYValue,
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: const Color(0xFF38BDF8),
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF38BDF8).withOpacity(0.2),
                  ),
                  spots: spots,
                  dotData: FlDotData(show: singleOrFlat),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Montos diarios (${currency.toUpperCase()})',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

class _IncomePoint {
  _IncomePoint({required this.date, required this.amount});

  final String date;
  final double amount;
}
