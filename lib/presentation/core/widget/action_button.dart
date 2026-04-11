import 'package:baitul_mal_plus/data/source/local/database_helper.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:flutter/material.dart';

class ActionButton extends StatefulWidget {
  final VoidCallback onProjectAdded;

  const ActionButton({super.key, required this.onProjectAdded});

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  final TextEditingController _projectController = TextEditingController();

  @override
  void dispose() {
    _projectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        _showAddProject(context, _projectController, widget.onProjectAdded);
      },
      icon: const Icon(Icons.add),
      label: const Text("Tambah Project"),
    );
  }
}

void _showAddProject(
  BuildContext context,
  TextEditingController projectController,
  VoidCallback onProjectAdded,
) async {
  await showModalBottomSheet(
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
                controller: projectController,
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
                  onPressed: () {
                    String newProject = projectController.text;

                    if (newProject.isNotEmpty) {
                      DatabaseHelper().insertProject(
                        ProjectModel(name: newProject),
                      );

                      projectController.clear();
                      onProjectAdded();
                      Navigator.pop(context);
                    }
                  },
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
