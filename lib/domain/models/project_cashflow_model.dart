class ProjectCashflowModel {
  final int projectId;
  final String projectName;
  final double totalSetoran;
  final double totalPenarikan;
  final double totalDipinjam;
  final double totalKembali;
  final double danaDipinjamAktif;
  final double danadiTangan;
  final double? setoranHariIni;
  final double? pinjamanHariIni;
  final double? pembayaranHariIni;

  const ProjectCashflowModel({
    required this.projectId,
    required this.projectName,
    required this.totalSetoran,
    required this.totalPenarikan,
    required this.totalDipinjam,
    required this.totalKembali,
    required this.danaDipinjamAktif,
    required this.danadiTangan,
    this.setoranHariIni,
    this.pinjamanHariIni,
    this.pembayaranHariIni,
  });

  double get totalDana => totalSetoran - totalPenarikan;

  factory ProjectCashflowModel.fromMap(Map<String, dynamic> map) {
    return ProjectCashflowModel(
      projectId: map['project_id'] as int,
      projectName: map['project_name'] as String,
      totalSetoran: (map['total_setoran'] as num? ?? 0).toDouble(),
      totalPenarikan: (map['total_penarikan'] as num? ?? 0).toDouble(),
      totalDipinjam: (map['total_dipinjam'] as num? ?? 0).toDouble(),
      totalKembali: (map['total_kembali'] as num? ?? 0).toDouble(),
      danaDipinjamAktif: (map['dana_dipinjam_aktif'] as num? ?? 0).toDouble(),
      danadiTangan: (map['dana_di_tangan'] as num? ?? 0).toDouble(),
      setoranHariIni: (map['setoran_hari_ini'] as num?)?.toDouble(),
      pinjamanHariIni: (map['pinjaman_hari_ini'] as num?)?.toDouble(),
      pembayaranHariIni: (map['pembayaran_hari_ini'] as num?)?.toDouble(),
    );
  }
}
