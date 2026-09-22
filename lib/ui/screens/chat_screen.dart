import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_colors.dart';
import '../../services/chat_service.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final int? shopId; // Null jika Kasir, Terisi jika Admin yang buka
  final String? shopName; 

  const ChatScreen({super.key, this.shopId, this.shopName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  Timer? _pollingTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    
    // Polling setiap 3 detik
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessagesSilently();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final msgs = await _chatService.getMessages(shopId: widget.shopId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
      _chatService.markAsRead(shopId: widget.shopId);
    }
  }

  Future<void> _fetchMessagesSilently() async {
    final msgs = await _chatService.getMessages(shopId: widget.shopId);
    if (mounted) {
      if (msgs.length > _messages.length) {
        setState(() {
          _messages = msgs;
        });
        _scrollToBottom();
        _chatService.markAsRead(shopId: widget.shopId);
      }
    }
  }

  void _scrollToBottom() {
    // Dengan reverse: true, kita tidak perlu scrollToBottom secara manual
    // tapi fungsi ini dipertahankan kosong jika masih ada pemanggilan
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    
    // Optimistic UI (Langsung tampil sebelum response)
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMsg = {
      'id': tempId,
      'message': text,
      'user': {'role': user?['role'] ?? 'cashier', 'name': user?['name'] ?? 'Saya'},
      'created_at': DateTime.now().toIso8601String(),
      'status': 'sending',
    };
    
    setState(() {
      _messages.add(tempMsg);
    });
    _scrollToBottom();

    final success = await _chatService.sendMessage(text, shopId: widget.shopId);
    if (success) {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index]['status'] = 'sent';
          }
        });
        _fetchMessagesSilently(); // Ambil ID asli dari server
      }
    } else {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index]['status'] = 'failed';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengirim pesan')));
      }
    }
  }

  Future<void> _retrySendMessage(Map<String, dynamic> msg) async {
    final tempId = msg['id'];
    setState(() {
      msg['status'] = 'sending';
    });

    final success = await _chatService.sendMessage(msg['message'], shopId: widget.shopId);
    if (success) {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index]['status'] = 'sent';
          }
        });
        _fetchMessagesSilently();
      }
    } else {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index]['status'] = 'failed';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengirim ulang pesan')));
      }
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
    final currentUserRole = Provider.of<AuthProvider>(context, listen: false).user?['role'];
    final title = currentUserRole == 'admin' ? (widget.shopName ?? 'Chat Cabang') : 'Chat Pusat';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      reverse: true, // Membalikkan list (terbaru di bawah)
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages.reversed.toList()[index];
                        final senderRole = msg['user']?['role'];
                        final isMe = senderRole == currentUserRole;
                        final isFailed = msg['status'] == 'failed';
                        final isSending = msg['status'] == 'sending';
                        
                        Widget bubble = Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                            ]
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['message'] ?? '',
                                style: GoogleFonts.outfit(
                                  color: isMe ? Colors.white : AppColors.text,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(msg['created_at']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe ? Colors.white70 : Colors.grey,
                                    ),
                                  ),
                                  if (isSending) ...[
                                    const SizedBox(width: 4),
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            ],
                          ),
                        );

                        if (isFailed) {
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (isMe) ...[
                                  GestureDetector(
                                    onTap: () => _retrySendMessage(Map<String, dynamic>.from(msg)),
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 8, bottom: 12),
                                      child: Icon(Icons.refresh, color: Colors.red, size: 20),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8, bottom: 12),
                                    child: Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  ),
                                ],
                                bubble,
                                if (!isMe) ...[
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8, bottom: 12),
                                    child: Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: bubble,
                        );
                      },
                    ),
          ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
