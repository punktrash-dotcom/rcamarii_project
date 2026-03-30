import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:nmd/services/safe_just_audio_platform.dart';

void main() {
  test('disposeAllPlayers ignores MissingPluginException', () async {
    final platform = SafeJustAudioPlatform(_ThrowingJustAudioPlatform());

    await expectLater(
      platform.disposeAllPlayers(DisposeAllPlayersRequest()),
      completes,
    );
  });

  test('disposeAllPlayers still delegates successful responses', () async {
    final delegate = _RecordingJustAudioPlatform();
    final platform = SafeJustAudioPlatform(delegate);

    await platform.disposeAllPlayers(DisposeAllPlayersRequest());

    expect(delegate.disposeAllPlayersCalled, isTrue);
  });
}

class _ThrowingJustAudioPlatform extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) {
    throw MissingPluginException('No implementation found');
  }
}

class _RecordingJustAudioPlatform extends JustAudioPlatform {
  bool disposeAllPlayersCalled = false;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    disposeAllPlayersCalled = true;
    return DisposeAllPlayersResponse();
  }
}
