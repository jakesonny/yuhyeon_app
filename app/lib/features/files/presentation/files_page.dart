import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';
import '../../sensors/data/sensor_api.dart';

class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key});

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage> {
  late Future<List<FileListItem>> _filesFuture;
  String _query = '';
  int? _downloadingId;
  int? _deletingId;
  bool _uploading = false;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _filesFuture = _loadFiles(ref);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _filesFuture = _loadFiles(ref);
    });
    await _filesFuture;
  }

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => _toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _toast = null);
    });
  }

  Future<void> _openUpload(String authorName) async {
    final picked = await showDialog<_PickedFile>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _UploadDialog(authorName: authorName),
    );
    if (picked == null) return;
    try {
      setState(() => _uploading = true);
      await ref
          .read(sensorApiProvider)
          .uploadFile(bytes: picked.bytes, filename: picked.name);
      if (!mounted) return;
      _showToast("'${picked.name}' 파일이 등록되었습니다.");
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showToast('업로드 실패: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _confirmDelete(FileListItem file) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _DeleteDialog(name: file.originalName),
    );
    if (ok != true) return;
    try {
      setState(() => _deletingId = file.id);
      await ref.read(sensorApiProvider).deleteFile(file.id);
      if (!mounted) return;
      _showToast("'${file.originalName}' 파일이 삭제되었습니다.");
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showToast('삭제 실패: $e');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Future<void> _download(FileListItem file) async {
    try {
      setState(() => _downloadingId = file.id);
      final downloaded =
          await ref.read(sensorApiProvider).downloadFile(file.id);
      if (kIsWeb) {
        if (!mounted) return;
        _showToast('웹에서는 직접 저장이 지원되지 않습니다.');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/${downloaded.fileName}';
      final f = File(path);
      await f.writeAsBytes(downloaded.bytes, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("'${downloaded.fileName}' 저장 완료"),
          action: SnackBarAction(
            label: '경로 복사',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (!mounted) return;
              _showToast('경로가 복사되었습니다.');
            },
          ),
        ),
      );
      _showToast("'${downloaded.fileName}' 다운로드를 시작합니다.");
    } catch (e) {
      if (!mounted) return;
      _showToast('다운로드 실패: $e');
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    final me = session.username ?? '나';
    final compact = MediaQuery.of(context).size.width < 380;

    return AppShell(
      title: '파일',
      body: Stack(
        children: [
          FutureBuilder<List<FileListItem>>(
            future: _filesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    GeoCard(
                      child: Text(
                        '파일 조회 실패: ${snapshot.error}\n(실서버는 인증 토큰이 필요합니다)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                );
              }
              final files = snapshot.data ?? const <FileListItem>[];
              final filtered = _filterFiles(files, _query);
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  children: [
                    _FilesHeader(
                      total: files.length,
                      uploading: _uploading,
                      onUpload: () => _openUpload(me),
                      compact: compact,
                    ),
                    const SizedBox(height: 8),
                    _SearchBox(
                      value: _query,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      _EmptyState(
                        searchQuery: _query,
                        onUpload: () => _openUpload(me),
                      )
                    else
                      ...filtered.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FileCard(
                            file: f,
                            compact: compact,
                            downloading: _downloadingId == f.id,
                            deleting: _deletingId == f.id,
                            onDownload: () => _download(f),
                            onDelete: () => _confirmDelete(f),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (_toast != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(child: _ToastPill(message: _toast!)),
            ),
        ],
      ),
    );
  }
}

List<FileListItem> _filterFiles(List<FileListItem> files, String q) {
  if (q.trim().isEmpty) return files;
  final s = q.toLowerCase();
  return files
      .where((f) =>
          f.originalName.toLowerCase().contains(s) ||
          f.uploadedByName.toLowerCase().contains(s))
      .toList();
}

Future<List<FileListItem>> _loadFiles(WidgetRef ref) async {
  if (AppConfig.demoMode) {
    return DemoMockData.files
        .asMap()
        .entries
        .map((e) => FileListItem(
              id: e.key + 1,
              originalName: e.value.name,
              fileSize: _mockSizeToBytes(e.value.size),
              uploadedByName: e.value.uploadedBy,
              createdAt: null,
            ))
        .toList();
  }
  return ref.read(sensorApiProvider).fetchFiles();
}

int _mockSizeToBytes(String size) {
  final s = size.trim().toUpperCase();
  if (s.endsWith('MB')) {
    final n = double.tryParse(s.replaceAll('MB', '').trim()) ?? 0;
    return (n * 1024 * 1024).round();
  }
  if (s.endsWith('KB')) {
    final n = double.tryParse(s.replaceAll('KB', '').trim()) ?? 0;
    return (n * 1024).round();
  }
  return 0;
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes >= 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}.${two(l.month)}.${two(l.day)}';
}

String _fileEmoji(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  if (ext == 'pdf') return '📄';
  if (['zip', 'rar', '7z'].contains(ext)) return '🗜';
  if (['pptx', 'ppt'].contains(ext)) return '📊';
  if (['dwg', 'dxf'].contains(ext)) return '📐';
  if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) return '🖼';
  if (['xlsx', 'xls', 'csv'].contains(ext)) return '📈';
  if (['doc', 'docx', 'hwp', 'txt'].contains(ext)) return '📝';
  return '📎';
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _FilesHeader extends StatelessWidget {
  const _FilesHeader({
    required this.total,
    required this.uploading,
    required this.onUpload,
    required this.compact,
  });
  final int total;
  final bool uploading;
  final VoidCallback onUpload;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '파일 관리',
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '총 $total개 파일',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: uploading ? null : onUpload,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(uploading ? '업로드 중...' : '+ 파일 등록'),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 12, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: InputBorder.none,
          hintText: '파일명 또는 작성자 검색...',
          hintStyle:
              const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          prefixIcon: const Icon(Icons.search,
              size: 16, color: AppColors.inkMuted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
          suffixIcon: _ctrl.text.isEmpty
              ? null
              : IconButton(
                  splashRadius: 16,
                  iconSize: 14,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _ctrl.clear();
                    widget.onChanged('');
                  },
                  icon: const Icon(Icons.close,
                      color: AppColors.inkMuted),
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searchQuery, required this.onUpload});
  final String searchQuery;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final hasQuery = searchQuery.trim().isNotEmpty;
    return GeoCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        children: [
          Text(
            hasQuery
                ? "'$searchQuery' 검색 결과가 없습니다."
                : '등록된 파일이 없습니다.',
            style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onUpload,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('+ 첫 번째 파일 등록하기'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File card
// ─────────────────────────────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.file,
    required this.compact,
    required this.downloading,
    required this.deleting,
    required this.onDownload,
    required this.onDelete,
  });
  final FileListItem file;
  final bool compact;
  final bool downloading;
  final bool deleting;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GeoCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              _fileEmoji(file.originalName),
              style: TextStyle(fontSize: compact ? 18 : 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.originalName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    _MetaChip(
                      icon: Icons.person_outline,
                      text: file.uploadedByName.isEmpty
                          ? '—'
                          : file.uploadedByName,
                    ),
                    _MetaChip(
                      icon: Icons.sd_storage_outlined,
                      text: _formatBytes(file.fileSize),
                    ),
                    _MetaChip(
                      icon: Icons.calendar_today_outlined,
                      text: _formatDate(file.createdAt),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: downloading ? null : onDownload,
                      icon: Icon(
                        downloading
                            ? Icons.hourglass_bottom
                            : Icons.download_rounded,
                        size: 16,
                        color: AppColors.brand,
                      ),
                      label: Text(
                        downloading ? '다운로드 중' : '다운로드',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.brand,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: deleting ? null : onDelete,
                      icon: Icon(
                        deleting
                            ? Icons.hourglass_bottom
                            : Icons.delete_outline,
                        size: 16,
                        color: AppColors.dangerText,
                      ),
                      label: Text(
                        deleting ? '삭제 중' : '삭제',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.dangerText,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.inkMuted),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload dialog
// ─────────────────────────────────────────────────────────────────────────────

class _PickedFile {
  _PickedFile({required this.name, required this.bytes, required this.size});
  final String name;
  final List<int> bytes;
  final int size;
}

class _UploadDialog extends StatefulWidget {
  const _UploadDialog({required this.authorName});
  final String authorName;

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  _PickedFile? _picked;
  bool _picking = false;

  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final bytes = f.bytes;
      if (bytes == null || f.name.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일을 읽을 수 없습니다.')),
        );
        return;
      }
      setState(() => _picked = _PickedFile(
            name: f.name,
            bytes: bytes,
            size: f.size,
          ));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '파일 등록',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    splashRadius: 16,
                    iconSize: 18,
                    color: AppColors.inkMuted,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '파일 첨부',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _picking ? null : _pick,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 28, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          width: 2,
                          color: picked == null
                              ? AppColors.line
                              : AppColors.normalBorder,
                        ),
                        color: picked == null
                            ? AppColors.surfaceSubtle
                            : AppColors.normalBg,
                      ),
                      child: picked == null
                          ? Column(
                              children: [
                                const Text('📁',
                                    style: TextStyle(fontSize: 28)),
                                const SizedBox(height: 6),
                                Text(
                                  _picking
                                      ? '파일 선택 중...'
                                      : '클릭하여 파일을 선택하세요',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '모든 파일 형식 지원',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Text(
                                  _fileEmoji(picked.name),
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  picked.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatBytes(picked.size),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: _pick,
                                  style: TextButton.styleFrom(
                                    minimumSize:
                                        const Size(0, 24),
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8),
                                    foregroundColor:
                                        AppColors.dangerText,
                                  ),
                                  child: const Text(
                                    '파일 변경',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '작성자',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '로그인한 계정 기준 자동 설정',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          widget.authorName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        side: const BorderSide(
                            color: AppColors.line),
                        foregroundColor: AppColors.inkSub,
                      ),
                      child: const Text('취소',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: picked == null
                          ? null
                          : () => Navigator.of(context).pop(picked),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('등록'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete confirmation dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.dangerBg,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '⚠',
                  style: TextStyle(fontSize: 22, color: AppColors.danger),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '파일을 삭제하시겠습니까?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '삭제된 파일은 복구할 수 없습니다.',
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        side: const BorderSide(color: AppColors.line),
                        foregroundColor: AppColors.inkSub,
                      ),
                      child: const Text('취소',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('삭제'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastPill extends StatelessWidget {
  const _ToastPill({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33212233),
              blurRadius: 14,
              offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
