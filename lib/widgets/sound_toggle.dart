import 'package:flutter/material.dart';

import '../services/sound_service.dart';

/// Klein speaker-icoon dat geluid aan/uit zet (gedeeld door de schermen).
class SoundToggle extends StatelessWidget {
  const SoundToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SoundService.instance.enabled,
      builder: (context, enabled, _) => IconButton(
        tooltip: enabled ? 'Geluid uitzetten' : 'Geluid aanzetten',
        icon: Icon(enabled ? Icons.volume_up : Icons.volume_off),
        onPressed: () => SoundService.instance.enabled.value = !enabled,
      ),
    );
  }
}
