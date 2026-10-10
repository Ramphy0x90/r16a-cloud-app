import 'package:flutter/material.dart';

import '../../../core/util/file_size.dart';
import '../domain/dashboard_metrics.dart';
import 'widgets/metric_card.dart';

// Accent colours ported 1:1 from `pages/dashboard/dashboard.ts`.
const _usedStorageAccent = Color(0xFFE23636);
const _filesUploadedAccent = Color(0xFFF59E0B);
const _photosAccent = Color(0xFF10B981);
const _sharedAccent = Color(0xFF8B5CF6);

String _usedStorage(DashboardMetrics m) => formatFileSize(m.usedStorageBytes);
String _filesUploaded(DashboardMetrics m) => m.uploadedFiles.toString();
String _photosAndVideos(DashboardMetrics m) => m.uploadedPhotos.toString();
String _sharedFiles(DashboardMetrics m) => m.sharedFiles.toString();

const dashboardMetricSpecs = <MetricCardSpec>[
  MetricCardSpec(
    icon: 'assets/icons/device-sd-card.svg',
    accent: _usedStorageAccent,
    title: 'Used storage',
    valueBuilder: _usedStorage,
  ),
  MetricCardSpec(
    icon: 'assets/icons/cloud-upload.svg',
    accent: _filesUploadedAccent,
    title: 'Files uploaded',
    valueBuilder: _filesUploaded,
  ),
  MetricCardSpec(
    icon: 'assets/icons/photo-video.svg',
    accent: _photosAccent,
    title: 'Photos & videos',
    valueBuilder: _photosAndVideos,
  ),
  MetricCardSpec(
    icon: 'assets/icons/share-2.svg',
    accent: _sharedAccent,
    title: 'Shared files',
    valueBuilder: _sharedFiles,
  ),
];
