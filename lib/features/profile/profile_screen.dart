import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/auth_service.dart';
import '../auth/presentation/auth_screen.dart';
import '../../core/services/auth_storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  Map<String, dynamic>? _userMetadata;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = AuthService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
          _userMetadata = user.userMetadata;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AuthService.signOut();
        await AuthStorageService.clear();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_off_outlined,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Not logged in',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    final firstName = _userMetadata?['first_name'] ?? '';
    final lastName = _userMetadata?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = _currentUser!.email ?? '';
    final phone = _userMetadata?['phone'] ?? '';
    final age = _userMetadata?['age']?.toString() ?? '';
    final createdAt = _currentUser!.createdAt;
    
    // Get initials for avatar
    String getInitials() {
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '${firstName[0]}${lastName[0]}'.toUpperCase();
      } else if (firstName.isNotEmpty) {
        return firstName[0].toUpperCase();
      } else if (email.isNotEmpty) {
        return email[0].toUpperCase();
      }
      return 'U';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.teal.shade400,
                    Colors.teal.shade600,
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    child: Text(
                      getInitials(),
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    fullName.isNotEmpty ? fullName : 'Welcome!',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Personal Information Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Info Cards
                  _buildInfoCard(
                    icon: Icons.person_outline,
                    label: 'Full Name',
                    value: fullName.isNotEmpty ? fullName : 'Not provided',
                  ),
                  const SizedBox(height: 12),
                  
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email,
                  ),
                  const SizedBox(height: 12),
                  
                  if (phone.isNotEmpty) ...[
                    _buildInfoCard(
                      icon: Icons.phone_outlined,
                      label: 'Phone Number',
                      value: '+91 $phone',
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (age.isNotEmpty) ...[
                    _buildInfoCard(
                      icon: Icons.cake_outlined,
                      label: 'Age',
                      value: '$age years',
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  _buildInfoCard(
                    icon: Icons.calendar_today_outlined,
                    label: 'Member Since',
                    value: _formatDate(createdAt),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Account Actions
                  const Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildActionCard(
                    icon: Icons.history,
                    title: 'Queue History',
                    subtitle: 'View your past appointments',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Queue history coming soon!')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildActionCard(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage your notification settings',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notification settings coming soon!')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildActionCard(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy & Security',
                    subtitle: 'Manage your privacy settings',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Privacy settings coming soon!')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildActionCard(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'Get help with WellQueue',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Help center coming soon!')),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.teal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.black87, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
