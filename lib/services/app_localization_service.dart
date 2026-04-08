import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/guideline_language_provider.dart';
import 'guideline_localization_service.dart';

class AppLocalizationService {
  static Locale materialLocale(GuidelineLanguage language) {
    switch (language) {
      case GuidelineLanguage.tagalog:
        return const Locale('fil');
      case GuidelineLanguage.english:
      case GuidelineLanguage.visayan:
        return const Locale('en');
    }
  }

  static String text(GuidelineLanguage language, String key) {
    return localizeLooseText(language, _copy[language]?[key] ?? key);
  }

  static String format(
    GuidelineLanguage language,
    String key, [
    Map<String, String> values = const {},
  ]) {
    var output = text(language, key);
    values.forEach((name, value) {
      output = output.replaceAll(
        '{$name}',
        localizeLooseText(language, value),
      );
    });
    return localizeLooseText(language, output);
  }

  static String localizeLooseText(GuidelineLanguage language, String value) {
    if (language != GuidelineLanguage.visayan || value.isEmpty) {
      return value;
    }

    const replacements = <String, String>{
      'Profit Tools': 'Kalkulasyon sa Ganansya',
      'Panalapi': 'Pagsubay sa Gasto',
      'Finance': 'Pagsubay sa Gasto',
      'Farm Hub': 'Kaumahan',
      'Operations': 'Mga Trabaho',
      'Inventory': 'Gamit sa Uma',
      'Library': 'Tabang Basahon',
      'Mga Delivery': 'Pagbaligya sa Produkto',
      'Deliveries': 'Pagbaligya sa Produkto',
      'Employees': 'Mga Trabahante',
      'Yuta': 'Mga Uma',
      'Estate': 'Mga Uma',
      'Sugarcane and Rice': 'Tubo ug Humay',
      'sugarcane and rice': 'tubo ug humay',
      'Sugarcane': 'Tubo',
      'sugarcane': 'tubo',
      'Rice': 'Humay',
      'rice': 'humay',
      'Corn': 'Mais',
      'corn': 'mais',
    };

    final orderedEntries = replacements.entries.toList()
      ..sort((left, right) => right.key.length.compareTo(left.key.length));

    var localized = value;
    for (final entry in orderedEntries) {
      localized = localized.replaceAllMapped(
        RegExp('(?<!\\w)${RegExp.escape(entry.key)}(?!\\w)'),
        (_) => entry.value,
      );
    }
    return localized;
  }

