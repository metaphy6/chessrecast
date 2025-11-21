import 'package:flutter/material.dart';
// Shared UI widgets used across many screens

/// Reusable section card used across settings screens
class SectionCard extends StatelessWidget {
  final Widget titleRow;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.titleRow,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withAlpha((0.9 * 255).round()),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [titleRow, const SizedBox(height: 12), child],
        ),
      ),
    );
  }
}

/// Difficulty readout and color helpers used in multiple places
class DifficultyBadge extends StatelessWidget {
  final int difficulty;

  const DifficultyBadge({super.key, required this.difficulty});

  Color _getDifficultyColor() {
    if (difficulty <= 3) {
      return Colors.green;
    } else if (difficulty <= 6) {
      return Colors.orange;
    }
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: _getDifficultyColor(),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _getDifficultyColor().withAlpha((0.3 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '$difficulty',
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class DifficultyLabel extends StatelessWidget {
  final int difficulty;

  const DifficultyLabel({super.key, required this.difficulty});

  String _getDifficultyLabel() {
    if (difficulty <= 2) return 'Beginner';
    if (difficulty <= 4) return 'Easy';
    if (difficulty <= 6) return 'Intermediate';
    if (difficulty <= 8) return 'Advanced';
    return 'Master';
  }

  Color _getDifficultyColor() {
    if (difficulty <= 3) return Colors.green;
    if (difficulty <= 6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _getDifficultyLabel(),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _getDifficultyColor(),
      ),
    );
  }
}

class DifficultySelector extends StatelessWidget {
  final int difficulty;
  final ValueChanged<double> onChanged;
  final int min;
  final int max;

  const DifficultySelector({
    super.key,
    required this.difficulty,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
  });

  Color _getDifficultyColor() {
    if (difficulty <= 3) return Colors.green;
    if (difficulty <= 6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [DifficultyBadge(difficulty: difficulty)],
        ),
        const SizedBox(height: 8),
        Center(child: DifficultyLabel(difficulty: difficulty)),
        const SizedBox(height: 24),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _getDifficultyColor(),
            inactiveTrackColor: Colors.grey[300],
            thumbColor: _getDifficultyColor(),
            overlayColor: _getDifficultyColor().withAlpha((0.2 * 255).round()),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(
            value: difficulty.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: difficulty.toString(),
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Beginner',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Master',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }
}
