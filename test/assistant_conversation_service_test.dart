import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/assistant_conversation_service.dart';
import 'package:my_health/src/model.dart';

void main() {
  test('deleting a chat day also removes its private media copies', () async {
    final directory = await Directory.systemTemp.createTemp('myhealth-chat-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final attachment = File('${directory.path}/voice.m4a');
    final thumbnail = File('${directory.path}/thumbnail.jpg');
    await attachment.writeAsBytes([1, 2, 3]);
    await thumbnail.writeAsBytes([4, 5, 6]);
    final message = AssistantMessage(
      id: 'voice-1',
      createdAt: DateTime(2026, 9, 23).toIso8601String(),
      role: 'user',
      text: 'Голосовое сообщение',
      relatedSection: 'today',
      kind: 'voice',
      attachmentPath: attachment.path,
      thumbnailPath: thumbnail.path,
    );

    await AssistantConversationService().deleteMediaForMessages([message]);

    expect(await attachment.exists(), isFalse);
    expect(await thumbnail.exists(), isFalse);
  });
}
