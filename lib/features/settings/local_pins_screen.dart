import 'package:flutter/cupertino.dart';

import '../../core/services.dart';
import '../../ui/ios_list.dart';
import '../../ui/ios_page.dart';
import '../../ui/look.dart';
import '../../widgets/chat_avatar.dart';

/// Device-local pins: no Telegram limit, shown above server pins.
class LocalPinsScreen extends StatelessWidget {
  const LocalPinsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s.settings, s.chats]),
      builder: (context, _) {
        final look = Look.of(context);
        final pins = s.settings.localPins;
        return IosPage(
          title: 'Закреплённые чаты',
          slivers: [
            SliverToBoxAdapter(
              child: IosSection(
                dividerInset: 66,
                footer:
                    'Без лимита Telegram, но только на этом устройстве. Закрепить: свайп по чату влево '
                    'или долгое нажатие.',
                children: [
                  if (pins.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Пока ничего не закреплено', style: TextStyle(color: look.secondaryLabel)),
                    ),
                  for (final id in pins)
                    IosRow(
                      leading: s.chats.chats[id] == null
                          ? const SizedBox(width: 36)
                          : ChatAvatar(chat: s.chats.chats[id]!, store: s.chats, size: 36),
                      title: s.chats.chats[id]?.title ?? 'Чат $id',
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        onPressed: () => s.settings.toggleLocalPin(id),
                        child: const Icon(CupertinoIcons.minus_circle_fill, color: LookData.destructive),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
