import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        _showAddProject(context);
      },
      icon: const Icon(Icons.add),
      label: const Text("Tambah Project"),
    );
  }
}

void _showAddProject(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        //for content save at small screen
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tambah Project Baru",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Nama Project",
                  hintText: "Contoh: Tabungan Tahun 2026",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, // fill button width modal size
                height: 50,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text("Simpan Project"),
                ),
              ),
              const SizedBox(height: 10), //add aditional at bottom
            ],
          ),
        ),
      ),
    ),
    isScrollControlled: true,
  ); // for keyboard not overlap with input
}
