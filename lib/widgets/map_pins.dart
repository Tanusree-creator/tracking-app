import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import '../l10n/l10n.dart';

/// Map pointer with a white outline and shadow, so it stays clear on both the light and the dark map.
class MapPin extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String? text;
  final double size;
  const MapPin({super.key, required this.color, this.icon, this.text, this.size = 44});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.topCenter, children: [
          Icon(Icons.location_on, size: size, color: Colors.white, shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))]),
          Icon(Icons.location_on, size: size - 8, color: color),
          Positioned(
            top: size * .2,
            child: text != null
                ? Text(text!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .3))
                : Icon(icon ?? Icons.circle, size: size * .34, color: Colors.white),
          ),
        ]),
      );
}

/// A person on the map: photo (or initials) in a white ring with a status dot.
class PersonPin extends StatelessWidget {
  final String initials;
  final Uint8List? photo;
  final Color color;
  final double size;
  const PersonPin({super.key, required this.initials, this.photo, required this.color, this.size = 46});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .7), blurRadius: 14, spreadRadius: 2), const BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
          image: photo == null ? null : DecorationImage(image: MemoryImage(photo!), fit: BoxFit.cover),
        ),
        child: photo != null ? null : Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
      );
}

/// The place the employee is heading to: its own colour so it never looks like a task status.
const kDestinationColor = Color(0xFF8E4DFF);

(Color, IconData) visitPinStyle(VisitStatus s) => switch (s) {
      VisitStatus.pending => (AppColors.red, Icons.flag_rounded),
      VisitStatus.inProgress => (AppColors.accent, Icons.directions_walk),
      VisitStatus.completed => (AppColors.green, Icons.check_rounded),
    };

/// Task locations as numbered pins. Tapping one shows the task.
List<Marker> visitMarkers(BuildContext context, List<Visit> visits, {String? who}) => [
      for (final v in visits.where((v) => v.lat != null && v.lng != null))
        Marker(
          point: LatLng(v.lat!, v.lng!),
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => showVisitPinSheet(context, v, who: who),
            child: MapPin(color: visitPinStyle(v.status).$1, icon: visitPinStyle(v.status).$2),
          ),
        ),
    ];

void showVisitPinSheet(BuildContext context, Visit v, {String? who}) {
  final (color, icon) = visitPinStyle(v.status);
  final label = switch (v.status) {
    VisitStatus.pending => 'To do',
    VisitStatus.inProgress => 'In progress',
    VisitStatus.completed => 'Completed',
  };
  showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Text(v.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          StatusChip(label, color),
        ]),
        const SizedBox(height: 12),
        if (who != null) Text(trf('Assigned to {}', [who]), style: const TextStyle(fontWeight: FontWeight.w600)),
        if (v.location.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(v.location, style: const TextStyle(color: AppColors.muted))),
        const SizedBox(height: 4),
        Text(trf('Scheduled {}', [DateFormat('EEE d MMM, h:mm a').format(v.scheduledTime)]), style: const TextStyle(color: AppColors.muted)),
      ]),
    ),
  );
}

/// Legend chips for the pins above.
class PinLegend extends StatelessWidget {
  const PinLegend({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(spacing: Sp.l, runSpacing: 4, children: [
        StatusChip('Task to do', AppColors.red),
        StatusChip('In progress', AppColors.accent),
        StatusChip('Done', AppColors.green),
      ]);
}
