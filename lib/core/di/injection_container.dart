/// Dependency Injection Container
/// Sets up GetIt for service locator pattern
library;

import 'package:get_it/get_it.dart';
import '../../data/services/image_picker_service.dart';
import '../../data/services/image_processor_service.dart';
import '../../data/services/pdf_generator_service.dart';
import '../../data/services/pdf_merge_service.dart';
import '../../data/services/size_optimizer_service.dart';
import '../../data/services/image_conversion_service.dart';
import '../../data/services/file_export_service.dart';
import '../../data/services/heic_converter_service.dart';
import '../../data/services/conversion_history_service.dart';
import '../../data/services/firestore_sync_service.dart';
import '../../services/ads_service.dart';
import '../../services/auth_service.dart';
import '../../data/services/usage_stats_service.dart';
import '../../data/services/walkthrough_service.dart';
import '../../data/services/support_service.dart';

import '../../presentation/bloc/image_selection/image_selection_bloc.dart';
import '../../presentation/bloc/pdf_conversion/pdf_conversion_bloc.dart';
import '../../presentation/bloc/image_conversion/image_conversion_bloc.dart';
import '../../presentation/bloc/monetization/monetization_bloc.dart';

/// Global service locator instance
final GetIt sl = GetIt.instance;

/// Initialize all dependencies
Future<void> initDependencies() async {
  // ============ Services ============

  // Image Services
  sl.registerLazySingleton<HeicConverterService>(
    () => HeicConverterService(),
  );

  sl.registerLazySingleton<ImagePickerService>(
    () => ImagePickerService(
      heicConverter: sl<HeicConverterService>(),
    ),
  );

  sl.registerLazySingleton<ImageProcessorService>(
    () => ImageProcessorService(),
  );

  // Image Conversion Services
  sl.registerLazySingleton<FileExportService>(() => FileExportService());
  sl.registerLazySingleton<ImageConversionService>(
    () => ImageConversionService(exportService: sl()),
  );

  // PDF Services
  sl.registerLazySingleton<PdfGeneratorService>(
    () => PdfGeneratorService(
      imageProcessor: sl<ImageProcessorService>(),
      exportService: sl<FileExportService>(),
    ),
  );

  sl.registerLazySingleton<SizeOptimizerService>(
    () => SizeOptimizerService(
      pdfGenerator: sl<PdfGeneratorService>(),
      imageProcessor: sl<ImageProcessorService>(),
    ),
  );

  // PDF Merge Service
  sl.registerLazySingleton<PdfMergeService>(
    () => PdfMergeService(
      exportService: sl<FileExportService>(),
    ),
  );

  // Monetization Services
  sl.registerLazySingleton<AdsService>(
    () => AdsService(),
  );

  sl.registerLazySingleton<AuthService>(
    () => AuthService(),
  );

  // Firestore Sync Service
  sl.registerLazySingleton<FirestoreSyncService>(
    () => FirestoreSyncService(),
  );

  // Usage Statistics Service
  sl.registerLazySingleton<UsageStatsService>(
    () => UsageStatsService(),
  );

  // Initialize usage stats on app start
  await sl<UsageStatsService>().initialize();

  // Wire up Firestore sync to stats service
  sl<UsageStatsService>().setSyncService(sl<FirestoreSyncService>());

  // Conversion History Service
  sl.registerLazySingleton<ConversionHistoryService>(
    () => ConversionHistoryService(),
  );

  // Initialize history database on app start
  await sl<ConversionHistoryService>().initialize();

  // Wire up Firestore sync to history service
  sl<ConversionHistoryService>().setSyncService(sl<FirestoreSyncService>());

  // Walkthrough Service
  sl.registerLazySingleton<WalkthroughService>(
    () => WalkthroughService(),
  );

  // Initialize walkthrough service
  await sl<WalkthroughService>().initialize();

  // Support Service
  sl.registerLazySingleton<SupportService>(
    () => SupportService(),
  );

  // ============ BLoCs ============

  // BLoCs are registered as factory to create new instances
  // This allows proper disposal when widgets are removed

  sl.registerFactory<ImageSelectionBloc>(
    () => ImageSelectionBloc(
      imagePickerService: sl<ImagePickerService>(),
    ),
  );

  sl.registerFactory<PdfConversionBloc>(
    () => PdfConversionBloc(
      pdfGenerator: sl<PdfGeneratorService>(),
      sizeOptimizer: sl<SizeOptimizerService>(),
      statsService: sl<UsageStatsService>(),
      historyService: sl<ConversionHistoryService>(),
    ),
  );

  sl.registerFactory<ImageConversionBloc>(
    () => ImageConversionBloc(
      conversionService: sl<ImageConversionService>(),
      statsService: sl<UsageStatsService>(),
      historyService: sl<ConversionHistoryService>(),
    ),
  );

  sl.registerFactory<MonetizationBloc>(
    () => MonetizationBloc(
      adsService: sl<AdsService>(),
    ),
  );
}

/// Reset all dependencies (useful for testing)
Future<void> resetDependencies() async {
  await sl.reset();
}
