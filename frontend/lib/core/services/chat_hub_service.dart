import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../config.dart';

/// Encapsulates the SignalR connection to the backend ChatHub (/hubs/chat).
///
/// Usage:
///   final hub = ChatHubService();
///   await hub.connect();
///   await hub.joinConversation(myId, peerId);
///   hub.onMessage.listen((msg) { ... });
///   await hub.sendMessage(myId, peerId, 'Hello!');
///   hub.dispose();
class ChatHubService {
  static const _defaultUrl = String.fromEnvironment(
    'HUB_URL',
    defaultValue: 'https://ingenieria-de-software-grupo-colegio6-production.up.railway.app/hubs/chat',
  );

  HubConnection? _connection;

  final _messageController =
      StreamController<_IncomingMessage>.broadcast();
  final _typingController = StreamController<String>.broadcast();

  /// Fires whenever a "ReceiveMessage" event arrives from the hub.
  Stream<_IncomingMessage> get onMessage => _messageController.stream;

  /// Fires whenever a "UserTyping" event arrives (yields the sender's ID).
  Stream<String> get onTyping => _typingController.stream;

  bool get isConnected =>
      _connection?.state == HubConnectionState.Connected;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Connect to the hub. Pass a [token] if JWT auth is enabled on the server.
  Future<void> connect({String url = _defaultUrl, String? token}) async {
    // En modo demo no hay servidor: intentar conectar dejaría el cliente
    // reintentando en bucle contra una URL inexistente. Los mensajes se
    // resuelven igual por HTTP contra el backend simulado.
    if (kDemoMode) return;

    final endpoint = token != null ? '$url?access_token=$token' : url;

    _connection = HubConnectionBuilder()
        .withUrl(endpoint)
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
        .build();

    _connection!.on('ReceiveMessage', _onReceiveMessage);
    _connection!.on('UserTyping', _onUserTyping);

    try {
      await _connection!.start();
    } catch (_) {
      // Backend not running — hub features disabled, UI still works offline.
    }
  }

  void dispose() {
    _connection?.stop();
    _messageController.close();
    _typingController.close();
  }

  // ── Server → Client handlers ───────────────────────────────────────────────

  void _onReceiveMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final map = args[0] as Map<String, dynamic>? ?? {};
    _messageController.add(_IncomingMessage(
      senderId: map['senderId'] as String? ?? '',
      content: map['content'] as String? ?? '',
      timestamp: map['timestamp'] as String? ?? '',
    ));
  }

  void _onUserTyping(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final map = args[0] as Map<String, dynamic>? ?? {};
    _typingController.add(map['senderId'] as String? ?? '');
  }

  // ── Client → Server invocations ────────────────────────────────────────────

  Future<void> joinConversation(String myId, String peerId) =>
      _invoke('JoinConversation', [myId, peerId]);

  Future<void> leaveConversation(String myId, String peerId) =>
      _invoke('LeaveConversation', [myId, peerId]);

  Future<void> sendMessage(String senderId, String peerId, String content) =>
      _invoke('SendDirectMessage', [senderId, peerId, content]);

  Future<void> sendTyping(String senderId, String peerId) =>
      _invoke('SendTypingDm', [senderId, peerId]);

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _invoke(String method, List<Object?> args) async {
    if (!isConnected) return;
    try {
      await _connection!.invoke(method, args: args.cast<Object>());
    } catch (_) {
      // Swallow transient errors; reconnect logic handles recovery.
    }
  }
}

/// Data class for messages received from the hub.
class _IncomingMessage {
  const _IncomingMessage({
    required this.senderId,
    required this.content,
    required this.timestamp,
  });

  final String senderId;
  final String content;
  final String timestamp;
}
