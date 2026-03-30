import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

class SafeJustAudioPlatform extends JustAudioPlatform {
  SafeJustAudioPlatform(this._delegate);

  final JustAudioPlatform _delegate;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) {
    return _delegate.init(request);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) {
    return _delegate.disposePlayer(request);
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    try {
      return await _delegate.disposeAllPlayers(request);
    } on MissingPluginException {
      // just_audio triggers this call during startup/hot restart without
      // awaiting it, which can surface as an uncaught async error on Windows.
      return DisposeAllPlayersResponse();
    }
  }
}
