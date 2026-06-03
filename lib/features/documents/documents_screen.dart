import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';

/// Documents & Pathology — shared by clinicians, with archive feature.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          title: const Text('My Records'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Documents'),
              Tab(text: 'Pathology'),
            ],
          ),
        ),
        body: const TabBarView(children: [_DocumentsTab(), _PathologyTab()]),
      ),
    );
  }
}

class _DocumentsTab extends StatefulWidget {
  const _DocumentsTab();
  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  List<Map<String, dynamic>> _docs = [];
  Set<String> _archived = {};
  bool _loading = true;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _archived = (prefs.getStringList('viva_archived_docs') ?? []).toSet();
    try {
      final pid = await pApi.patientId;
      if (pid != null) {
        // Fetch both standard attachments and Viva shared documents
        final data = await pApi.get('/patient-app/attachments/$pid');
        final list = data is List
            ? data
            : ((data as Map)['attachments'] ?? data['data'] ?? []) as List;
        _docs = list.map((j) => Map<String, dynamic>.from(j as Map)).toList();
        // Also fetch clinician-shared documents via Viva
        try {
          final vivaData = await pApi.get('/patient-app/shared-docs/$pid');
          final vivaDocs = ((vivaData as Map)['documents'] ?? []) as List;
          for (final d in vivaDocs) {
            final m = Map<String, dynamic>.from(d as Map);
            _docs.add({
              'id': m['id'],
              'filename': m['title'],
              'title': m['title'],
              'createdAt': m['createdAt'],
              'docType': m['docType'],
              'url': m['url'],
            });
          }
        } catch (_) {}
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleArchive(String id) async {
    setState(() {
      if (_archived.contains(id)) {
        _archived.remove(id);
      } else {
        _archived.add(id);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('viva_archived_docs', _archived.toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }

    final active = _docs
        .where((d) => !_archived.contains(d['id']?.toString()))
        .toList();
    final archived = _docs
        .where((d) => _archived.contains(d['id']?.toString()))
        .toList();

    if (_docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: kTextLight.withAlpha(100),
            ),
            const SizedBox(height: 12),
            const Text(
              'No documents shared yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kText,
              ),
            ),
            Text(
              'Documents shared by your clinician will appear here',
              style: TextStyle(fontSize: 12, color: kTextLight),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ...active.map(
          (d) => _DocTile(
            doc: d,
            isArchived: false,
            onArchive: () => _toggleArchive(d['id']?.toString() ?? ''),
          ),
        ),

        if (archived.isNotEmpty) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _showArchived = !_showArchived),
            child: Row(
              children: [
                Icon(
                  _showArchived ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: kTextLight,
                ),
                const SizedBox(width: 4),
                Text(
                  'Archived (${archived.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextLight,
                  ),
                ),
              ],
            ),
          ),
          if (_showArchived)
            ...archived.map(
              (d) => _DocTile(
                doc: d,
                isArchived: true,
                onArchive: () => _toggleArchive(d['id']?.toString() ?? ''),
              ),
            ),
        ],
      ],
    );
  }
}

class _DocTile extends StatelessWidget {
  final Map<String, dynamic> doc;
  final bool isArchived;
  final VoidCallback onArchive;
  const _DocTile({
    required this.doc,
    required this.isArchived,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isArchived ? kSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kDivider),
      ),
      child: ListTile(
        leading: Icon(
          Icons.insert_drive_file,
          color: isArchived ? kTextLight : kInfo,
          size: 20,
        ),
        title: Text(
          doc['filename'] ?? doc['title'] ?? 'Document',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isArchived ? kTextLight : kText,
          ),
        ),
        subtitle: Text(
          doc['uploadedAt'] ?? doc['createdAt'] ?? '',
          style: TextStyle(fontSize: 10, color: kTextLight),
        ),
        trailing: IconButton(
          icon: Icon(
            isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
            size: 18,
            color: kTextLight,
          ),
          tooltip: isArchived ? 'Unarchive' : 'Archive',
          onPressed: onArchive,
        ),
      ),
    );
  }
}

class _PathologyTab extends StatelessWidget {
  const _PathologyTab();

  Future<List<Map<String, dynamic>>> _fetch() async {
    try {
      final pid = await pApi.patientId;
      if (pid == null) return [];
      final data = await pApi.get('/patient-app/pathology/$pid');
      final list = data is List
          ? data
          : ((data as Map)['results'] ?? data['data'] ?? []) as List;
      return list.map((j) => Map<String, dynamic>.from(j as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _fetch(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );
        }
        final results = snap.data ?? [];
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 48,
                  color: kTextLight.withAlpha(100),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No pathology results shared',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kText,
                  ),
                ),
                Text(
                  'Results shared by your clinician will appear here',
                  style: TextStyle(fontSize: 12, color: kTextLight),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: results.length,
          itemBuilder: (_, i) {
            final r = results[i];
            final isAbnormal = r['isAbnormal'] == true;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  Icons.science,
                  color: isAbnormal ? kError : kSuccess,
                  size: 22,
                ),
                title: Text(
                  r['testName'] ?? r['name'] ?? 'Test',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${r['result'] ?? ''} ${r['units'] ?? ''}',
                  style: TextStyle(fontSize: 12, color: kTextLight),
                ),
                trailing: isAbnormal
                    ? const Icon(Icons.warning_amber, color: kError, size: 18)
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
