import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/appointment.dart';
import '../theme/app_theme.dart';

class AppointmentCalendarView extends StatelessWidget {
  const AppointmentCalendarView({
    super.key,
    required this.appointments,
    required this.selectedDay,
    required this.focusedDay,
    required this.onDaySelected,
    this.showPatientName = false,
    this.onAdd,
    this.onTapAppointment,
    this.onDeleteAppointment,
    this.emptyMessage = 'Bu gün için görüşme yok.',
  });

  final List<Appointment> appointments;
  final DateTime selectedDay;
  final DateTime focusedDay;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final bool showPatientName;
  final VoidCallback? onAdd;
  final ValueChanged<Appointment>? onTapAppointment;
  final ValueChanged<Appointment>? onDeleteAppointment;
  final String emptyMessage;

  List<Appointment> _forDay(DateTime day) {
    return appointments.where((item) => isSameDay(item.startsAt, day)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  @override
  Widget build(BuildContext context) {
    final dayItems = _forDay(selectedDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: TableCalendar<Appointment>(
            locale: 'tr_TR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            startingDayOfWeek: StartingDayOfWeek.monday,
            eventLoader: _forDay,
            onDaySelected: onDaySelected,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Ay'},
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(selectedDay),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            if (onAdd != null)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Görüşme ekle'),
              ),
          ],
        ),
        if (dayItems.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(emptyMessage, style: const TextStyle(color: AppColors.muted)),
            ),
          )
        else
          ...dayItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AppointmentTile(
                appointment: item,
                showPatientName: showPatientName,
                onTap: onTapAppointment == null ? null : () => onTapAppointment!(item),
                onDelete: onDeleteAppointment == null ? null : () => onDeleteAppointment!(item),
              ),
            ),
          ),
      ],
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.showPatientName,
    this.onTap,
    this.onDelete,
  });

  final Appointment appointment;
  final bool showPatientName;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final time =
        '${DateFormat('HH:mm').format(appointment.startsAt)} – ${DateFormat('HH:mm').format(appointment.endsAt)}';
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: appointment.isPast ? AppColors.chip : AppColors.primary,
          foregroundColor: appointment.isPast ? AppColors.primary : Colors.white,
          child: const Icon(Icons.event_available_outlined),
        ),
        title: Text(appointment.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            time,
            if (showPatientName) appointment.patientName,
            if (appointment.notes?.isNotEmpty == true) appointment.notes!,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: onDelete == null
            ? null
            : IconButton(
                tooltip: 'Sil',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
      ),
    );
  }
}
