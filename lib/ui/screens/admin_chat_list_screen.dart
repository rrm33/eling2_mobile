import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  final ChatService _chatService = ChatService();
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    
    // Polling setiap 5 detik untuk daftar chat
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchSilently();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final data = await _chatService.getConversations();
    if (mounted) {
      setState(() {
        _conversations = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSilently() async {
    final data = await _chatService.getConversations();
    if (mounted) {
      setState(() {
        _conversations = data;
      });
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Pesan Masuk', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(child: Text('Belum ada obrolan.'))
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final convo = _conversations[index];
                    final latest = convo['latest_message'];
                    final unreadCount = convo['unread_count'] ?? 0;

                    return ListTile(
                      tileColor: Colors.white,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Icon(Icons.storefront, color: AppColors.primary),
                      ),
                      title: Text(
                        convo['name'] ?? 'Cabang',
                        style: GoogleFonts.outfit(fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500),
                      ),
                      subtitle: Text(
                        latest != null ? (latest['message'] ?? '') : 'Belum ada pesan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unreadCount > 0 ? Colors.black87 : Colors.grey,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (latest != null)
                            Text(
                              _formatTime(latest['created_at']),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          const SizedBox(height: 4),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              shopId: convo['id'],
                              shopName: convo['name'],
                            ),
                          ),
                        );
                        _loadConversations(); // Refresh saat kembali
                      },
                    );
                  },
                ),
    );
  }
}
