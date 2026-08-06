import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Thin UDP socket wrapper for MAVLink transport.
///
/// Usage:
///   final t = MavlinkUdpTransport();
///   await t.bind(14550);           // bind local port (SITL / MAVProxy)
///   t.byteStream.listen(onBytes);  // subscribe before calling bind
///   t.send(frame, InternetAddress('127.0.0.1'), 14550);
///   t.close();
class MavlinkUdpTransport {
  RawDatagramSocket? _socket;
  final _controller = StreamController<Uint8List>.broadcast();

  /// Broadcast stream of raw UDP payload bytes received on the bound socket.
  Stream<Uint8List> get byteStream => _controller.stream;

  /// Whether the socket is currently bound and listening.
  bool get isOpen => _socket != null;

  /// Bind a local UDP port and start listening for datagrams.
  /// Throws if binding fails.
  Future<void> bind(int localPort) async {
    await close();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, localPort);
    _socket!.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          final dg = _socket?.receive();
          if (dg != null && dg.data.isNotEmpty) {
            _controller.add(Uint8List.fromList(dg.data));
            // Cache the remote address so we can reply to it
            _remoteAddress = dg.address;
            _remotePort = dg.port;
          }
        }
      },
      onError: (e) => _controller.addError(e),
      cancelOnError: false,
    );
  }

  // The remote peer that last sent us data (auto-detected from first packet).
  InternetAddress? _remoteAddress;
  int? _remotePort;

  InternetAddress? get remoteAddress => _remoteAddress;
  int? get remotePort => _remotePort;

  /// Set the remote peer manually (when you know host:port up front).
  void setRemote(InternetAddress address, int port) {
    _remoteAddress = address;
    _remotePort = port;
  }

  /// Send raw bytes to [address]:[port].
  /// If address/port are null, sends to the last-seen remote peer.
  void send(Uint8List data, {InternetAddress? address, int? port}) {
    final addr = address ?? _remoteAddress;
    final p = port ?? _remotePort;
    if (_socket == null || addr == null || p == null) return;
    try {
      _socket!.send(data, addr, p);
    } catch (_) {}
  }

  /// Close the socket and release resources.
  Future<void> close() async {
    _socket?.close();
    _socket = null;
    _remoteAddress = null;
    _remotePort = null;
  }

  void dispose() {
    close();
    _controller.close();
  }
}