  static final Map<GuidelineLanguage, Map<String, String>> _copy = {
    GuidelineLanguage.tagalog: {
      'RCAMARii is tuning your farm command center':
          'Inaayos ng RCAMARii ang command center ng iyong bukid',
      'FIELD INTELLIGENCE BY NOMAD TECHNOLOGIES':
          'FIELD INTELLIGENCE NG NOMAD TECHNOLOGIES',
      'Field intelligence for farms, crews, logistics, supplies, and profit.':
          'Field intelligence para sa mga bukid, tauhan, logistics, supplies, at kita.',
      'Farm': 'Bukid',
      'Logistics': 'Logistics',
      'Profit': 'Kita',
      'Copilot': 'Copilot',
      'Supply Intelligence': 'Supply Intelligence',
      'Knowledge Studio': 'Knowledge Studio',
      'Main Hub': 'Pangunahing Hub',
      'Search current database': 'Maghanap sa kasalukuyang database',
      'Weather forecast': 'Pagtataya ng panahon',
      'Voice command': 'Voice command',
      'Search this section': 'Hanapin sa seksyong ito',
      'Estate': 'Bukirin',
      'Ledger': 'Ledger',
      'Activities': 'Mga Gawain',
      'Assets': 'Mga Asset',
      'Supplies': 'Mga Supply',
      'Library': 'Aklatan',
      'Knowledge': 'Kaalaman',
      'Settings': 'Mga Setting',
      'Workspace Controls': 'Mga Kontrol sa Workspace',
      'Choose the preferred language for supply guidance before opening the field modules.':
          'Piliin ang gustong wika para sa supply guidance bago buksan ang mga field module.',
      'Weather offline': 'Hindi available ang panahon',
      'RCAMARii is online. Ask for farm status, delivery impact, supply guidance, or weather context.':
          'Online ang RCAMARii. Magtanong tungkol sa kalagayan ng bukid, epekto ng delivery, gabay sa supply, o konteksto ng panahon.',
      'Voice': 'Boses',
      'Your farm command center is ready.':
          'Handa na ang command center ng iyong bukid.',
      "Today's focus is {farm}.": 'Ang pokus ngayon ay si {farm}.',
      'Add a farm, connect a delivery, or ask RCAMARii what to do next.':
          'Magdagdag ng bukid, iugnay ang delivery, o tanungin ang RCAMARii kung ano ang susunod.',
      '{crop} is active, {days} days from planting, with {deliveries} sugarcane deliveries in the current queue.':
          'Aktibo ang {crop}, {days} araw mula nang itanim, at may {deliveries} sugarcane deliveries sa kasalukuyang pila.',
      'What does my active farm need this week?':
          'Ano ang kailangan ng aktibo kong bukid ngayong linggo?',
      'What should I buy next?': 'Ano ang dapat kong bilhin sunod?',
      'Summarize my deliveries': 'Ibuod ang aking deliveries',
      'Ask RCAMARii for a field brief...':
          'Tanungin ang RCAMARii para sa field brief...',
      'Ask RCAMARii': 'Tanungin ang RCAMARii',
      'Farms': 'Mga Bukid',
      'Deliveries': 'Mga Delivery',
      'Conversation Feed': 'Feed ng Usapan',
      'Autopilot': 'Autopilot',
      'Use typed or voice prompts. RCAMARii answers from your current farm context and existing knowledge logic.':
          'Gumamit ng typed o voice prompt. Sumasagot ang RCAMARii mula sa kasalukuyang konteksto ng bukid at umiiral na logic ng kaalaman.',
      'Sensitivity': 'Sensitivity',
      'Open farms': 'Buksan ang mga bukid',
      'Crew panel': 'Panel ng tauhan',
      'Tracker': 'Tracker',
      'Estimate ROI': 'Tantyahin ang ROI',
      'Charts': 'Mga Chart',
      'Action Deck': 'Action Deck',
      'Jump into core modules without losing the copilot context.':
          'Pumasok sa mga pangunahing module nang hindi nawawala ang konteksto ng copilot.',
      'Finance': 'Pananalapi',
      'Workers': 'Mga Manggagawa',
      'Reports': 'Mga Ulat',
      'No active farm': 'Walang aktibong bukid',
      'Select a farm to make RCAMARii specific.':
          'Pumili ng bukid para maging mas tiyak ang RCAMARii.',
      '{crop} - {days} days - {area} ha': '{crop} - {days} araw - {area} ha',
      'Weather pending': 'Nakabinbin ang panahon',
      'Weather brief': 'Ulat sa panahon',
      'Forecast sync will appear here.':
          'Lalabas dito ang na-sync na forecast.',
      'Equipment readiness': 'Kahandaan ng kagamitan',
      '{count} equipment records available for review.':
          '{count} tala ng kagamitan ang handang suriin.',
      'Sugarcane queue': 'Pila ng sugarcane',
      '{count} delivery records are ready for profit work.':
          '{count} tala ng delivery ang handa para sa profit work.',
      'Live Overview': 'Live Overview',
      'Field focus': 'Pokus sa bukid',
      'Choose a farm to unlock crop-stage guidance.':
          'Pumili ng bukid para ma-unlock ang crop-stage guidance.',
      '{farm} is {days} days from planting.':
          'Si {farm} ay {days} araw mula nang itanim.',
      'Activity pulse': 'Galaw ng aktibidad',
      '{count} activity records were logged in the last 7 days.':
          '{count} tala ng aktibidad ang na-log sa nakaraang 7 araw.',
      'Inventory posture': 'Lagayan ng imbentaryo',
      '{count} supply entries are available for review.':
          '{count} supply entry ang handang suriin.',
      'Delivery posture': 'Kalagayan ng delivery',
      '{count} deliveries are recorded across the app.':
          '{count} delivery ang naitala sa buong app.',
      'Today Board': 'Board Ngayon',
      'A fast operational summary driven by your existing farm records.':
          'Mabilis na buod ng operasyon batay sa iyong mga kasalukuyang tala ng bukid.',
      'Exit RCAMARii': 'Lumabas sa RCAMARii',
      'Estate Oversight': 'Pangangalaga sa Bukirin',
      'ADD ESTATE': 'MAGDAGDAG NG BUKIRIN',
      'ADD TASK': 'MAGDAGDAG NG GAWAIN',
      'EDIT': 'I-EDIT',
      'DELETE': 'BURAHIN',
      'Estates': 'Mga Bukirin',
      'Area': 'Lawak',
      'None': 'Wala',
      'NO DATA': 'WALANG DATA',
      'Age of Crop: {days} days': 'Edad ng Tanim: {days} araw',
      '{type} - {area} Hectares': '{type} - {area} Ektarya',
      'Location: {city}, {province}': 'Lokasyon: {city}, {province}',
      'View Details': 'Tingnan ang Detalye',
      'TERMINAL STANDBY': 'NAKA-STANDBY ANG TERMINAL',
      'INITIALIZE NEW ESTATE': 'SIMULAN ANG BAGONG BUKIRIN',
      'Confirm Removal': 'Kumpirmahin ang Pagtanggal',
      'Are you sure you want to remove this record from the grid?':
          'Sigurado ka bang gusto mong tanggalin ang record na ito sa grid?',
      'CANCEL': 'KANSELAHIN',
      'REMOVE': 'ALISIN',
      'Activity Intelligence': 'Activity Intelligence',
      'NEW JOB ORDER': 'BAGONG JOB ORDER',
      'Jobs': 'Mga Trabaho',
      'Spend': 'Gastos',
      'Focus': 'Pokus',
      'All farms': 'Lahat ng bukid',
      'LEDGER': 'LEDGER',
      'TASKS': 'MGA GAWAIN',
      'RESET': 'I-RESET',
      'Sort activities': 'Ayusin ang mga aktibidad',
      'SORT: {mode}': 'AYOS: {mode}',
      'Date': 'Petsa',
      'Crop': 'Pananim',
      'Worker: Unassigned': 'Manggagawa: Wala pang naka-assign',
      'Worker: {worker}': 'Manggagawa: {worker}',
      'Type: {type}': 'Uri: {type}',
      'Mode: {mode}': 'Paraan: {mode}',
      'Ready for selection in new job orders':
          'Handa para piliin sa mga bagong job order',
      '{duration} hr': '{duration} oras',
      'INITIALIZE NEW JOB ORDER': 'SIMULAN ANG BAGONG JOB ORDER',
      'TASK GRID EMPTY': 'WALANG LAMAN ANG TASK GRID',
      'ADD TASK DEFINITION': 'MAGDAGDAG NG TASK DEFINITION',
      'Are you sure you want to remove "{name}" from task definitions?':
          'Sigurado ka bang gusto mong alisin si "{name}" mula sa mga task definition?',
      'Task definition removed': 'Inalis ang task definition',
      'Are you sure you want to remove "{name}" from the ledger?':
          'Sigurado ka bang gusto mong alisin si "{name}" mula sa ledger?',
      'Job removed from ledger': 'Inalis ang job mula sa ledger',
      'Edit Job Record': 'I-edit ang Job Record',
      'Open this job order for editing?':
          'Buksan ang job order na ito para i-edit?',
      'OPEN': 'BUKSAN',
      'Back to Hub': 'Bumalik sa Hub',
      'Edit Profile': 'I-edit ang Profile',
      'Wallet Name': 'Pangalan ng Wallet',
      'Cancel': 'Kanselahin',
      'Save': 'I-save',
      'Good Afternoon,': 'Magandang Hapon,',
      'Recent Transactions': 'Mga Huling Transaksyon',
      'Home': 'Home',
      'Analytics': 'Analytics',
      'Hub': 'Hub',
      'Total Balance': 'Kabuuang Balanse',
      'Income': 'Kita',
      'Expenses': 'Mga Gastos',
      'Net': 'Net',
      'GENERAL': 'PANGKALAHATAN',
      'APP PREFERENCES': 'MGA PREFERENSIYA NG APP',
      'These preferences apply across RCAMARii.':
          'Nalalapat ang mga kagustuhang ito sa buong RCAMARii.',
      'Language': 'Wika',
      'Launch Screen': 'Panimulang Screen',
      'Operational Hub': 'Operational Hub',
      'Field Workspace': 'Field Workspace',
      'Manage Categories': 'Pamahalaan ang Mga Kategorya',
      'FINANCE': 'PANANALAPI',
      'Currency': 'Currency',
      'APPEARANCE': 'ITSURA',
      'Dark Mode': 'Dark Mode',
      'Reduced Motion': 'Bawasan ang Galaw',
      'VOICE & ASSISTANCE': 'BOSES AT TULONG',
      'Voice Assistant': 'Voice Assistant',
      'Spoken Responses': 'Pasalitang Tugon',
      'WEATHER': 'PANAHON',
      'Auto Refresh Weather': 'Awtomatikong I-refresh ang Panahon',
      'DATA MANAGEMENT': 'PAMAMAHALA NG DATA',
      'Backup Data': 'I-backup ang Data',
      'Restore Data': 'I-restore ang Data',
      'ABOUT': 'TUNGKOL',
      'About RCAMARii': 'Tungkol sa RCAMARii',
      'Built from a family farm in Bukidnon':
          'Binuo mula sa isang pamilyang bukid sa Bukidnon',
      'RCAMARii grew out of real field work, real family decisions, and real farming needs.':
          'Lumago ang RCAMARii mula sa totoong gawain sa bukid, totoong mga pasya ng pamilya, at totoong pangangailangan sa pagsasaka.',
      'From its roots in Bukidnon, the app now aims to offer practical guidance for farmers who need a clearer way to manage operations and learn as they grow.':
          'Mula sa mga ugat nito sa Bukidnon, layunin ngayon ng app na magbigay ng praktikal na gabay para sa mga magsasakang nangangailangan ng mas malinaw na paraan upang pamahalaan ang operasyon at matuto habang lumalago.',
      'Family-owned': 'Pagmamay-ari ng pamilya',
      'Sugarcane focus': 'Pokus sa tubo',
      'Rice guidance': 'Gabay sa palay',
      'Built by NOMAD': 'Binuo ni NOMAD',
      'Built for one family farm, shared to guide many more.':
          'Binuo para sa isang pamilyang bukid, ibinahagi upang gumabay sa marami pa.',
      'Programmer': 'Programmer',
      'Location': 'Lokasyon',
      'Where RCAMARii started': 'Saan nagsimula ang RCAMARii',
      'RCAMARii began as a practical tool for a family-owned farm in Sinayawan, Valencia City, Bukidnon. It was originally built to support the daily work of the family farm, from organizing field activities to keeping records clearer and easier to review.':
          'Nagsimula ang RCAMARii bilang praktikal na kasangkapan para sa isang pamilyang bukid sa Sinayawan, Valencia City, Bukidnon. Orihinal itong ginawa upang suportahan ang araw-araw na gawain ng bukid, mula sa pag-aayos ng mga aktibidad sa bukid hanggang sa pagpapalinaw at pagpapadali ng pagrepaso sa mga tala.',
      'Why it was shared': 'Bakit ito ibinahagi',
      'As the system became more useful in real farm operations, NOMAD, the owner and programmer behind RCAMARii, decided not to keep it private. The goal expanded from helping one farm operate better to helping new sugarcane and rice farmers gain guidance, structure, and confidence in managing their own farms.':
          'Habang mas naging kapaki-pakinabang ang sistema sa totoong operasyon ng bukid, nagpasya si NOMAD, ang may-ari at programmer sa likod ng RCAMARii, na huwag itong panatilihing pribado. Lumawak ang layunin mula sa pagtulong sa isang bukid na mas mahusay na magpatakbo tungo sa pagtulong sa mga bagong magsasaka ng tubo at palay na magkaroon ng gabay, istruktura, at kumpiyansa sa pamamahala ng sarili nilang mga bukid.',
      'What the app is for': 'Para saan ang app',
      'RCAMARii is designed to bring together estate records, job orders, supply references, weather context, and farm guidance in one place. It is meant to support real agricultural work with a focus on sugarcane and rice farming, especially for growers who are still building their routines and decision-making process.':
          'Dinisenyo ang RCAMARii upang pagsamahin sa iisang lugar ang mga tala ng bukid, job orders, supply references, konteksto ng panahon, at gabay sa pagsasaka. Nilalayon nitong suportahan ang totoong gawaing agrikultural na nakatuon sa pagtatanim ng tubo at palay, lalo na para sa mga magsasakang binubuo pa ang kanilang mga nakasanayan at proseso ng pagdedesisyon.',
      'Mission': 'Misyon',
      'RCAMARii exists to turn lived farming experience into practical support. It reflects the discipline of a working family farm in Bukidnon and shares that experience to help newer farmers start with better guidance, better records, and better day-to-day decisions.':
          'Umiiral ang RCAMARii upang gawing praktikal na suporta ang tunay na karanasan sa pagsasaka. Sinasalamin nito ang disiplina ng isang pamilyang bukid na aktibong nagtatrabaho sa Bukidnon at ibinabahagi ang karanasang iyon upang matulungan ang mga bagong magsasaka na magsimula nang may mas mabuting gabay, mas maayos na mga tala, at mas mahusay na araw-araw na pagdedesisyon.',
      'Sugarcane and Rice': 'Tubo at Palay',
      'Philippine Peso': 'Philippine Peso',
      'US Dollar': 'US Dollar',
      'Euro': 'Euro',
    },
    GuidelineLanguage.visayan: {
      'RCAMARii is tuning your farm command center':
          'Gi-andam sa RCAMARii ang command center sa imong umahan',
      'FIELD INTELLIGENCE BY NOMAD TECHNOLOGIES':
          'FIELD INTELLIGENCE SA NOMAD TECHNOLOGIES',
      'Field intelligence for farms, crews, logistics, supplies, and profit.':
          'Field intelligence para sa mga umahan, crew, logistics, supplies, ug kita.',
      'Farm': 'Umahan',
      'Logistics': 'Logistics',
      'Profit': 'Kita',
      'Copilot': 'Copilot',
      'Supply Intelligence': 'Supply Intelligence',
      'Knowledge Studio': 'Knowledge Studio',
      'Main Hub': 'Pangunang Hub',
      'Search current database': 'Pangitaa sa kasamtangang database',
      'Weather forecast': 'Panagna sa panahon',
      'Voice command': 'Voice command',
      'Search this section': 'Pangitaa sa seksyong kini',
      'Estate': 'Yuta',
      'Ledger': 'Ledger',
      'Activities': 'Mga Buluhaton',
      'Assets': 'Mga Asset',
      'Supplies': 'Mga Supply',
      'Library': 'Library',
      'Knowledge': 'Kahibalo',
      'Settings': 'Mga Setting',
      'Workspace Controls': 'Mga Kontrol sa Workspace',
      'Choose the preferred language for supply guidance before opening the field modules.':
          'Pilia ang gusto nga pinulongan para sa giya sa supply sa dili pa ablihan ang mga field module.',
      'Weather offline': 'Walay datos sa panahon',
      'RCAMARii is online. Ask for farm status, delivery impact, supply guidance, or weather context.':
          'Online ang RCAMARii. Pangutana bahin sa kahimtang sa umahan, epekto sa delivery, giya sa supply, o konteksto sa panahon.',
      'Voice': 'Tingog',
      'Your farm command center is ready.':
          'Andam na ang command center sa imong umahan.',
      "Today's focus is {farm}.": 'Ang tutok karon mao si {farm}.',
      'Add a farm, connect a delivery, or ask RCAMARii what to do next.':
          'Pagdugang og umahan, ikonekta ang delivery, o pangutan-a ang RCAMARii unsay sunod buhaton.',
      '{crop} is active, {days} days from planting, with {deliveries} sugarcane deliveries in the current queue.':
          'Aktibo ang {crop}, {days} ka adlaw sukad pagtanom, ug adunay {deliveries} ka sugarcane delivery sa kasamtangang pila.',
      'What does my active farm need this week?':
          'Unsa man ang kinahanglan sa akong aktibong umahan karong semanaha?',
      'What should I buy next?': 'Unsa man ang akong paliton sunod?',
      'Summarize my deliveries': 'I-summarize ang akong mga delivery',
      'Ask RCAMARii for a field brief...':
          'Pangayo og field brief gikan sa RCAMARii...',
      'Ask RCAMARii': 'Pangutan-a ang RCAMARii',
      'Farms': 'Mga Umahan',
      'Deliveries': 'Mga Delivery',
      'Conversation Feed': 'Conversation Feed',
      'Autopilot': 'Autopilot',
      'Use typed or voice prompts. RCAMARii answers from your current farm context and existing knowledge logic.':
          'Gamita ang typed o voice prompt. Motubag ang RCAMARii base sa kasamtangang konteksto sa umahan ug sa naang kahibalo.',
      'Sensitivity': 'Sensitivity',
      'Open farms': 'Ablihi ang mga umahan',
      'Crew panel': 'Crew panel',
      'Tracker': 'Tracker',
      'Estimate ROI': 'Tantiyaa ang ROI',
      'Charts': 'Mga Chart',
      'Action Deck': 'Action Deck',
      'Jump into core modules without losing the copilot context.':
          'Sulod sa mga core module nga dili mawala ang konteksto sa copilot.',
      'Finance': 'Panalapi',
      'Workers': 'Mga Trabahante',
      'Reports': 'Mga Report',
      'No active farm': 'Walay aktibong umahan',
      'Select a farm to make RCAMARii specific.':
          'Pili og umahan aron mahimong mas piho ang RCAMARii.',
      '{crop} - {days} days - {area} ha':
          '{crop} - {days} ka adlaw - {area} ha',
      'Weather pending': 'Naghulat sa panahon',
      'Weather brief': 'Mubo nga report sa panahon',
      'Forecast sync will appear here.': 'Mogawas dinhi ang forecast sync.',
      'Equipment readiness': 'Kaandam sa ekipo',
      '{count} equipment records available for review.':
          '{count} ka talaan sa ekipo ang andam tan-awon.',
      'Sugarcane queue': 'Pila sa sugarcane',
      '{count} delivery records are ready for profit work.':
          '{count} ka talaan sa delivery ang andam para sa profit work.',
      'Live Overview': 'Live Overview',
      'Field focus': 'Tutok sa umahan',
      'Choose a farm to unlock crop-stage guidance.':
          'Pili og umahan aron maablihan ang crop-stage guidance.',
      '{farm} is {days} days from planting.':
          'Si {farm} kay {days} ka adlaw sukad pagtanom.',
      'Activity pulse': 'Galaw sa aktibidad',
      '{count} activity records were logged in the last 7 days.':
          '{count} ka activity record ang na-log sa miaging 7 ka adlaw.',
      'Inventory posture': 'Kahimtang sa imbentaryo',
      '{count} supply entries are available for review.':
          '{count} ka supply entry ang andam tan-awon.',
      'Delivery posture': 'Kahimtang sa delivery',
      '{count} deliveries are recorded across the app.':
          '{count} ka delivery ang natala sa tibuok app.',
      'Today Board': 'Board Karong Adlawa',
      'A fast operational summary driven by your existing farm records.':
          'Paspas nga operasyon nga summary base sa imong kasamtangang farm record.',
      'Exit RCAMARii': 'Mugawas sa RCAMARii',
      'Estate Oversight': 'Pagdumala sa Umahan',
      'ADD ESTATE': 'PAGDUGANG OG UMAHAN',
      'ADD TASK': 'PAGDUGANG OG BULUHATON',
      'EDIT': 'USABA',
      'DELETE': 'TANGTANGA',
      'Estates': 'Mga Umahan',
      'Area': 'Kadak-on',
      'None': 'Wala',
      'NO DATA': 'WALAY DATA',
      'Age of Crop: {days} days': 'Edad sa tanom: {days} ka adlaw',
      '{type} - {area} Hectares': '{type} - {area} Hektarya',
      'Location: {city}, {province}': 'Lokasyon: {city}, {province}',
      'View Details': 'Tan-awa ang detalye',
      'TERMINAL STANDBY': 'NAKA-STANDBY ANG TERMINAL',
      'INITIALIZE NEW ESTATE': 'SUGDI ANG BAG-ONG UMAHAN',
      'Confirm Removal': 'Kumpirmaha ang pagtangtang',
      'Are you sure you want to remove this record from the grid?':
          'Sigurado ba ka nga gusto nimong tangtangon kining talaan sa grid?',
      'CANCEL': 'KANSELA',
      'REMOVE': 'TANGTANGON',
      'Activity Intelligence': 'Activity Intelligence',
      'NEW JOB ORDER': 'BAG-ONG JOB ORDER',
      'Jobs': 'Mga Trabaho',
      'Spend': 'Gasto',
      'Focus': 'Tutok',
      'All farms': 'Tanang umahan',
      'LEDGER': 'LEDGER',
      'TASKS': 'MGA BULUHATON',
      'RESET': 'I-RESET',
      'Sort activities': 'Ihan-ay ang mga aktibidad',
      'SORT: {mode}': 'HAN-AY: {mode}',
      'Date': 'Petsa',
      'Crop': 'Tanom',
      'Worker: Unassigned': 'Trabahante: Wala pay gi-assign',
      'Worker: {worker}': 'Trabahante: {worker}',
      'Type: {type}': 'Tipo: {type}',
      'Mode: {mode}': 'Pamaagi: {mode}',
      'Ready for selection in new job orders':
          'Andam mapilian sa bag-ong mga job order',
      '{duration} hr': '{duration} oras',
      'INITIALIZE NEW JOB ORDER': 'SUGDI ANG BAG-ONG JOB ORDER',
      'TASK GRID EMPTY': 'WALAY SULOD ANG TASK GRID',
      'ADD TASK DEFINITION': 'PAGDUGANG OG TASK DEFINITION',
      'Are you sure you want to remove "{name}" from task definitions?':
          'Sigurado ba ka nga gusto nimong tangtangon si "{name}" gikan sa mga task definition?',
      'Task definition removed': 'Gikuha ang task definition',
      'Are you sure you want to remove "{name}" from the ledger?':
          'Sigurado ba ka nga gusto nimong tangtangon si "{name}" gikan sa ledger?',
      'Job removed from ledger': 'Gikuha ang job gikan sa ledger',
      'Edit Job Record': 'Usba ang Job Record',
      'Open this job order for editing?':
          'Ablihan ba kini nga job order para usbon?',
      'OPEN': 'ABLIHI',
      'Back to Hub': 'Balik sa Hub',
      'Edit Profile': 'Usba ang Profile',
      'Wallet Name': 'Ngalan sa Wallet',
      'Cancel': 'Kansela',
      'Save': 'I-save',
      'Good Afternoon,': 'Maayong Hapon,',
      'Recent Transactions': 'Bag-ong mga Transaksyon',
      'Home': 'Home',
      'Analytics': 'Analytics',
      'Hub': 'Hub',
      'Total Balance': 'Kinatibuk-ang Balanse',
      'Income': 'Kita',
      'Expenses': 'Mga Gasto',
      'Net': 'Net',
      'GENERAL': 'KINATIBUK-AN',
      'APP PREFERENCES': 'MGA PREFERENSIYA SA APP',
      'These preferences apply across RCAMARii.':
          'Kining mga gusto magamit sa tibuok RCAMARii.',
      'Language': 'Pinulongan',
      'Launch Screen': 'Pangunang Screen',
      'Operational Hub': 'Operational Hub',
      'Field Workspace': 'Field Workspace',
      'Manage Categories': 'Dumalahon ang mga Kategorya',
      'FINANCE': 'PANALAPI',
      'Currency': 'Currency',
      'APPEARANCE': 'PANAGWAY',
      'Dark Mode': 'Dark Mode',
      'Reduced Motion': 'Bawasan ang Lihok',
      'VOICE & ASSISTANCE': 'TINGOG UG TABANG',
      'Voice Assistant': 'Voice Assistant',
      'Spoken Responses': 'Sinultihang Tubag',
      'WEATHER': 'PANAHON',
      'Auto Refresh Weather': 'Awtomatikong I-refresh ang Panahon',
      'DATA MANAGEMENT': 'PAGDUMALA SA DATA',
      'Backup Data': 'I-backup ang Data',
      'Restore Data': 'I-restore ang Data',
      'ABOUT': 'BAHIN',
      'About RCAMARii': 'Bahin sa RCAMARii',
      'Built from a family farm in Bukidnon':
          'Gikan sa usa ka pamilyang umahan sa Bukidnon',
      'RCAMARii grew out of real field work, real family decisions, and real farming needs.':
          'Mitubo ang RCAMARii gikan sa tinuod nga trabaho sa umahan, tinuod nga mga desisyon sa pamilya, ug tinuod nga panginahanglan sa pagpanguma.',
      'From its roots in Bukidnon, the app now aims to offer practical guidance for farmers who need a clearer way to manage operations and learn as they grow.':
          'Gikan sa gigikanan niini sa Bukidnon, tumong karon sa app ang paghatag og praktikal nga giya alang sa mga mag-uuma nga nanginahanglan og mas klarong paagi sa pagdumala sa operasyon ug pagkat-on samtang nag-uswag sila.',
      'Family-owned': 'Pagpanag-iya sa pamilya',
      'Sugarcane focus': 'Tutok sa sugarcane',
      'Rice guidance': 'Giya sa humay',
      'Built by NOMAD': 'Gibuhat ni NOMAD',
      'Built for one family farm, shared to guide many more.':
          'Gibuhat para sa usa ka pamilyang umahan, gipaambit aron mogiya sa daghan pa.',
      'Programmer': 'Programmer',
      'Location': 'Lokasyon',
      'Where RCAMARii started': 'Asa nagsugod ang RCAMARii',
      'RCAMARii began as a practical tool for a family-owned farm in Sinayawan, Valencia City, Bukidnon. It was originally built to support the daily work of the family farm, from organizing field activities to keeping records clearer and easier to review.':
          'Nagsugod ang RCAMARii isip praktikal nga himan para sa usa ka pamilyang umahan sa Sinayawan, Valencia City, Bukidnon. Sa sinugdanan, gihimo kini aron mosuporta sa adlaw-adlaw nga trabaho sa pamilyang umahan, gikan sa pag-organisa sa mga kalihokan sa umahan hangtod sa paghimo sa mga rekord nga mas klaro ug mas sayon tan-awon pag-usab.',
      'Why it was shared': 'Ngano nga gipaambit kini',
      'As the system became more useful in real farm operations, NOMAD, the owner and programmer behind RCAMARii, decided not to keep it private. The goal expanded from helping one farm operate better to helping new sugarcane and rice farmers gain guidance, structure, and confidence in managing their own farms.':
          'Samtang mas nahimong mapuslanon ang sistema sa tinuod nga operasyon sa umahan, si NOMAD, ang tag-iya ug programmer sa likod sa RCAMARii, nakahukom nga dili kini taguon isip pribado. Milapad ang tumong gikan sa pagtabang sa usa ka umahan nga mas maayong modagan ngadto sa pagtabang sa bag-ong mga mag-uuma sa sugarcane ug humay nga makabaton og giya, istruktura, ug pagsalig sa pagdumala sa ilang kaugalingong mga umahan.',
      'What the app is for': 'Para unsa ang app',
      'RCAMARii is designed to bring together estate records, job orders, supply references, weather context, and farm guidance in one place. It is meant to support real agricultural work with a focus on sugarcane and rice farming, especially for growers who are still building their routines and decision-making process.':
          'Gidisenyo ang RCAMARii aron tipunon sa usa ka lugar ang mga rekord sa umahan, job orders, supply references, konteksto sa panahon, ug giya sa pagpanguma. Gituyo kini aron mosuporta sa tinuod nga buluhaton sa agrikultura nga nakatutok sa pagpanguma og sugarcane ug humay, ilabi na sa mga mag-uuma nga nagatukod pa sa ilang rutina ug proseso sa pagdesisyon.',
      'Mission': 'Misyon',
      'RCAMARii exists to turn lived farming experience into practical support. It reflects the discipline of a working family farm in Bukidnon and shares that experience to help newer farmers start with better guidance, better records, and better day-to-day decisions.':
          'Naa ang RCAMARii aron himuong praktikal nga suporta ang tinuod nga kasinatian sa pagpanguma. Gipakita niini ang disiplina sa usa ka nagtrabahong pamilyang umahan sa Bukidnon ug gipaambit kana nga kasinatian aron matabangan ang mga bag-ong mag-uuma nga magsugod uban sa mas maayong giya, mas maayong mga rekord, ug mas maayong adlaw-adlaw nga mga desisyon.',
      'Sugarcane and Rice': 'Sugarcane ug Humay',
      'Philippine Peso': 'Philippine Peso',
      'US Dollar': 'US Dollar',
      'Euro': 'Euro',
    },
  };
}

extension AppLocalizationBuildContext on BuildContext {
  GuidelineLanguage get appLanguage {
    final canListen = owner?.debugBuilding ?? false;
    if (canListen) {
      return watch<GuidelineLanguageProvider>().selectedLanguage;
    }
    return read<GuidelineLanguageProvider>().selectedLanguage;
  }

  GuidelineLanguage get appLanguageRead =>
      read<GuidelineLanguageProvider>().selectedLanguage;

  String tr(String key, [Map<String, String> values = const {}]) {
    return AppLocalizationService.format(appLanguage, key, values);
  }

  String trRead(String key, [Map<String, String> values = const {}]) {
    return AppLocalizationService.format(appLanguageRead, key, values);
  }

  String localizeText(String value) {
    return AppLocalizationService.localizeLooseText(appLanguage, value);
  }

  String localizeTextRead(String value) {
    return AppLocalizationService.localizeLooseText(appLanguageRead, value);
  }
}
