import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(IndiaBudgetApp());

class IndiaBudgetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hisab Kitab - Budget Intelligence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: AuthGate(),
    );
  }
}

// ============ AUTH GATE - Decides Login vs Home ============
class AuthGate extends StatefulWidget {
  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    setState(() {
      _token = token;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_token != null && _token!.isNotEmpty) {
      return HomeScreen();
    }
    return LoginScreen();
  }
}

// ============ LOGIN SCREEN ============
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final String baseUrl = 'http://192.168.22.222:8000';
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter username and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body:
                'username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}',
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'] as String;

        // Fetch user info with token
        final userResponse = await http.get(
          Uri.parse('$baseUrl/users/me'),
          headers: {'Authorization': 'Bearer $token'},
        );

        String role = 'public';
        String fullName = username;
        String? department;

        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          role = userData['role'] ?? 'public';
          fullName = userData['full_name'] ?? username;
          department = userData['department'];
        }

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('username', username);
        await prefs.setString('role', role);
        await prefs.setString('full_name', fullName);
        if (department != null) {
          await prefs.setString('department', department);
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } else if (response.statusCode == 401) {
        setState(() => _error = 'Invalid username or password');
      } else {
        setState(() => _error = 'Server error (${response.statusCode})');
      }
    } catch (e) {
      setState(
        () => _error =
            'Cannot connect to server.\nCheck if backend is running at $baseUrl',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance, size: 80, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Hisab Kitab',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Text(
                'Indian Budget Intelligence',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              SizedBox(height: 40),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Login', style: TextStyle(fontSize: 16)),
                ),
              ),
              if (_error != null) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[200], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[200]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 32),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[900]?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[800]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demo Accounts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[200],
                      ),
                    ),
                    SizedBox(height: 8),
                    _demoAccount(
                      'admin',
                      'Full access',
                      Icons.admin_panel_settings,
                    ),
                    _demoAccount(
                      'health_dept',
                      'Health dept only',
                      Icons.local_hospital,
                    ),
                    _demoAccount(
                      'education_dept',
                      'Education dept only',
                      Icons.school,
                    ),
                    _demoAccount('public_user', 'Read-only', Icons.people),
                    SizedBox(height: 4),
                    Text(
                      'Password: admin123',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _demoAccount(String username, String desc, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          _usernameController.text = username;
          _passwordController.text = 'admin123';
        },
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.blue[300]),
            SizedBox(width: 8),
            Text(
              username,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            SizedBox(width: 6),
            Text('- $desc', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// ============ HOME SCREEN (with auth) ============
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String baseUrl = 'http://192.168.22.222:8000';

  String? authToken;
  String username = '';
  String userRole = 'public';
  String fullName = '';
  String? department;

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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('auth_token');
      username = prefs.getString('username') ?? '';
      userRole = prefs.getString('role') ?? 'public';
      fullName = prefs.getString('full_name') ?? '';
      department = prefs.getString('department');
    });
    checkConnection();
    loadSummary();
    loadStates();
    loadDepartments();
  }

  Map<String, String> get authHeaders => {
    'Authorization': 'Bearer $authToken',
    'Content-Type': 'application/json',
  };

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  Future<void> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/states'))
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          connectionStatus = '✅ Connected as $fullName ($userRole)';
        });
      } else {
        setState(() => connectionStatus = '❌ Server error');
      }
    } catch (e) {
      setState(() {
        connectionStatus = '⚠️ Cannot reach server';
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
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => anomalies = List.from(data['anomalies'] ?? []));
      } else if (response.statusCode == 401) {
        _showAuthError('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        _showAuthError('You do not have access to $dept department data.');
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> loadLeakage() async {
    if (userRole != 'admin') {
      _showAuthError('Only admin users can view leakage data.');
      return;
    }
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/leakage?min_utilization=50'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        setState(() => leakage = json.decode(response.body));
      } else if (response.statusCode == 401) {
        _showAuthError('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        _showAuthError('Admin access required for leakage data.');
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> loadReallocation() async {
    if (userRole != 'admin') {
      _showAuthError('Only admin users can view reallocation suggestions.');
      return;
    }
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/reallocate'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        setState(() => reallocation = json.decode(response.body));
      } else if (response.statusCode == 401) {
        _showAuthError('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        _showAuthError('Admin access required.');
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> loadHighRisk() async {
    if (userRole != 'admin') {
      _showAuthError('Only admin users can view high-risk projects.');
      return;
    }
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/high-risk'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        setState(() => highRisk = json.decode(response.body));
      } else if (response.statusCode == 401) {
        _showAuthError('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        _showAuthError('Admin access required.');
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => isLoading = false);
  }

  void _showAuthError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        action: message.contains('expired')
            ? SnackBarAction(
                label: 'LOGIN',
                textColor: Colors.white,
                onPressed: _logout,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.compact(locale: 'en_IN');

    return Scaffold(
      appBar: AppBar(
        title: Text('Hisab Kitab'),
        backgroundColor: Colors.blue[900],
        elevation: 0,
        actions: [
          PopupMenuButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: _roleColor(userRole),
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            itemBuilder: (context) => <PopupMenuEntry>[
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '@$username',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _roleColor(userRole),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        userRole.toUpperCase(),
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                    if (department != null) ...[
                      SizedBox(height: 4),
                      Text('Dept: $department', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
                onTap: _logout,
              ),
            ],
          ),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(30),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: connectionStatus.contains('✅')
                ? Colors.green[900]
                : Colors.red[900],
            child: Text(
              connectionStatus,
              style: TextStyle(fontSize: 11),
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

              Text(
                'ANALYSIS TOOLS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                _roleAccessHint(),
                style: TextStyle(fontSize: 11, color: Colors.grey),
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
                  _buildActionButton(
                    '💧 Leakage',
                    userRole == 'admin' ? Colors.orange : Colors.grey,
                    loadLeakage,
                  ),
                  _buildActionButton(
                    '🔄 Reallocate',
                    userRole == 'admin' ? Colors.green : Colors.grey,
                    loadReallocation,
                  ),
                  _buildActionButton(
                    '⚠️ High Risk',
                    userRole == 'admin' ? Colors.purple : Colors.grey,
                    loadHighRisk,
                  ),
                ],
              ),

              SizedBox(height: 20),

              if (isLoading)
                Center(child: CircularProgressIndicator())
              else ...[
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
                      ),
                  if (anomalies.length > 5)
                    Text('+ ${anomalies.length - 5} more...'),
                ],

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
                      ),
                ],

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
                      ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _roleAccessHint() {
    switch (userRole) {
      case 'admin':
        return 'Admin: Full access to all tools';
      case 'department':
        return 'Dept officer: Anomalies for $department only';
      default:
        return 'Public: Read-only access to overview data';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'department':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showDepartmentDialog() {
    if (userRole == 'department' && department != null) {
      loadAnomalies(department!);
      return;
    }
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
