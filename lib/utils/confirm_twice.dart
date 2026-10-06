import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<bool> confirmTwice({
  required BuildContext context,
  required String title,
  required String firstBody,
  String secondTitle = 'Emin misiniz?',
  required String secondBody,
  String confirmLabel = 'Sil',
  String finalLabel = 'Evet, sil',
}) async {
  final first = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(firstBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (first != true || !context.mounted) return false;
  final second = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(secondTitle),
      content: Text(secondBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: Text(finalLabel),
        ),
      ],
    ),
  );
  return second == true;
}
