import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _PriceEntry {
  final double cost;
  final Set<String> aliases;

  const _PriceEntry(this.cost, this.aliases);
}

String _normalize(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await databaseFactory.openDatabase(
    r'C:\Users\punkt\OneDrive\Documents\RcamariiFarm.db',
  );

  final priceEntries = <_PriceEntry>[
    _PriceEntry(298.75, {'Agro Cypermethrin', 'AGRO CYPERMETHRIN 5 EC'}),
    _PriceEntry(635.83, {'Bida', 'BIDA 2.5 EC'}),
    _PriceEntry(517.52, {'Brodan', 'BRODAN 31.5 EC'}),
    _PriceEntry(412.12, {'Bushwhack', 'BUSHWACK 5 EC'}),
    _PriceEntry(748.50, {'Chix', 'CHIX 2.5 EC'}),
    _PriceEntry(460.32, {'Cymbush', 'CYMBUSH 5 EC'}),
    _PriceEntry(882.00, {'Prevathon', 'PREVATHON SC'}),
    _PriceEntry(401.88, {'Agroxone'}),
    _PriceEntry(384.85, {'2-4D Ester', '2,4-D Ester', '2,4-D ESTER 40 EC'}),
    _PriceEntry(707.68, {'Clear-out', 'CLEAROUT 41 PLUS'}),
    _PriceEntry(772.62, {'Ground Plus', 'Ground Phus'}),
    _PriceEntry(373.75, {'Glyphobest', 'Glvphobest'}),
    _PriceEntry(504.90, {'Hedonal', 'Hedon'}),
    _PriceEntry(610.00, {'Hero'}),
    _PriceEntry(633.44, {'Machete'}),
    _PriceEntry(565.00, {'Mower'}),
    _PriceEntry(1428.75, {'Nominee', 'Nominge'}),
    _PriceEntry(1250.00, {'P-max', 'P-max/500ml'}),
    _PriceEntry(1160.00, {'Pyanchor Ultra'}),
    _PriceEntry(480.83, {'Round up', 'Round ue', 'RUN-UP'}),
    _PriceEntry(431.46, {'Sharp Shooter', 'SHARPSHOOTER'}),
    _PriceEntry(522.50, {'Shine'}),
    _PriceEntry(540.00, {'Slash'}),
    _PriceEntry(995.00, {'Square off'}),
    _PriceEntry(1024.48, {'Sofit'}),
    _PriceEntry(1337.50, {'Spitfire', 'SPITFIRE'}),
    _PriceEntry(1283.33, {'Triple 8', 'Triple B/gal'}),
    _PriceEntry(702.80, {'Antracol', 'ANTRACOL 70 WG', 'ANTRACOL 70 WP'}),
    _PriceEntry(1080.00, {'Armor', 'Amor', 'ARMOR'}),
    _PriceEntry(727.92, {'Armure', 'Armure 250ML', 'ARMURE 300 EC'}),
    _PriceEntry(1850.00, {'Benomax', 'Benomax/Box'}),
    _PriceEntry(943.80, {'Daconil', 'Daconi', 'DACONIL 720 SC'}),
    _PriceEntry(513.91, {'Dithane', 'Dithame'}),
    _PriceEntry(602.06, {'Dithane M45', 'DITHANE M-45 NEOTEC WP'}),
    _PriceEntry(474.28, {'Fungitox', 'Fungitox/ box'}),
    _PriceEntry(451.48, {'Fungufree'}),
    _PriceEntry(702.71, {'Funguran', 'Funguran/box'}),
    _PriceEntry(760.10, {'Funguran OH'}),
    _PriceEntry(515.00, {'Ganazeb'}),
    _PriceEntry(978.50, {'Kocide'}),
    _PriceEntry(610.00, {'Manager'}),
    _PriceEntry(388.17, {'Manzate', 'Mangat'}),
    _PriceEntry(1199.88, {'Nordox', 'Nandox'}),
    _PriceEntry(400.00, {'Redeem'}),
    _PriceEntry(1278.25, {'Tango 70WP', 'TANGO 70 WP'}),
    _PriceEntry(589.44, {'Topsin', 'TOPSIN-M 70 WP'}),
    _PriceEntry(1013.76, {'Bayluscide', 'BAYLUSCIDE 250 EC', 'BAYLUSCIDE 50 WP'}),
    _PriceEntry(320.84, {'Bayonet', 'BAYONET 6% PELLETS'}),
    _PriceEntry(515.62, {'Cimarron', 'Cmarron'}),
    _PriceEntry(604.63, {'Hit'}),
    _PriceEntry(881.75, {'Hit 700WP'}),
    _PriceEntry(1000.00, {'Maskada'}),
    _PriceEntry(634.00, {'Moluxide'}),
    _PriceEntry(510.75, {'Niclomax', 'Nicloma'}),
    _PriceEntry(746.77, {'Parakuhol'}),
    _PriceEntry(882.50, {'Primalex'}),
    _PriceEntry(982.50, {'Shatter', 'Shatte', 'SHATTER 70 WP'}),
    _PriceEntry(912.42, {'Snail Free', 'SNAIL FREE 250 EC', 'SNAIL FREE 70 WP'}),
    _PriceEntry(724.16, {'Snailmate 70WP', 'SNAILMATE 70 WP'}),
    _PriceEntry(430.42, {'Snailkill', 'SNAILKIL 6% P'}),
    _PriceEntry(707.61, {'Surekill', 'SurekiH', 'SUREKILL 70 WP'}),
    _PriceEntry(775.00, {'Tagluscide'}),
    _PriceEntry(29.74, {'Viso-Bait', 'Viso-Balt'}),
    _PriceEntry(50.95, {'Racumin', 'Racumin/50g', 'RACUMIN DUST'}),
    _PriceEntry(27.50, {'Ratol'}),
    _PriceEntry(23.33, {'Rat-X', 'Rat-X/sachet'}),
    _PriceEntry(29.74, {'Storm', 'Storm/sachet'}),
    _PriceEntry(25.76, {'Zinc Phosphide', 'Zinc Phosphide/sachet'}),
    _PriceEntry(326.88, {'Super M', 'SUPER M 5 EC'}),
  ];

  final aliasToCost = <String, double>{};
  for (final entry in priceEntries) {
    for (final alias in entry.aliases) {
      aliasToCost[_normalize(alias)] = entry.cost;
    }
  }

  final rows = await db.query(
    'DefSup',
    where: 'UPPER(type) LIKE ? OR UPPER(type) LIKE ?',
    whereArgs: ['%PEST%', '%HERB%'],
  );

  for (final row in rows) {
    final id = row['id']?.toString() ?? '';
    final name = row['name']?.toString() ?? '';
    final normalizedName = _normalize(name);
    final matchedCost = aliasToCost[normalizedName];
    if (id.isEmpty || matchedCost == null) {
      continue;
    }

    await db.update(
      'DefSup',
      {'Cost': matchedCost},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  await db.close();
}
