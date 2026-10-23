import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../inti/tema/warna_app.dart';
import '../../../rute/nama_rute.dart';
import '../../provider/provider_auth.dart';
import '../../widget/umum/kepala_warna.dart';

/// Dipakai dua keadaan oleh satu form yang sama.
///
/// [wajib] true: muncul setelah admin memberi password sementara dan tidak
/// bisa dilewati, karena password sementara sempat berpindah lewat pesan
/// singkat atau lisan sehingga tidak boleh dipakai terus-menerus.
///
/// [wajib] false: dibuka sendiri dari Profil, boleh dibatalkan, dan kembali ke
/// halaman sebelumnya setelah tersimpan.
class LayarGantiPassword extends StatefulWidget {
  const LayarGantiPassword({super.key, this.wajib = true});

  final bool wajib;

  @override
  State<LayarGantiPassword> createState() => _LayarGantiPasswordState();
}

class _LayarGantiPasswordState extends State<LayarGantiPassword> {
  final _formKey = GlobalKey<FormState>();
  final _lamaCtrl = TextEditingController();
  final _baruCtrl = TextEditingController();
  final _ulangCtrl = TextEditingController();

  bool _sembunyikan = true;

  @override
  void dispose() {
    _lamaCtrl.dispose();
    _baruCtrl.dispose();
    _ulangCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<ProviderAuth>();
    final berhasil = await auth.gantiPassword(_lamaCtrl.text, _baruCtrl.text);

    if (!mounted) return;

    if (!berhasil) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.pesanError ?? 'Gagal mengganti password'),
          backgroundColor: WarnaApp.error,
        ),
      );
      return;
    }

    if (widget.wajib) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(NamaRute.beranda, (_) => false);
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password berhasil diganti'),
        backgroundColor: WarnaApp.success,
      ),
    );
  }

  Future<void> _keluar() async {
    await context.read<ProviderAuth>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(NamaRute.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final sedangProses = context.watch<ProviderAuth>().sedangProses;

    return PopScope(
      canPop: !widget.wajib,
      child: Scaffold(
        body: Stack(children: [
          SingleChildScrollView(
            child: Column(
              children: [
                KepalaWarna(
                  adaTombolKembali: !widget.wajib,
                  atasJudul:
                      widget.wajib ? 'Langkah terakhir' : 'Keamanan akun',
                  judul: widget.wajib ? 'Buat Password Baru' : 'Ganti Password',
                  aksi: widget.wajib
                      ? [
                          TextButton(
                            onPressed: sedangProses ? null : _keluar,
                            style: TextButton.styleFrom(
                              foregroundColor: WarnaApp.textSecondary,
                            ),
                            child: const Text('Keluar'),
                          ),
                        ]
                      : null,
                  isi: widget.wajib
                      ? const KotakKepala(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 20, color: WarnaApp.primary),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Password dari admin hanya untuk masuk '
                                  'pertama kali. Buat password sendiri supaya '
                                  'akun Anda aman.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: WarnaApp.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _kolom(
                            controller: _lamaCtrl,
                            label: widget.wajib
                                ? 'Password dari Admin'
                                : 'Password Sekarang',
                            sedangProses: sedangProses,
                            validator: (n) => (n == null || n.isEmpty)
                                ? (widget.wajib
                                    ? 'Isi password dari admin'
                                    : 'Isi password sekarang')
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _kolom(
                            controller: _baruCtrl,
                            label: 'Password Baru',
                            sedangProses: sedangProses,
                            validator: (n) {
                              if (n == null || n.isEmpty) {
                                return 'Isi password baru';
                              }
                              if (n.length < 8) return 'Minimal 8 karakter';
                              if (n == _lamaCtrl.text) {
                                return widget.wajib
                                    ? 'Harus berbeda dari password admin'
                                    : 'Harus berbeda dari password sekarang';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _kolom(
                            controller: _ulangCtrl,
                            label: 'Ulangi Password Baru',
                            sedangProses: sedangProses,
                            validator: (n) => n != _baruCtrl.text
                                ? 'Ulangan tidak sama'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Minimal 8 karakter. Pakai yang mudah Anda ingat '
                            'tapi sulit ditebak orang lain.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: WarnaApp.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: sedangProses ? null : _simpan,
                            child: sedangProses
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Simpan Password'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TudungStatus()
        ]),
      ),
    );
  }

  Widget _kolom({
    required TextEditingController controller,
    required String label,
    required bool sedangProses,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !sedangProses,
      obscureText: _sembunyikan,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_sembunyikan ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _sembunyikan = !_sembunyikan),
        ),
      ),
      validator: validator,
    );
  }
}
