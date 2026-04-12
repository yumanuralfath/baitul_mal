# Baitul Mal Plus — Struktur Project

## Arsitektur

Project ini menggunakan **Clean Architecture** ringan dengan 3 layer utama:

```
lib/
├── core/                          # Konfigurasi global
│   ├── app.dart                   # Root widget (BaitulMalApp)
│   ├── routes/
│   │   └── app_routes.dart        # Semua routing terpusat di sini
│   └── theme/
│       └── theme_controller.dart  # Manajemen light/dark theme
│
├── data/                          # Layer data (implementasi)
│   ├── repositories/
│   │   └── project_repository_impl.dart  # Implementasi SQLite
│   └── source/local/
│       └── database_helper.dart   # Koneksi & skema database
│
├── domain/                        # Layer domain (kontrak/interface)
│   ├── models/
│   │   └── project_model.dart     # Model data
│   └── repositories/
│       └── project_repository.dart  # Abstract interface
│
├── presentation/                  # Layer UI
│   ├── core/widgets/              # Widget yang dipakai banyak screen
│   │   ├── action_button.dart     # FAB tambah project
│   │   ├── add_project_bottom_sheet.dart
│   │   └── appbar.dart
│   └── home/
│       ├── ui/
│       │   └── home_screen.dart   # Screen utama
│       └── widgets/
│           └── project_list_item.dart
│
└── main.dart                      # Entry point
```

---

## Prinsip yang Diterapkan

### 1. Separation of Concerns
Setiap layer punya tanggung jawab yang jelas:
- **`domain`** — Tidak tahu apapun soal database atau UI
- **`data`** — Tahu soal SQLite, tidak tahu soal UI
- **`presentation`** — Tahu soal UI, tidak tahu soal SQLite

### 2. Dependency Inversion
Widget bergantung ke **interface** (`ProjectRepository`), bukan **implementasi** (`ProjectRepositoryImpl`).  
Artinya: kalau suatu hari ganti dari SQLite ke REST API, cukup buat `ProjectRepositoryApiImpl` dan ganti satu baris di `HomeScreen` — tanpa menyentuh UI sama sekali.

### 3. Single Responsibility
- `DatabaseHelper` — hanya koneksi & skema
- `ProjectRepositoryImpl` — hanya query SQL
- `HomeScreen` — hanya tampilkan UI
- `AddProjectBottomSheet` — hanya form tambah project

---

## Cara Menambah Fitur Baru

### Menambah screen baru
1. Buat folder `lib/presentation/nama_fitur/ui/`
2. Buat file screen: `nama_fitur_screen.dart`
3. Daftarkan route di `lib/core/routes/app_routes.dart`

### Menambah field baru ke database
1. Tambahkan field di `ProjectModel`
2. Update `toMap()` dan `fromMap()`
3. Naikkan versi database di `DatabaseHelper._dbVersion`
4. Tambahkan migrasi di `DatabaseHelper._onUpgrade()`

### Menambah operasi data baru
1. Deklarasikan method di `ProjectRepository` (abstract)
2. Implementasikan di `ProjectRepositoryImpl`

### Menambah screen baru dengan argument
```dart
// 1. Buat argument class
class ProjectDetailArgs {
  final ProjectModel project;
  const ProjectDetailArgs({required this.project});
}

// 2. Tambahkan route di app_routes.dart
case AppRoutes.projectDetail:
  final args = settings.arguments as ProjectDetailArgs;
  return MaterialPageRoute(
    builder: (_) => ProjectDetailScreen(project: args.project),
  );

// 3. Navigasi dari screen lain
Navigator.pushNamed(
  context,
  AppRoutes.projectDetail,
  arguments: ProjectDetailArgs(project: project),
);
```

---

## Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0   # Untuk Linux & Windows
  path: ^1.9.0
  shared_preferences: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```
