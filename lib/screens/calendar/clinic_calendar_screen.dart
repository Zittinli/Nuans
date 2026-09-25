import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import '../../services/clinic_service.dart';
import '../../widgets/appointment_calendar.dart';
import 'appointment_form_screen.dart';

class ClinicCalendarScreen extends StatefulWidget {
  const ClinicCalendarScreen({super.key});

  @override
  State<ClinicCalendarScreen> createState() => _ClinicCalendarScreenState();
}

class _ClinicCalendarScreenState extends State<ClinicCalendarScreen> {
  final _clinic = ClinicService();
  DateTime _selected = DateTime.now();
  DateTime _focused = DateTime.now();

  Future<void> _delete(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Görüşmeyi sil'),
        content: Text('${appointment.patientName} için bu görüşme silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed == true) {
      await _clinic.deleteAppointment(appointment.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Klinik takvimi')),
      body: StreamBuilder<List<Appointment>>(
        stream: _clinic.watchAppointments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Takvim yüklenemedi: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Text(
                'Tüm hastaların görüşmeleri saatleriyle birlikte burada görünür.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 12),
              AppointmentCalendarView(
                appointments: snapshot.data!,
                selectedDay: _selected,
                focusedDay: _focused,
                showPatientName: true,
                emptyMessage: 'Seçilen günde henüz görüşme yok.',
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selected = selected;
                    _focused = focused;
                  });
                },
                onAdd: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppointmentFormScreen(initialDay: _selected),
                    ),
                  );
                },
                onTapAppointment: (appointment) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppointmentFormScreen(appointment: appointment),
                    ),
                  );
                },
                onDeleteAppointment: _delete,
              ),
            ],
          );
        },
      ),
    );
  }
}
