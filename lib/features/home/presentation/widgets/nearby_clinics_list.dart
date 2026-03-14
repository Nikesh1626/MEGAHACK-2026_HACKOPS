import 'package:flutter/material.dart';
import '../../data/clinic_repository.dart';
import '../../../../core/model/clinic.dart';
import 'clinic_card.dart';

class NearbyClinicsList extends StatefulWidget {
  const NearbyClinicsList({super.key});

  @override
  _NearbyClinicsListState createState() => _NearbyClinicsListState();
}

class _NearbyClinicsListState extends State<NearbyClinicsList> {
  final ClinicRepository _repository = ClinicRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Clinic>>(
      stream: _repository.streamNearbyClinics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No clinics found.'));
        } else {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final clinic = snapshot.data![index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ClinicCard(clinic: clinic),
              );
            },
          );
        }
      },
    );
  }
}
