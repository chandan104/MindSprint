/// Roster read models. Plain immutable classes — no codegen needed at this
/// size. Parsing is defensive: a malformed row throws FormatException with
/// the offending payload, never a silent null.
class SchoolClass {
  final String id;
  final String name;
  final int? grade;

  const SchoolClass({required this.id, required this.name, this.grade});

  factory SchoolClass.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) {
      throw FormatException('Malformed class row: $json');
    }
    return SchoolClass(id: id, name: name, grade: json['grade'] as int?);
  }
}

class Student {
  final String id;
  final String classId;
  final String fullName;
  final String? rollNumber;

  const Student({
    required this.id,
    required this.classId,
    required this.fullName,
    this.rollNumber,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final classId = json['class_id'];
    final fullName = json['full_name'];
    if (id is! String || classId is! String || fullName is! String) {
      throw FormatException('Malformed student row: $json');
    }
    return Student(
      id: id,
      classId: classId,
      fullName: fullName,
      rollNumber: json['roll_number'] as String?,
    );
  }
}
