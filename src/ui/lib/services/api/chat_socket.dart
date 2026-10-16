import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class ChatSocketMessage {
  const ChatSocketMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory ChatSocketMessage.fromJson(Map<String, dynamic> json) {
    return ChatSocketMessage(
      id: json['id'].toString(),
      senderId: json['sender_id'].toString(),
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
}

class ChatSocket {
  ChatSocket({
    required String baseUrl,
    required this.chatUid,
    required Future<String?> Function() accessToken,
    required Future<bool> Function() refresh,
    WebSocketChannel Function(Uri)? connect,
    DateTime Function()? now,
    this.reconnectBefore = const Duration(minutes: 14),
    this.maxBackoff = const Duration(seconds: 30),
    Timer Function(Duration, void Function())? timerFactory,
  })  : _baseUrl = baseUrl,
        _accessToken = accessToken,
        _refresh = refresh,
        _connect = connect ?? WebSocketChannel.connect,
        now = now ?? DateTime.now,
        _timerFactory = timerFactory ?? Timer.new;

  static const _policyViolation = 1008;

  final String _baseUrl;
  final String chatUid;
  final Future<String?> Function() _accessToken;
  final Future<bool> Function() _refresh;
  final WebSocketChannel Function(Uri) _connect;
  final DateTime Function() now;
  final Duration reconnectBefore;
  final Duration maxBackoff;
  final Timer Function(Duration, void Function()) _timerFactory;

  final StreamController<ChatSocketMessage> _controller = StreamController.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _proactiveTimer;
  Timer? _retryTimer;
  int _generation = 0;
  int _attempt = 0;
  bool _disposed = false;
  bool _stopped = false;
  bool _refreshedWithoutFrame = false;

  Stream<ChatSocketMessage> get messages => _controller.stream;

  Future<void> start() async {
    if (_disposed) return;
    _stopped = false;
    await _open();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _proactiveTimer?.cancel();
    _retryTimer?.cancel();
    await _closeCurrent();
    await _controller.close();
  }

  Uri _buildUri(String token) {
    final base = Uri.parse(_baseUrl);
    final scheme = switch (base.scheme) {
      'https' || 'wss' => 'wss',
      _ => 'ws',
    };
    final prefix =
        base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '$prefix/v1/ws/chats/$chatUid',
      queryParameters: {'token': token},
    );
  }

  Future<void> _closeCurrent() async {
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    await subscription?.cancel();
    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (_) {}
    }
  }

  Future<void> _open() async {
    if (_disposed || _stopped) return;
    _proactiveTimer?.cancel();
    _retryTimer?.cancel();
    final generation = ++_generation;
    await _closeCurrent();
    String? token;
    try {
      token = await _accessToken();
    } catch (_) {
      token = null;
    }
    if (_disposed || _stopped || generation != _generation) return;
    if (token == null || token.isEmpty) {
      _scheduleBackoff(generation);
      return;
    }
    WebSocketChannel channel;
    try {
      channel = _connect(_buildUri(token));
    } catch (_) {
      _scheduleBackoff(generation);
      return;
    }
    _channel = channel;
    _subscription = channel.stream.listen(
      (frame) => _onFrame(generation, frame),
      onError: (Object _) => _onDrop(generation),
      onDone: () => _onDrop(generation),
      cancelOnError: true,
    );
    _proactiveTimer = _timerFactory(reconnectBefore, () {
      if (generation != _generation) return;
      _refreshedWithoutFrame = false;
      _attempt = 0;
      unawaited(_open());
    });
  }

  void _onFrame(int generation, dynamic frame) {
    if (generation != _generation || _disposed) return;
    ChatSocketMessage message;
    try {
      final raw = frame is String ? frame : utf8.decode(frame as List<int>);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      message = ChatSocketMessage.fromJson(decoded);
    } catch (_) {
      return;
    }
    _attempt = 0;
    _refreshedWithoutFrame = false;
    _controller.add(message);
  }

  void _onDrop(int generation) {
    if (generation != _generation || _disposed || _stopped) return;
    final closeCode = _channel?.closeCode;
    _generation++;
    _proactiveTimer?.cancel();
    if (closeCode == _policyViolation) {
      unawaited(_recoverSession());
    } else {
      _scheduleBackoff(_generation);
    }
  }

  Future<void> _recoverSession() async {
    final generation = _generation;
    if (_refreshedWithoutFrame) {
      _expire();
      return;
    }
    _refreshedWithoutFrame = true;
    bool refreshed;
    try {
      refreshed = await _refresh();
    } catch (_) {
      refreshed = false;
    }
    if (_disposed || generation != _generation) return;
    if (!refreshed) {
      _expire();
      return;
    }
    await _open();
  }

  void _expire() {
    _stopped = true;
    _proactiveTimer?.cancel();
    _retryTimer?.cancel();
    if (!_controller.isClosed) {
      _controller.addError(StateError('session_expired'));
    }
  }

  void _scheduleBackoff(int generation) {
    if (_disposed || _stopped) return;
    final seconds = 1 << (_attempt > 20 ? 20 : _attempt);
    var delay = Duration(seconds: seconds);
    if (delay > maxBackoff) delay = maxBackoff;
    _attempt++;
    _retryTimer?.cancel();
    _retryTimer = _timerFactory(delay, () {
      if (generation != _generation) return;
      unawaited(_open());
    });
  }
}
