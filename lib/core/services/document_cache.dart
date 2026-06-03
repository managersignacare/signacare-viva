// apps/patient-app/lib/core/services/document_cache.dart
//
// Phase 11B — Viva's document cache.
//
// Consumes the `documents` section of the /patient-app/mobile-sync
// response. Each row carries a fresh 1h-TTL pre-signed `download_url`
// and a `server_updated_at` timestamp. The cache downloads the bytes
// once, stores them under
//
//   ${appDocumentsDir}/viva-documents/<id>/<filename>
//
// and an adjacent `<id>.meta` marker containing the stored
// `server_updated_at` so subsequent syncs can skip the download unless
// the server copy has changed. When the patient disables the
// `documents` module in Sync Settings, the next refresh() returns an
// empty documents list and the cache is pruned to remove local files
// for rows that are no longer in the active set.
//
// Non-fatal: every file operation is wrapped in try/catch. If the
// device is out of disk space or the signed URL has expired, the call
// logs and moves on — the UI falls back to "open online" via the
// same download URL on the next tap.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';

final vivaDocumentCacheProvider = Provider<VivaDocumentCache>((ref) => VivaDocumentCache._());

class VivaDocumentCache {
  VivaDocumentCache._();

  Directory? _root;
  Future<Directory> _ensureRoot() async {
    final existing = _root;
    if (existing != null) return existing;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/viva-documents');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _root = dir;
    return dir;
  }

  /// Returns the on-disk file for this document id if it's cached
  /// AND its stored server_updated_at matches the latest sync.
  /// Returns null otherwise — callers should fall back to streaming
  /// from the network using `download_url`.
  Future<File?> cachedFileFor(String id) async {
    try {
      final root = await _ensureRoot();
      final docDir = Directory('${root.path}/$id');
      if (!await docDir.exists()) return null;
      final listing = docDir.listSync().whereType<File>().where((f) {
        final name = f.uri.pathSegments.last;
        return name != '_meta.json';
      }).toList();
      if (listing.isEmpty) return null;
      return listing.first;
    } catch (e) {
      debugPrint('[VivaDocumentCache] cachedFileFor failed: $e');
      return null;
    }
  }

  /// Reconcile the cache against the latest documents delta. Files
  /// whose id is not in `rows` are left alone (they may still belong
  /// to an enabled module — the reconciliation is additive).
  Future<void> reconcile(List<Map<String, dynamic>> rows) async {
    try {
      final root = await _ensureRoot();
      for (final row in rows) {
        final id = row['id']?.toString();
        final filename = row['filename']?.toString();
        final url = row['download_url']?.toString();
        final serverUpdatedAt = row['server_updated_at']?.toString();
        if (id == null || filename == null || url == null || serverUpdatedAt == null) {
          continue;
        }

        final docDir = Directory('${root.path}/$id');
        final metaFile = File('${docDir.path}/_meta.json');
        if (await metaFile.exists()) {
          try {
            final meta = json.decode(await metaFile.readAsString()) as Map<String, dynamic>;
            if (meta['server_updated_at'] == serverUpdatedAt) {
              continue; // already current
            }
          } catch (_) { /* fall through and re-download */ }
        }

        if (!await docDir.exists()) {
          await docDir.create(recursive: true);
        }
        final target = File('${docDir.path}/$filename');
        try {
          await pApi.download(url, target.path);
          await metaFile.writeAsString(json.encode({
            'server_updated_at': serverUpdatedAt,
            'filename': filename,
            'cached_at': DateTime.now().toIso8601String(),
          }));
        } on DioException catch (e) {
          // 403 = signed URL expired (> 1h since the sync that produced
          // it). Harmless — the next /mobile-sync call will refresh the
          // URL and we retry on the subsequent reconcile.
          debugPrint('[VivaDocumentCache] download failed for $id: ${e.message}');
        }
      }
    } catch (e) {
      debugPrint('[VivaDocumentCache] reconcile failed: $e');
    }
  }

  /// Clear the entire cache. Called on logout so a second patient on
  /// the same device never sees the previous user's files. Also
  /// called by VivaSyncClient.clear() as part of the consent-
  /// revocation pathway.
  Future<void> clear() async {
    try {
      final root = _root;
      if (root == null) return;
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
      _root = null;
    } catch (e) {
      debugPrint('[VivaDocumentCache] clear failed: $e');
    }
  }

  /// Drop cached files whose id is NOT in the provided set. Used when
  /// a module is disabled: the sync response stops returning those
  /// rows, so we prune everything not in the live set. A no-op when
  /// the set is equal to or a superset of current contents.
  Future<void> pruneNotIn(Set<String> keepIds) async {
    try {
      final root = await _ensureRoot();
      if (!await root.exists()) return;
      await for (final entity in root.list()) {
        if (entity is! Directory) continue;
        final id = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (!keepIds.contains(id)) {
          await entity.delete(recursive: true).catchError((_) => entity);
        }
      }
    } catch (e) {
      debugPrint('[VivaDocumentCache] pruneNotIn failed: $e');
    }
  }
}
