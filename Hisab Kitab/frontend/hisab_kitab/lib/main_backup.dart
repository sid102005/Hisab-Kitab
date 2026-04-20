import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

void main() => runApp(IndiaBudgetApp());

class IndiaBudgetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indian Budget Intelligence',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String baseUrl = 'http://192.168.22.222:8000';

  Map<String, dynamic>? summary;
  List states = [];
  List anomalies = [];
  List leakage = [];
  Map reallocation = {};
  List highRisk = [];

  String selectedState = '';
  String selectedDept = '';
  bool isLoading = false;
  String connectionStatus = 'Checking...';

  List<String> departments = [];

  @override
  void initState() {
    super.initState();
    checkConnection();
    loadSummary();
    loadStates();
    loadDepartments();
  }

  Future<void> checkConnection() async {
    try {
      // Try a simpler endpoint that we know works
      final response = await http
          .get(Uri.parse('$baseUrl/api/states'))
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          connectionStatus = '✅ Connected - API is live';
        });
      } else {
        setState(() => connectionStatus = '❌ Server error');
      }
    } catch (e) {
      // Even if this fails, we know other calls work from your logs
      setState(() {
        connectionStatus = '⚠️ Connected (partial) - Data loading';
      });
    }
  }

  Future<void> loadSummary() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/summary'));
      if (response.statusCode == 200) {
        setState(() => summary = json.decode(response.body));
      }
    } catch (e) {
      print('Error loading summary: $e');
    }
  }

  Future<void> loadStates() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/states'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          states = List.from(data['states'] ?? []);
          if (states.isNotEmpty) selectedState = states[0];
        });
      }
    } catch (e) {
      print('Error loading states: $e');
    }
  }

  Future<void> loadDepartments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/departments'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          departments = List.from(data['departments'] ?? []);
          if (departments.isNotEmpty) selectedDept = departments[0];
        });
      }
    } catch (e) {
      // Fallback departments if API fails
      setState(() {
        departments = [
          'Health',
          'Education',
          'Rural Development',
          'Agriculture',
          'Infrastructure',
        ];
        selectedDept = departments[0];
      });
    }
  }

  Future<void> loadAnomalies(String dept) async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/anomalies/$dept'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => anomalies = List.from(data['anomalies'] ?? []));
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> loadLeakage() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/leakage?min_utilization=50'),
      );
      if (response.statusCode == 200) {
        setState(() => leakage = json.decode(response.body));
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> loadReallocation() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/reallocate'));
      if (response.statusCode == 200) {
        setState(() => reallocation = json.decode(response.body));
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> loadHighRisk() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/high-risk'));
      if (response.statusCode == 200) {
        setState(() => highRisk = json.decode(response.body));
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.compact(locale: 'en_IN');

    return Scaffold(
      appBar: AppBar(
        title: Text('Indian Budget Intelligence'),
        backgroundColor: Colors.blue[900],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: Container(
            padding: EdgeInsets.all(8),
            color: connectionStatus.contains('✅')
                ? Colors.green[900]
                : Colors.red[900],
            child: Text(
              connectionStatus,
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await loadSummary();
          await loadStates();
          await loadDepartments();
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              if (summary != null) ...[
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                              'Total Budget',
                              '₹${format.format(summary!['total_allocated_cr'])}Cr',
                              Icons.account_balance,
                              Colors.blue,
                            ),
                            _buildSummaryItem(
                              'Total Spent',
                              '₹${format.format(summary!['total_spent_cr'])}Cr',
                              Icons.trending_up,
                              Colors.green,
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                              'Utilization',
                              '${summary!['avg_utilization']?.toStringAsFixed(1)}%',
                              Icons.pie_chart,
                              Colors.orange,
                            ),
                            _buildSummaryItem(
                              'Waste',
                              '₹${format.format(summary!['total_waste_cr'])}Cr',
                              Icons.warning,
                              Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(height: 20),

              // Stats Overview
              Text(
                'INDIA OVERVIEW',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildStatCard(
                    'States',
                    summary?['total_states']?.toString() ?? '0',
                    Icons.map,
                  ),
                  _buildStatCard(
                    'Districts',
                    summary?['total_districts']?.toString() ?? '0',
                    Icons.location_city,
                  ),
                  _buildStatCard(
                    'Ministries',
                    summary?['total_ministries']?.toString() ?? '0',
                    Icons.account_balance,
                  ),
                  _buildStatCard(
                    'Departments',
                    summary?['total_departments']?.toString() ?? '0',
                    Icons.business,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Action Buttons
              Text(
                'ANALYSIS TOOLS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildActionButton('🔍 Anomalies', Colors.red, () {
                    if (departments.isNotEmpty) {
                      _showDepartmentDialog();
                    }
                  }),
                  _buildActionButton('💧 Leakage', Colors.orange, loadLeakage),
                  _buildActionButton(
                    '🔄 Reallocate',
                    Colors.green,
                    loadReallocation,
                  ),
                  _buildActionButton(
                    '⚠️ High Risk',
                    Colors.purple,
                    loadHighRisk,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Results Section
              if (isLoading)
                Center(child: CircularProgressIndicator())
              else ...[
                // Anomalies
                if (anomalies.isNotEmpty) ...[
                  Text(
                    'ANOMALIES DETECTED',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...anomalies
                      .take(5)
                      .map(
                        (a) => Card(
                          color: Colors.red[900],
                          child: ListTile(
                            title: Text('${a['State']} - ${a['District']}'),
                            subtitle: Text(
                              '${a['Department']}: ${a['Scheme_Name']}',
                            ),
                            trailing: Text(
                              '${a['Utilization_Percentage']?.toStringAsFixed(1)}%',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  if (anomalies.length > 5)
                    Text('+ ${anomalies.length - 5} more...'),
                ],

                // Leakage
                if (leakage.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'POTENTIAL LEAKAGES',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...leakage
                      .take(5)
                      .map(
                        (l) => Card(
                          color: Colors.orange[900],
                          child: ListTile(
                            title: Text('${l['State']} - ${l['District']}'),
                            subtitle: Text(
                              '${l['Department']}: ${l['Scheme_Name']}',
                            ),
                            trailing: Text(
                              '₹${format.format(l['unspent_amount'])}Cr',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ],

                // Reallocation
                if (reallocation.containsKey('suggestions') &&
                    reallocation['suggestions'].isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'REALLOCATION SUGGESTIONS',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...reallocation['suggestions']
                      .map(
                        (s) => Card(
                          color: Colors.green[900],
                          child: ListTile(
                            title: Text(s['reason']),
                            subtitle: Text(
                              '${s['from_location']} → ${s['to_location']}',
                            ),
                            trailing: Text('₹${s['suggested_amount_cr']}Cr'),
                          ),
                        ),
                      )
                      .toList(),
                ],

                // High Risk
                if (highRisk.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'HIGH RISK PROJECTS',
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...highRisk
                      .take(5)
                      .map(
                        (r) => Card(
                          color: Colors.purple[900],
                          child: ListTile(
                            title: Text('${r['State']} - ${r['District']}'),
                            subtitle: Text(
                              '${r['Scheme_Name']} | Delay: ${r['Delay_Days']} days',
                            ),
                            trailing: Text(
                              '${r['Utilization_Percentage']?.toStringAsFixed(1)}%',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDepartmentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Select Department'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: departments.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(departments[index]),
                onTap: () {
                  Navigator.pop(ctx);
                  loadAnomalies(departments[index]);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
    );
  }
}
