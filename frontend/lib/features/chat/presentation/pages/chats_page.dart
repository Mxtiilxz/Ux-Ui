import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/services/chat_hub_service.dart';
import '../../../../core/theme/kairos_palette.dart';
import '../../../../core/widgets/k_card.dart';
import '../../data/models/chat_model.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({
    super.key,
    required this.currentUser,
    this.initialContactId,
  });

  final UserProfile currentUser;

  /// If set, opens directly on this conversation once loaded (used when
  /// arriving from an action elsewhere in the app, e.g. Quick Match "Contactar").
  final String? initialContactId;

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final _inputController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final _api = ApiClient();

  // ── Conversations ──────────────────────────────────────────────────────────
  List<ChatPreview> _conversations = [];
  bool _loadingConversations = true;

  // ── Active thread ──────────────────────────────────────────────────────────
  ChatPreview? _selected;
  bool _loadingThread = false;
  final List<ChatMessage> _thread = [];
  bool _showConversationListOnMobile = true;

  // ── Suggestions (following) ────────────────────────────────────────────────
  int _sidebarTab = 0; // 0 = conversations, 1 = suggestions
  List<Map<String, dynamic>> _suggestions = [];
  bool _loadingSuggestions = false;
  bool _suggestionsLoaded = false;

  // ── SignalR ────────────────────────────────────────────────────────────────
  final _hub = ChatHubService();
  StreamSubscription<dynamic>? _msgSub;
  StreamSubscription<dynamic>? _typingSub;
  bool _isTyping = false;
  Timer? _typingTimer;
  Timer? _statusTimer;
  String? _liveStatus;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadConversations() async {
    setState(() => _loadingConversations = true);
    try {
      final data = await _api.getConversations();
      final conversations = data.cast<Map<String, dynamic>>().map((json) {
        final lastAt = DateTime.tryParse(
          json['lastMessageAt'] as String? ?? '',
        );
        String ts = '';
        if (lastAt != null) {
          final diff = DateTime.now().toUtc().difference(lastAt.toUtc());
          if (diff.inMinutes < 60) {
            ts = 'Hace ${diff.inMinutes} min';
          } else if (diff.inHours < 24) {
            ts = 'Hace ${diff.inHours} h';
          } else {
            ts = 'Hace ${diff.inDays} días';
          }
        }
        final user = UserProfile(
          id: json['otherUserId'].toString(),
          name: json['otherUserName'] as String? ?? 'Usuario',
          role: _mapRole(json['otherUserRole'] as String?),
          title: json['otherUserTitle'] as String? ?? '',
          avatarUrl: json['otherUserAvatarUrl'] as String? ?? '',
          skills: const [],
          bio: '',
          location: '',
          connections: 0,
        );
        return ChatPreview(
          id: json['otherUserId'].toString(),
          user: user,
          lastMessage: json['lastMessage'] as String? ?? '',
          timestamp: ts,
          unread: json['hasUnread'] as bool? ?? false,
        );
      }).toList();

      if (mounted) {
        setState(() => _conversations = conversations);
        if (_selected == null) {
          final target = widget.initialContactId != null
              ? conversations
                    .where((c) => c.id == widget.initialContactId)
                    .firstOrNull
              : null;
          final toSelect =
              target ??
              (widget.initialContactId == null && conversations.isNotEmpty
                  ? conversations.first
                  : null);
          if (toSelect != null) {
            await _selectConversation(toSelect, openOnMobile: target != null);
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _conversations = []);
    } finally {
      if (mounted) setState(() => _loadingConversations = false);
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loadingSuggestions = true);
    try {
      final data = await _api.getFollowing();
      if (mounted) {
        setState(() {
          _suggestions = data.cast<Map<String, dynamic>>();
          _suggestionsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _suggestionsLoaded = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _loadThread(String otherUserId) async {
    final otherId = int.tryParse(otherUserId);
    if (otherId == null) {
      setState(() => _thread.clear());
      return;
    }

    setState(() => _loadingThread = true);
    try {
      final data = await _api.getMessages(otherId);
      final messages = data.cast<Map<String, dynamic>>().map((json) {
        final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
        final ts = createdAt != null
            ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
            : '';
        final senderId = json['senderId'].toString();
        return ChatMessage(
          id: json['id'].toString(),
          text: json['content'] as String? ?? '',
          timestamp: ts,
          isMine: senderId == widget.currentUser.id,
          senderId: senderId,
        );
      }).toList();
      if (mounted) {
        setState(() {
          _thread
            ..clear()
            ..addAll(messages);
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _thread.clear());
    } finally {
      if (mounted) setState(() => _loadingThread = false);
    }
  }

  // ── SignalR hub ────────────────────────────────────────────────────────────

  Future<void> _initHub() async {
    final selected = _selected;
    if (selected == null) return;

    final token = await _api.getToken();
    await _hub.connect(token: token);
    if (!mounted) return;

    await _hub.joinConversation(widget.currentUser.id, selected.user.id);

    _msgSub = _hub.onMessage.listen((msg) {
      if (!mounted) return;
      setState(() {
        _thread.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: msg.content,
            timestamp: msg.timestamp,
            isMine: msg.senderId == widget.currentUser.id,
            senderId: msg.senderId,
          ),
        );
        _liveStatus = 'Nuevo mensaje de ${selected.user.name}: ${msg.content}';
      });
      _clearLiveStatusLater();
      _scrollToBottom();
    });

    _typingSub = _hub.onTyping.listen((senderId) {
      if (!mounted || senderId == widget.currentUser.id) return;
      _typingTimer?.cancel();
      setState(() => _isTyping = true);
      _typingTimer = Timer(
        const Duration(seconds: 3),
        () => setState(() => _isTyping = false),
      );
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _typingSub?.cancel();
    _typingTimer?.cancel();
    _statusTimer?.cancel();
    final selected = _selected;
    if (selected != null) {
      _hub.leaveConversation(widget.currentUser.id, selected.user.id);
    }
    _hub.dispose();
    _inputController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Conversation selection ─────────────────────────────────────────────────

  Future<void> _selectConversation(
    ChatPreview chat, {
    bool openOnMobile = true,
  }) async {
    final current = _selected;
    if (current?.id == chat.id) return;

    if (current != null && _hub.isConnected) {
      await _hub.leaveConversation(widget.currentUser.id, current.user.id);
    }

    setState(() {
      _selected = chat;
      _isTyping = false;
      if (openOnMobile) _showConversationListOnMobile = false;
      _thread.clear();
    });

    await _loadThread(chat.user.id);

    if (!_hub.isConnected) {
      await _initHub();
    } else {
      await _hub.joinConversation(widget.currentUser.id, chat.user.id);
    }
  }

  void _openSuggestion(Map<String, dynamic> suggestion) {
    final userId = suggestion['id'].toString();

    // If a conversation already exists, just select it
    final existing = _conversations.where((c) => c.id == userId).firstOrNull;
    if (existing != null) {
      setState(() => _sidebarTab = 0);
      _selectConversation(existing);
      return;
    }

    // Build a temporary preview and open the chat panel
    final roleStr = suggestion['role'] as String? ?? 'student';
    final user = UserProfile(
      id: userId,
      name: suggestion['fullName'] as String? ?? 'Usuario',
      role: _mapRole(roleStr),
      title: _titleForRole(roleStr),
      avatarUrl: suggestion['avatarUrl'] as String? ?? '',
      skills: const [],
      bio: '',
      location: '',
      connections: 0,
    );
    final preview = ChatPreview(
      id: userId,
      user: user,
      lastMessage: '',
      timestamp: '',
      unread: false,
    );

    setState(() => _sidebarTab = 0);
    _selectConversation(preview);
  }

  void _onSidebarTabChanged(int tab) {
    setState(() => _sidebarTab = tab);
    if (tab == 1 && !_suggestionsLoaded) {
      _loadSuggestions();
    }
  }

  void _backToConversationList() {
    setState(() => _showConversationListOnMobile = true);
  }

  // ── Send message ───────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final selected = _selected;
    if (selected == null) return;

    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();

    final optimistic = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: _timeNow(),
      isMine: true,
      senderId: widget.currentUser.id,
    );
    setState(() => _thread.add(optimistic));
    _setLiveStatus('Mensaje enviado a ${selected.user.name}');
    _scrollToBottom();

    final receiverId = int.tryParse(selected.user.id);
    if (receiverId != null) {
      try {
        await _api.sendMessage(receiverId, text);
        Analytics.sendMessage();
        // Add conversation to list if it was a new chat
        if (!_conversations.any((c) => c.id == selected.id)) {
          setState(() => _conversations.insert(0, selected));
        }
      } catch (_) {}
    }

    if (_hub.isConnected) {
      await _hub.sendMessage(widget.currentUser.id, selected.user.id, text);
    }
  }

  void _onInputChanged(String _) {
    final selected = _selected;
    if (_hub.isConnected && selected != null) {
      _hub.sendTyping(widget.currentUser.id, selected.user.id);
    }
    setState(() {});
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final reduceMotion =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (reduceMotion) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _setLiveStatus(String status) {
    _statusTimer?.cancel();
    if (!mounted) return;
    setState(() => _liveStatus = status);
    _clearLiveStatusLater();
  }

  void _clearLiveStatusLater() {
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _liveStatus = null);
    });
  }

  static UserRole _mapRole(String? role) => switch (role?.toLowerCase()) {
    'staff' => UserRole.staff,
    'company' => UserRole.company,
    'alumni' => UserRole.alumni,
    _ => UserRole.student,
  };

  static String _titleForRole(String role) => switch (role.toLowerCase()) {
    'staff' => 'Staff del Liceo',
    'company' => 'Representante de Empresa',
    'alumni' => 'Egresado / Alumni',
    _ => 'Estudiante',
  };

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 1000;
    final showTopTitle = mobile && _showConversationListOnMobile;
    final pagePadding = mobile
        ? const EdgeInsets.fromLTRB(14, 14, 14, 12)
        : const EdgeInsets.fromLTRB(20, 0, 20, 12);
    final query = _searchController.text.trim().toLowerCase();

    final conversations = _conversations
        .where((chat) {
          if (query.isEmpty) return true;
          return chat.user.name.toLowerCase().contains(query) ||
              chat.lastMessage.toLowerCase().contains(query) ||
              chat.user.title.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return Padding(
      padding: pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_liveStatus != null)
            Semantics(
              liveRegion: true,
              container: true,
              label: _liveStatus!,
              child: ExcludeSemantics(child: Text(_liveStatus!)),
            ),
          if (showTopTitle) ...[
            Semantics(
              header: true,
              container: true,
              label: 'Chats',
              child: Text(
                'Chats',
                style: TextStyle(
                  fontSize: mobile ? 26 : 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: KCard(
              padding: EdgeInsets.zero,
              child: mobile
                  ? (_showConversationListOnMobile
                        ? _sidebar(conversations, compact: true)
                        : _chatPanel(
                            mobile: true,
                            onBack: _backToConversationList,
                          ))
                  : Row(
                      children: [
                        SizedBox(width: 340, child: _sidebar(conversations)),
                        const VerticalDivider(width: 1),
                        Expanded(child: _chatPanel()),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar (conversations + suggestions) ──────────────────────────────────

  Widget _sidebar(List<ChatPreview> conversations, {bool compact = false}) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: compact
              ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
              : const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0x140F766E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(17),
              topRight: Radius.circular(17),
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Buscar chats',
              hintText: 'Buscar chats...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),

        // Tab row
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: KairosPalette.border)),
          ),
          child: Row(
            children: [
              _SidebarTab(
                label: 'Mensajes',
                active: _sidebarTab == 0,
                onTap: () => _onSidebarTabChanged(0),
              ),
              _SidebarTab(
                label: 'Sugerencias',
                active: _sidebarTab == 1,
                onTap: () => _onSidebarTabChanged(1),
              ),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: _sidebarTab == 0
              ? _conversationListContent(conversations, compact: compact)
              : _suggestionsContent(),
        ),
      ],
    );
  }

  Widget _conversationListContent(
    List<ChatPreview> conversations, {
    bool compact = false,
  }) {
    if (_loadingConversations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: KairosPalette.secondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sin conversaciones aún.',
                style: TextStyle(color: KairosPalette.secondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _onSidebarTabChanged(1),
                child: const Text('Ver sugerencias'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final chat = conversations[index];
        final selected = chat.id == _selected?.id;
        final summary = [
          if (chat.unread) 'No leído',
          if (chat.lastMessage.isNotEmpty) chat.lastMessage,
          if (chat.timestamp.isNotEmpty) chat.timestamp,
        ].join('. ');
        return Semantics(
          button: true,
          selected: selected,
          container: true,
          excludeSemantics: true,
          label: 'Conversación con ${chat.user.name}',
          value: summary,
          hint: selected ? 'Conversación seleccionada' : 'Abrir conversación',
          onTap: () => _selectConversation(chat),
          child: InkWell(
            onTap: () => _selectConversation(chat),
            child: Container(
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                  : const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? const Color(0x120F766E) : null,
                border: const Border(
                  bottom: BorderSide(color: KairosPalette.border),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: chat.user.avatarUrl.trim().isNotEmpty
                        ? NetworkImage(chat.user.avatarUrl)
                        : null,
                    child: chat.user.avatarUrl.trim().isEmpty
                        ? const Icon(Icons.person_rounded)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat.user.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              chat.timestamp,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          chat.user.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KairosPalette.secondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KairosPalette.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (chat.unread)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(
                        color: KairosPalette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _suggestionsContent() {
    if (_loadingSuggestions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: KairosPalette.secondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sigue a alguien en tu red\npara iniciar una conversación.',
                style: TextStyle(color: KairosPalette.secondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final s = _suggestions[index];
        final name = s['fullName'] as String? ?? 'Usuario';
        final avatar = s['avatarUrl'] as String? ?? '';
        final roleStr = s['role'] as String? ?? 'student';
        final title = _titleForRole(roleStr);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: KairosPalette.border)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: avatar.trim().isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                child: avatar.trim().isEmpty
                    ? const Icon(Icons.person_rounded)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: KairosPalette.secondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                container: true,
                excludeSemantics: true,
                label: 'Chatear con $name',
                onTap: () => _openSuggestion(s),
                child: OutlinedButton(
                  onPressed: () => _openSuggestion(s),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    minimumSize: const Size(48, 48),
                    side: const BorderSide(color: KairosPalette.primary),
                    foregroundColor: KairosPalette.primary,
                  ),
                  child: const Text('Chatear', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Chat panel ─────────────────────────────────────────────────────────────

  Widget _chatPanel({bool mobile = false, VoidCallback? onBack}) {
    final isMobile = mobile || MediaQuery.sizeOf(context).width < 1000;
    final selected = _selected;

    if (selected == null) {
      return const Center(
        child: Text(
          'Selecciona una conversación\no elige alguien de Sugerencias.',
          style: TextStyle(color: KairosPalette.secondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        // Header
        Semantics(
          header: true,
          container: true,
          explicitChildNodes: true,
          label: 'Conversación con ${selected.user.name}',
          child: Container(
            height: isMobile ? 70 : 76,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0x140F766E),
              border: Border(bottom: BorderSide(color: KairosPalette.border)),
            ),
            child: Row(
              children: [
                if (isMobile && onBack != null)
                  IconButton(
                    tooltip: 'Volver a conversaciones',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Semantics(
                  image: true,
                  label: 'Foto de perfil de ${selected.user.name}',
                  child: CircleAvatar(
                    backgroundImage: selected.user.avatarUrl.trim().isNotEmpty
                        ? NetworkImage(selected.user.avatarUrl)
                        : null,
                    child: selected.user.avatarUrl.trim().isEmpty
                        ? const Icon(Icons.person_rounded)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        selected.user.title,
                        style: const TextStyle(color: KairosPalette.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Messages
        Expanded(
          child: _loadingThread
              ? Semantics(
                  liveRegion: true,
                  label: 'Cargando mensajes',
                  child: Center(child: CircularProgressIndicator()),
                )
              : _thread.isEmpty && !_isTyping
              ? Semantics(
                  container: true,
                  label: 'No hay mensajes. Sé el primero en escribir.',
                  child: Center(
                    child: Text(
                      'Aún no hay mensajes.\n¡Sé el primero en escribir!',
                      style: TextStyle(color: KairosPalette.secondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(14),
                  itemCount: _thread.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isTyping && index == _thread.length) {
                      return Semantics(
                        liveRegion: true,
                        container: true,
                        label: '${selected.user.name} está escribiendo',
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: KairosPalette.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${selected.user.name} está escribiendo',
                                  style: const TextStyle(
                                    color: KairosPalette.secondary,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: KairosPalette.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final msg = _thread[index];
                    return Semantics(
                      container: true,
                      excludeSemantics: true,
                      label:
                          'Mensaje de ${msg.isMine ? 'ti' : selected.user.name} a las ${msg.timestamp}: ${msg.text}',
                      child: Align(
                        alignment: msg.isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: isMobile
                                ? MediaQuery.sizeOf(context).width * 0.72
                                : 480,
                          ),
                          decoration: BoxDecoration(
                            color: msg.isMine
                                ? KairosPalette.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: msg.isMine
                                ? null
                                : Border.all(color: KairosPalette.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: msg.isMine
                                      ? Colors.white
                                      : KairosPalette.foreground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg.timestamp,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: msg.isMine
                                      ? Colors.white
                                      : KairosPalette.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: KairosPalette.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  onSubmitted: (_) => _sendMessage(),
                  onChanged: _onInputChanged,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    hintText: 'Escribe un mensaje...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isMobile)
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: KairosPalette.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _sendMessage,
                  tooltip: 'Enviar mensaje',
                  icon: const Icon(Icons.send_rounded, size: 18),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KairosPalette.accent,
                  ),
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Enviar'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sidebar tab button ─────────────────────────────────────────────────────────

class _SidebarTab extends StatelessWidget {
  const _SidebarTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        container: true,
        excludeSemantics: true,
        label: label,
        hint: active ? 'Pestaña seleccionada' : 'Mostrar pestaña $label',
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? KairosPalette.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? KairosPalette.primary : KairosPalette.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
