import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoLauncher {
  static Future<void> open(BuildContext context, String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;

    try {
      final isWebUrl = trimmed.startsWith('http://') ||
          trimmed.startsWith('https://') ||
          trimmed.contains('youtube.com') ||
          trimmed.contains('youtu.be') ||
          trimmed.contains('rutube.ru') ||
          trimmed.contains('vk.com/video');

      if (isWebUrl) {
        String cleanUrl = trimmed;
        if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
          cleanUrl = 'https://$cleanUrl';
        }
        final uri = Uri.parse(cleanUrl);
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } else {
        // Local video file on device (e.g. from file_picker)
        var filePath = trimmed;
        if (filePath.startsWith('file://')) {
          filePath = Uri.parse(filePath).toFilePath();
        }

        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done && context.mounted) {
          final errorMsg = result.message.isNotEmpty
              ? result.message
              : 'Не найдено приложение для воспроизведения видео';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось воспроизвести видео: $errorMsg'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        final shortError = e.toString().split('\n').first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка открытия видео: $shortError'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
