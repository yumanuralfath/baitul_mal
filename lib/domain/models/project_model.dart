class ProjectModel {
  final int? id; //nullable ID automatic create by DB
  final String name;

  ProjectModel({this.id, required this.name});

  // conversion object to map(for set to DB)
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  // conversion from Map to object (for get from DB)
  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(id: map['id'], name: map['name']);
  }
}
