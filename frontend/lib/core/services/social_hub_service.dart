import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';

import '../config.dart';

typedef VoidCallback = void Function();

class SocialHubService {
  static const _hubUrl = 'http://localhost:5001/hubs/social';

  late final HubConnection _connection;

  // Stream controllers so UI can listen reactively
  final _likeController = StreamController<Map<String, dynamic>>.broadcast();
  final _followController = StreamController<Map<String, dynamic>>.broadcast();
  final _commentController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onLike => _likeController.stream;
  Stream<Map<String, dynamic>> get onFollow => _followController.stream;
  Stream<Map<String, dynamic>> get onComment => _commentController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;

  SocialHubService(String jwtToken) {
    _connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => jwtToken,
          ),
        )
        .withAutomaticReconnect(retryDelays: [
          2000, 5000, 10000, 30000 // exponential-like retry policy (ms)
        ])
        .build();

    _registerHandlers();
  }

  void _registerHandlers() {
    _connection.on('ReceiveLike', (args) {
      if (args == null) return;
      _likeController.add(args.first as Map<String, dynamic>);
    });

    _connection.on('ReceiveFollow', (args) {
      if (args == null) return;
      _followController.add(args.first as Map<String, dynamic>);
    });

    _connection.on('ReceiveComment', (args) {
      if (args == null) return;
      _commentController.add(args.first as Map<String, dynamic>);
    });

    _connection.on('UserTyping', (args) {
      if (args == null) return;
      _typingController.add(args.first as Map<String, dynamic>);
    });
  }

  Future<void> connect() async {
    // En modo demo no hay servidor de tiempo real; ver ChatHubService.connect.
    if (kDemoMode) return;
    if (_connection.state == HubConnectionState.Connected) return;
    await _connection.start();
  }

  Future<void> disconnect() async {
    await _connection.stop();
  }

  Future<void> joinPostComments(int postId) async {
    await _connection.invoke('JoinPostComments', args: [postId]);
  }

  Future<void> leavePostComments(int postId) async {
    await _connection.invoke('LeavePostComments', args: [postId]);
  }

  Future<void> sendComment(int postId, String content) async {
    await _connection.invoke('SendComment', args: [postId, content]);
  }

  Future<void> sendTyping(int postId) async {
    await _connection.invoke('SendTyping', args: [postId]);
  }

  void dispose() {
    _connection.stop();
    _likeController.close();
    _followController.close();
    _commentController.close();
    _typingController.close();
  }
}
