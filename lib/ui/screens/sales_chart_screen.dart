import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/api_config.dart';
import '../../providers/auth_provider.dart';

class SalesChartScreen extends StatefulWidget {
  final String? initialShopId;

  const SalesChartScreen({super.key, this.initialShopId});

  @override
  State<SalesChartScreen> createState() => _SalesChartScreenState();
}

class _SalesChartScreenState extends State<SalesChartScreen> {
  bool _isLoading = false;
  String _filterType = 'monthly'; // 'monthly' or 'custom'
  DateTime _currentMonth = DateTime.now();
  DateTime? _startDate;
  DateTime? _endDate;
  
  List<String> _labels = [];
  List<double> _data = [];
  double _maxY = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setMonthlyRange();
    _fetchChartData();
  }

  void _setMonthlyRange() {
    _startDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
    // Hari terakhir bulan ini
    _endDate = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
  }

  Future<void> _fetchChartData() async {
    if (_startDate == null || _endDate == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken();
      
      final start = DateFormat('yyyy-MM-dd').format(_startDate!);
      final end = DateFormat('yyyy-MM-dd').format(_endDate!);
      
      String url = '${ApiConfig.apiUrl}/finance/chart?start_date=$start&end_date=$end';
      if (widget.initialShopId != null && widget.initialShopId!.isNotEmpty) {
        url += '&shop_id=${widget.initialShopId}';
      }

      debugPrint("CHART URL: $url");

      final response = await http.get(Uri.parse(url), headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      });

      debugPrint("CHART STATUS: ${response.statusCode}");
      debugPrint("CHART BODY: ${response.body}");

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['status'] == 'success') {
          final chartData = resData['chart'];
          List<dynamic> rawLabels = chartData['labels'] ?? [];
          List<dynamic> rawData = chartData['data'] ?? [];
          
          setState(() {
            _labels = rawLabels.map((e) => e.toString()).toList();
            _data = rawData.map((e) => double.tryParse(e.toString()) ?? 0).toList();
            
            if (_data.isNotEmpty) {
              double highest = _data.reduce((a, b) => a > b ? a : b);
              _maxY = highest <= 0 ? 1000000 : highest + (highest * 0.2);
            } else {
              _maxY = 1000000;
            }
          });
        } else {
          setState(() => _errorMessage = resData['message'] ?? 'Gagal mengambil data grafik.');
        }
      } else {
        setState(() => _errorMessage = 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching chart: $e");
      setState(() => _errorMessage = 'Gagal terhubung ke server: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)), // Beri jarak 1 tahun ke depan untuk cegah error
      initialDateRange: _startDate != null && _endDate != null 
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchChartData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grafik Omzet', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Filter Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Bulanan'),
                      selected: _filterType == 'monthly',
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _filterType = 'monthly';
                            _currentMonth = DateTime.now();
                            _setMonthlyRange();
                          });
                          _fetchChartData();
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Kustom'),
                      selected: _filterType == 'custom',
                      onSelected: (val) {
                        if (val) {
                          setState(() => _filterType = 'custom');
                          _selectDateRange();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (_filterType == 'monthly')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                            _setMonthlyRange();
                          });
                          _fetchChartData();
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(_currentMonth),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                            _setMonthlyRange();
                          });
                          _fetchChartData();
                        },
                      ),
                    ],
                  )
                else
                  InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            _startDate != null && _endDate != null
                                ? '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}'
                                : 'Pilih Rentang Tanggal',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, size: 64, color: Colors.orange[300]),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchChartData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        )
                      ],
                    ),
                  )
              : _data.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insert_chart_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Tidak ada data omzet pada periode ini', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 24, left: 16, top: 32, bottom: 16),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _maxY / 5 == 0 ? 1 : _maxY / 5,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1);
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: _labels.length > 7 ? (_labels.length / 5).ceilToDouble() : 1,
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index < 0 || index >= _labels.length) return const SizedBox.shrink();
                                // Ambil tanggalnya saja (misal dari "01 Aug" jadi "1")
                                String label = _labels[index].split(' ')[0];
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: _maxY / 5 == 0 ? 1 : _maxY / 5,
                              reservedSize: 42,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox.shrink();
                                String text;
                                if (value >= 1000000) {
                                  text = '${(value / 1000000).toStringAsFixed(1)}Jt';
                                } else if (value >= 1000) {
                                  text = '${(value / 1000).toStringAsFixed(0)}k';
                                } else {
                                  text = value.toStringAsFixed(0);
                                }
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (_data.length - 1).toDouble(),
                        minY: 0,
                        maxY: _maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                            isCurved: false,
                            color: AppColors.primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => Colors.blueGrey.shade800,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((LineBarSpot touchedSpot) {
                                final dateStr = _labels[touchedSpot.x.toInt()];
                                final valStr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(touchedSpot.y);
                                return LineTooltipItem(
                                  '$dateStr\n$valStr',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
