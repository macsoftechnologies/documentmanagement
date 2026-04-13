import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document_model.dart';
import '../services/api_service.dart';
import '../widgets/document_card.dart';
import 'login_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<DocumentModel> documents = [];
  List<DocumentModel> filteredDocuments = [];
  bool isLoading = true;
  bool hasError = false;
  String? lastSync;
  int? userId;
  Timer? _syncTimer;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  String _userName = '';
  final TextEditingController _searchController = TextEditingController();

  String _nowIST() {
    return DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();
  }

  void _applyFilter() {
    setState(() {
      filteredDocuments = documents.where((doc) {
        final matchesSearch = _searchQuery.isEmpty ||
            doc.documentName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
        final matchesFilter =
            _selectedFilter == 'all' || doc.status == _selectedFilter;
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    loadDocuments();
    _startAutoSync();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startAutoSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncDocuments();
    });
  }

  // ✅ Check if popup was already shown today
  Future<bool> _shouldShowPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString('popup_last_shown');
    final today = DateTime.now().toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String()
        .substring(0, 10); // YYYY-MM-DD only

    if (lastShown == today) return false;

    await prefs.setString('popup_last_shown', today);
    return true;
  }

  // ✅ Show popup after documents load
  Future<void> _checkAndShowPopup() async {
    if (!mounted) return;

    final shouldShow = await _shouldShowPopup();
    if (!shouldShow) return;

    final expiringSoon = documents
        .where((d) => d.status == 'expiring_soon')
        .toList();
    final expired = documents
        .where((d) => d.status == 'expired')
        .toList();

    if (expiringSoon.isEmpty && expired.isEmpty) return;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DocumentAlertDialog(
        expiringSoon: expiringSoon,
        expired: expired,
      ),
    );
  }

  Future<void> loadDocuments() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('user_id');

      if (userId == null) return;

      final response = await ApiService.getUserDocuments(userId!);

      if (response['success'] == true) {
        final data = response['data'] as List;
        setState(() {
          documents = data.map((e) => DocumentModel.fromJson(e)).toList();
          if (documents.isNotEmpty) {
            _userName = documents.first.userName;
          }
          isLoading = false;
        });
        _applyFilter();
        lastSync = _nowIST();
        print("LOAD DONE — lastSync: $lastSync");

        // ✅ Show popup after load
        await _checkAndShowPopup();
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
    } catch (e) {
      print("LOAD ERROR: $e");
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  Future<void> syncDocuments() async {
    if (userId == null || lastSync == null) {
      await loadDocuments();
      return;
    }

    print("SYNCING — lastSync: $lastSync");

    try {
      final response = await ApiService.syncDocuments(userId!, lastSync!);
      final newSync = _nowIST();

      if (response['success'] == true) {
        final data = response['data'] as List;
        final validIds = (response['valid_ids'] as List)
            .map((e) => int.parse(e.toString()))
            .toList();

        setState(() {
          documents.removeWhere(
            (d) => !validIds.contains(d.userDocumentId),
          );
          for (final updatedDoc
              in data.map((e) => DocumentModel.fromJson(e))) {
            final idx = documents.indexWhere(
              (d) => d.userDocumentId == updatedDoc.userDocumentId,
            );
            if (idx >= 0) {
              documents[idx] = updatedDoc;
            } else {
              documents.add(updatedDoc);
            }
          }
        });

        _applyFilter();
        lastSync = newSync;
        print("SYNC DONE — lastSync advanced to: $lastSync");
      }
    } catch (e) {
      print("SYNC ERROR: $e");
    }
  }

  Future<void> logout() async {
    _syncTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  int _countByStatus(String status) {
    if (status == 'all') return documents.length;
    return documents.where((d) => d.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Documents',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            if (_userName.isNotEmpty)
              Text(
                'Hi, $_userName',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: logout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading documents...',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off,
                    size: 48, color: Colors.red.shade300),
              ),
              const SizedBox(height: 20),
              const Text(
                'Failed to load documents',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your connection and try again',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: loadDocuments,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  _searchQuery = val;
                  _applyFilter();
                },
                decoration: InputDecoration(
                  hintText: 'Search documents...',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.grey.shade400),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = '';
                            _applyFilter();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 12),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'All'),
                    const SizedBox(width: 8),
                    _filterChip('active', 'Active'),
                    const SizedBox(width: 8),
                    _filterChip('expiring_soon', 'Expiring Soon'),
                    const SizedBox(width: 8),
                    _filterChip('expired', 'Expired'),
                  ],
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),

        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${filteredDocuments.length} document${filteredDocuments.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: filteredDocuments.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: syncDocuments,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filteredDocuments.length,
                    itemBuilder: (context, index) {
                      return DocumentCard(
                          document: filteredDocuments[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    final count = _countByStatus(value);

    Color chipColor;
    switch (value) {
      case 'active':
        chipColor = Colors.green;
        break;
      case 'expiring_soon':
        chipColor = Colors.orange;
        break;
      case 'expired':
        chipColor = Colors.red;
        break;
      default:
        chipColor = const Color(0xFF1565C0);
    }

    return GestureDetector(
      onTap: () {
        _selectedFilter = value;
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered =
        _selectedFilter != 'all' || _searchQuery.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFiltered ? Icons.filter_list_off : Icons.folder_open,
              size: 48,
              color: Colors.blue.shade300,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered
                ? 'No matching documents'
                : 'No documents found',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Try a different search or filter'
                : 'Your documents will appear here',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          if (isFiltered) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _searchQuery = '';
                _selectedFilter = 'all';
                _applyFilter();
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}

// ✅ Popup dialog widget
class _DocumentAlertDialog extends StatelessWidget {
  final List<DocumentModel> expiringSoon;
  final List<DocumentModel> expired;

  const _DocumentAlertDialog({
    required this.expiringSoon,
    required this.expired,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.notifications_active,
                      color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Document Alerts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expiring soon section
                    if (expiringSoon.isNotEmpty) ...[
                      _sectionHeader(
                        Icons.warning_amber_rounded,
                        'Expiring Soon',
                        Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      ...expiringSoon.map(
                        (doc) => _alertRow(
                          doc.documentName,
                          'Expires on ${doc.endDate}',
                          Colors.orange,
                        ),
                      ),
                    ],

                    // Spacer between sections
                    if (expiringSoon.isNotEmpty && expired.isNotEmpty)
                      const SizedBox(height: 16),

                    // Expired section
                    if (expired.isNotEmpty) ...[
                      _sectionHeader(
                        Icons.cancel_outlined,
                        'Expired',
                        Colors.red,
                      ),
                      const SizedBox(height: 8),
                      ...expired.map(
                        (doc) => _alertRow(
                          doc.documentName,
                          'Expired on ${doc.endDate}',
                          Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ✅ Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _alertRow(String name, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}