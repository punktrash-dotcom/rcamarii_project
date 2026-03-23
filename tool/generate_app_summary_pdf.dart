import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  const outputPath = 'output/pdf/rcamarii_app_summary.pdf';
  final regularFontBytes =
      await File('lib/assets/fonts/NotoSans-Regular.ttf').readAsBytes();
  final boldFontBytes =
      await File('lib/assets/fonts/NotoSans-Bold.ttf').readAsBytes();

  final regularFont = pw.Font.ttf(
    ByteData.sublistView(regularFontBytes),
  );
  final boldFont = pw.Font.ttf(
    ByteData.sublistView(boldFontBytes),
  );

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
      ),
      build: (context) => [
        _titleBlock(),
        pw.SizedBox(height: 16),
        _section(
          'What It Is',
          [
            _paragraph(
              'RCAMARii is a Flutter-based farm operations and finance app that combines estate tracking, activity logging, inventory, logistics, knowledge references, weather, and profit/reporting tools in one local-first workspace.',
            ),
          ],
        ),
        _section(
          'Who It\'s For',
          [
            _bullet(
              'Primary persona inferred from repo evidence: a farm operator, manager, or office staff member who needs to track farms, crews, supplies, deliveries, and financial outcomes.',
            ),
            _bullet(
              'Crop emphasis in repo: sugarcane workflows are the deepest, with additional rice knowledge content and logistics support for other crops such as corn and coconut.',
            ),
          ],
        ),
        _section(
          'What It Does',
          [
            _bullet('Manages farm or estate records, crop age, area, type, and location.'),
            _bullet('Logs field activities, job definitions, labor spend, and worker-linked operations.'),
            _bullet('Tracks supplies, equipment, catalog data, and market price references.'),
            _bullet('Captures logistics and deliveries, including sugarcane deliveries queued for profit processing.'),
            _bullet('Runs a financial tracker with charts, category analysis, printable transaction reports, and backup/restore.'),
            _bullet('Provides a sugarcane-focused profit calculator tied to deliveries and revenue records.'),
            _bullet('Includes a knowledge tab with handbook viewers and searchable Q&A loaded from seeded data.'),
            _bullet('Supports voice commands, text-to-speech responses, language selection, and optional live weather lookup.'),
          ],
        ),
        _section(
          'How It Works',
          [
            _bullet(
              'App shell: `lib/main.dart` builds a `MaterialApp`, registers `provider` state objects, and launches `SplashScreen`, which transitions into the `ScrMSoft` hub.',
            ),
            _bullet(
              'UI structure: the hub links to the main workspace (`FrmMain` tabs for Farm, Activities, Supplies, Knowledge) plus dedicated screens for logistics, workers, finance tracker, reports, settings, and the sugarcane profit calculator.',
            ),
            _bullet(
              'State management: `ChangeNotifier` providers manage farms, activities, supplies, equipment, deliveries, finance records, profits, weather, navigation, voice, theme, profile, language, audio, and app settings.',
            ),
            _bullet(
              'Persistence: `DatabaseHelper` creates and migrates local SQLite tables for farms, activities, supplies, financial tracker records, deliveries, sugarcane profits, equipment, employees, reference definitions, and knowledge Q&A.',
            ),
            _bullet(
              'Seed/reference data: `DataSeeder` loads CSV assets into work definitions, supply/equipment catalogs, and knowledge Q&A tables; bundled PDFs, DOCX files, audio, images, and fonts ship as app assets.',
            ),
            _bullet(
              'Preferences: `SharedPreferences` stores currency, launch destination, reduced motion, weather refresh, audio settings, voice settings, and other app-level preferences.',
            ),
            _bullet(
              'External integrations found in repo: HTTP weather requests via `WeatherProvider` and `AppConfig` environment variables; speech recognition and TTS through `speech_to_text` and `flutter_tts`.',
            ),
            _bullet(
              'Data flow examples: splash warms database and seed data, screens load through providers from SQLite and assets, logistics writes activity plus finance and optional delivery records in one transaction, and the profit calculator can save both a sugarcane profit record and a linked finance entry.',
            ),
            _bullet(
              'Backend service beyond weather: Not found in repo. The app appears primarily local-first.',
            ),
          ],
        ),
        _section(
          'How To Run',
          [
            _bullet(
              'Install Flutter. README does not pin the SDK version, but `pubspec.yaml` requires Dart `>=3.0.0 <4.0.0`.',
            ),
            _bullet('From the repo root, run `flutter pub get`.'),
            _bullet(
              'Optional for live weather: set `WEATHER_API_KEY` and, if needed, `WEATHER_API_URL` in the environment before launch.',
            ),
            _bullet('Start the app with `flutter run`.'),
            _bullet(
              'Platform packaging or production deployment instructions: Not found in repo.',
            ),
          ],
        ),
      ],
    ),
  );

  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsBytes(await doc.save());
  stdout.writeln(outputFile.path);
}

pw.Widget _titleBlock() {
  return pw.Container(
    padding: const pw.EdgeInsets.all(20),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromHex('#F3F0E4'),
      borderRadius: pw.BorderRadius.circular(14),
      border: pw.Border.all(
        color: PdfColor.fromHex('#21442E'),
        width: 1.2,
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RCAMARii App Summary',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#173524'),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Generated from repository evidence',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColor.fromHex('#4A5A50'),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _section(String title, List<pw.Widget> children) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#21442E'),
          ),
        ),
        pw.SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

pw.Widget _bullet(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2, right: 8),
          child: pw.Text(
            '-',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#173524'),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            text,
            style: const pw.TextStyle(
              fontSize: 10.5,
              lineSpacing: 2,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _paragraph(String text) {
  return pw.Text(
    text,
    style: const pw.TextStyle(
      fontSize: 10.5,
      lineSpacing: 2,
    ),
  );
}
