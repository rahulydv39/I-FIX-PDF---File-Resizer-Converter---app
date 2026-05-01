/// I FIX PDF App Root
/// Provides BLoC providers and theme configuration
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'presentation/bloc/image_selection/image_selection_bloc.dart';
import 'presentation/bloc/pdf_conversion/pdf_conversion_bloc.dart';
import 'presentation/bloc/monetization/monetization_bloc.dart';
import 'presentation/bloc/monetization/monetization_event.dart';
import 'presentation/screens/main_shell.dart';

/// Root application widget
class FileConverterApp extends StatelessWidget {
  final Widget? home;

  const FileConverterApp({
    super.key,
    this.home,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Image Selection BLoC
        BlocProvider<ImageSelectionBloc>(
          create: (_) => sl<ImageSelectionBloc>(),
        ),

        // PDF Conversion BLoC
        BlocProvider<PdfConversionBloc>(
          create: (_) => sl<PdfConversionBloc>(),
        ),

        // Monetization BLoC (initialized on creation)
        BlocProvider<MonetizationBloc>(
          create: (_) => sl<MonetizationBloc>()
            ..add(const InitializeMonetization()),
        ),
      ],
      child: MaterialApp(
        title: 'I FIX PDF',
        debugShowCheckedModeBanner: false,

        // Theme configuration
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,

        // Main shell with bottom navigation
        home: home ?? const MainShell(),
      ),
    );
  }
}
