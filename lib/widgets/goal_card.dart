import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GoalCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final bool isSolo;
  final VoidCallback onTap;

  const GoalCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.isSolo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.glassCard, // Исправлено: теперь берется из темы
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSolo ? Icons.person_rounded : Icons.groups_rounded,
                  color: isSolo ? AppColors.primary : AppColors.nectarGold,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.h2, // Исправлено: берется из темы
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                color: AppColors.primary,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(subtitle, style: AppTextStyles.caption),
                Text(
                  "${progress.toInt()}%",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}