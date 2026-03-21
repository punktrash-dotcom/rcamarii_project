import '../models/schedule_alert_model.dart';

enum GuidelineLanguage { english, tagalog, visayan }

class GuidelineLocalizationService {
  static String languageLabel(GuidelineLanguage language) {
    switch (language) {
      case GuidelineLanguage.english:
        return 'English';
      case GuidelineLanguage.tagalog:
        return 'Tagalog';
      case GuidelineLanguage.visayan:
        return 'Visayan';
    }
  }

  static String ui(GuidelineLanguage language, String key) {
    return _uiCopy[language]?[key] ??
        _uiCopy[GuidelineLanguage.english]![key] ??
        key;
  }

  static String cropLabel(String cropType, GuidelineLanguage language) {
    final normalized = cropType.trim().toLowerCase();
    if (normalized.contains('sugar')) {
      return switch (language) {
        GuidelineLanguage.english => 'Sugarcane',
        GuidelineLanguage.tagalog => 'Tubo',
        GuidelineLanguage.visayan => 'Tubo',
      };
    }
    if (normalized.contains('rice') || normalized.contains('palay')) {
      return switch (language) {
        GuidelineLanguage.english => 'Rice',
        GuidelineLanguage.tagalog => 'Palay',
        GuidelineLanguage.visayan => 'Humay',
      };
    }
    if (normalized.contains('corn') || normalized.contains('maize')) {
      return switch (language) {
        GuidelineLanguage.english => 'Corn',
        GuidelineLanguage.tagalog => 'Mais',
        GuidelineLanguage.visayan => 'Mais',
      };
    }
    return cropType;
  }

  static String categoryLabel(String category, GuidelineLanguage language) {
    switch (category) {
      case 'Fertilizer':
        return switch (language) {
          GuidelineLanguage.english => 'Fertilizer',
          GuidelineLanguage.tagalog => 'Abono',
          GuidelineLanguage.visayan => 'Abono',
        };
      case 'Herbicide':
        return switch (language) {
          GuidelineLanguage.english => 'Herbicide',
          GuidelineLanguage.tagalog => 'Herbisidyo',
          GuidelineLanguage.visayan => 'Herbisidyo',
        };
      case 'Pesticide':
        return switch (language) {
          GuidelineLanguage.english => 'Pesticide',
          GuidelineLanguage.tagalog => 'Pestisidyo',
          GuidelineLanguage.visayan => 'Pestisidyo',
        };
      case 'Planning':
        return switch (language) {
          GuidelineLanguage.english => 'Planning',
          GuidelineLanguage.tagalog => 'Pagpaplano',
          GuidelineLanguage.visayan => 'Plano',
        };
      default:
        return category;
    }
  }

  static String statusLabel(String status, GuidelineLanguage language) {
    switch (status) {
      case 'NOW':
        return switch (language) {
          GuidelineLanguage.english => 'NOW',
          GuidelineLanguage.tagalog => 'NGAYON',
          GuidelineLanguage.visayan => 'KARON',
        };
      case 'NEXT':
        return switch (language) {
          GuidelineLanguage.english => 'NEXT',
          GuidelineLanguage.tagalog => 'SUSUNOD',
          GuidelineLanguage.visayan => 'SUNOD',
        };
      case 'DONE':
        return switch (language) {
          GuidelineLanguage.english => 'DONE',
          GuidelineLanguage.tagalog => 'TAPOS',
          GuidelineLanguage.visayan => 'NAHUMAN',
        };
      case 'UPCOMING':
        return switch (language) {
          GuidelineLanguage.english => 'UPCOMING',
          GuidelineLanguage.tagalog => 'PAPARATING',
          GuidelineLanguage.visayan => 'UMAABOT',
        };
      default:
        return status;
    }
  }

  static ScheduleAlert translateAlert(
    ScheduleAlert alert,
    GuidelineLanguage language,
  ) {
    if (language == GuidelineLanguage.english) {
      return alert;
    }

    final copy = _alertCopy[language]?[_alertKey(
      alert.title,
      alert.startDay,
      alert.endDay,
    )];
    if (copy == null) {
      return alert;
    }

    return ScheduleAlert(
      title: copy.title,
      message: copy.message,
      startDay: alert.startDay,
      endDay: alert.endDay,
      icon: alert.icon,
      color: alert.color,
    );
  }

  static String _alertKey(String title, int startDay, int endDay) =>
      '$title|$startDay|$endDay';

  static final Map<GuidelineLanguage, Map<String, String>> _uiCopy = {
    GuidelineLanguage.english: {
      'guideline_language': 'Guideline Language',
      'price_list_title': 'Most Recent Price List',
      'guide_title': 'Guide On What To Buy',
      'timeline_title': 'Application Timeline',
      'choose_farm_to_focus': 'Choose a farm to focus the catalog',
      'needs_selected_farm': 'Needs a selected farm',
      'open_catalog_help':
          'Open the catalog browser below to review fertilizers, herbicides, and pesticides.',
      'select_farm_guide':
          "Select a farm first so the guide can follow that crop's current age and stage.",
      'pick_farm_timeline':
          'Pick a farm to show its crop timeline and the next field-application windows.',
      'no_exact_stage_match':
          'No exact stage match. The guide uses the nearest advice window.',
      'no_recommendation':
          'No crop-specific recommendation is available for this farm yet.',
      'tap_open_catalog':
          'Tap the button to open the embedded catalog browser.',
      'supplies_tab': 'Supplies',
      'equipment_tab': 'Equipment',
      'database': 'Database',
      'most_recent': 'Most Recent',
      'list': 'List',
    },
    GuidelineLanguage.tagalog: {
      'guideline_language': 'Wika ng Gabay',
      'price_list_title': 'Pinakabagong Listahan ng Presyo',
      'guide_title': 'Gabay sa Dapat Bilhin',
      'timeline_title': 'Iskedyul ng Paglalagay',
      'choose_farm_to_focus': 'Pumili ng bukid para matutukan ang katalogo',
      'needs_selected_farm': 'Kailangang may napiling bukid',
      'open_catalog_help':
          'Buksan ang katalogo sa ibaba para makita ang abono, herbisidyo, at pestisidyo.',
      'select_farm_guide':
          'Pumili muna ng bukid para tumugma ang gabay sa edad at yugto ng tanim.',
      'pick_farm_timeline':
          'Pumili ng bukid para makita ang iskedyul ng tanim at susunod na gawain.',
      'no_exact_stage_match':
          'Walang eksaktong tugma sa yugto. Gagamitin ang pinakamalapit na payo.',
      'no_recommendation':
          'Wala pang tiyak na rekomendasyon para sa bukid na ito.',
      'tap_open_catalog':
          'Pindutin ang button para buksan ang katalogo sa ibaba.',
      'supplies_tab': 'Mga Supply',
      'equipment_tab': 'Kagamitan',
      'database': 'Database',
      'most_recent': 'Pinakabagong',
      'list': 'Listahan',
    },
    GuidelineLanguage.visayan: {
      'guideline_language': 'Pinulongan sa Giya',
      'price_list_title': 'Pinakabag-ong Lista sa Presyo',
      'guide_title': 'Giya sa Angay Paliton',
      'timeline_title': 'Timeline sa Aplikasyon',
      'choose_farm_to_focus': 'Pilia ang umahan aron matutokan ang katalogo',
      'needs_selected_farm': 'Kinahanglan og napiling umahan',
      'open_catalog_help':
          'Ablihi ang katalogo sa ubos aron makita ang abono, herbicide, ug pesticide.',
      'select_farm_guide':
          'Pili una og umahan aron ang giya mosunod sa edad ug yugto sa tanom.',
      'pick_farm_timeline':
          'Pili og umahan aron makita ang timeline sa tanom ug sa sunod nga mga buluhaton.',
      'no_exact_stage_match':
          'Walay eksaktong tugma sa yugto. Gamiton ang labing duol nga tambag.',
      'no_recommendation':
          'Wala pay piho nga rekomendasyon para niining umahana.',
      'tap_open_catalog':
          'Pislita ang button aron maablihan ang katalogo sa ubos.',
      'supplies_tab': 'Supply',
      'equipment_tab': 'Kagamitan',
      'database': 'Database',
      'most_recent': 'Pinakabag-ong',
      'list': 'Lista',
    },
  };

  static final Map<GuidelineLanguage, Map<String, _LocalizedAlertCopy>>
      _alertCopy = {
    GuidelineLanguage.tagalog: {
      _alertKey('Herbicide Application', 5, 10): const _LocalizedAlertCopy(
        title: 'Paglalagay ng Herbicide',
        message:
            'Mainam ang panahong ito para maglagay ng post-emergence herbicide laban sa damo.',
      ),
      _alertKey('First Fertilizer Application', 10, 15):
          const _LocalizedAlertCopy(
        title: 'Unang Pag-aabono',
        message:
            'Ilagay ang basal fertilizer gaya ng NPK para sa maagang paglago.',
      ),
      _alertKey('Top-Dressing Fertilizer', 30, 40): const _LocalizedAlertCopy(
        title: 'Top-Dressing na Abono',
        message:
            'Panahon na para sa Nitrogen fertilizer upang lumakas ang vegetative growth.',
      ),
      _alertKey('Panicle Initiation', 55, 65): const _LocalizedAlertCopy(
        title: 'Pagbuo ng Panicle',
        message:
            'Siguraduhing sapat ang tubig at mag-abono muli kung kailangan dahil kritikal ito sa ani.',
      ),
      _alertKey('Flowering Stage', 70, 85): const _LocalizedAlertCopy(
        title: 'Yugtong Pamumulaklak',
        message:
            'Namumulaklak na ang pananim. Iwasan ang pag-spray ng pesticide maliban kung kailangan.',
      ),
      _alertKey('Harvesting Window', 90, 120): const _LocalizedAlertCopy(
        title: 'Panahon ng Pag-aani',
        message:
            'Maghanda sa pag-aani. Suriin kung 80-85% ng butil ay kulay dayami na.',
      ),
      _alertKey('Planting Season', 0, 30): const _LocalizedAlertCopy(
        title: 'Panahon ng Pagtatanim',
        message:
            'Magandang panahon ito para sa pagtatanim. Ihanda ang bukid at gumamit ng malusog na binhi.',
      ),
      _alertKey('First Fertilizer & Herbicide', 1, 7):
          const _LocalizedAlertCopy(
        title: 'Unang Abono at Herbicide',
        message:
            'Ilagay ang paunang abono at pre-emergence herbicide sa unang linggo ng pagtatanim.',
      ),
      _alertKey('Weeding', 20, 25): const _LocalizedAlertCopy(
        title: 'Pag-aalis ng Damo',
        message:
            'Magbunot o mababaw na kultibasyon para makontrol ang damo nang hindi nasisira ang ugat.',
      ),
      _alertKey('Second Fertilizer (Sidedress)', 30, 45):
          const _LocalizedAlertCopy(
        title: 'Ikalawang Abono (Sidedress)',
        message:
            'Maglagay ng pangalawang Nitrogen fertilizer kapag kasintaas na ng tuhod ang mais.',
      ),
      _alertKey('Tasseling Stage', 45, 55): const _LocalizedAlertCopy(
        title: 'Yugtong Tasseling',
        message:
            'Kritikal ito sa polinasyon. Siguraduhing may sapat na tubig at bantayan ang corn borer.',
      ),
      _alertKey('Green Corn Harvest', 70, 80): const _LocalizedAlertCopy(
        title: 'Ani ng Murang Mais',
        message:
            'Kung green corn ang aanihin, mainam ang yugtong ito para sa pamimitas.',
      ),
      _alertKey('Grain Harvest Window', 100, 120): const _LocalizedAlertCopy(
        title: 'Panahon ng Pag-aani ng Butil',
        message:
            'Para sa tuyong butil, anihin kapag may black layer na sa ilalim ng kernel.',
      ),
      _alertKey('Land Preparation', -15, 0): const _LocalizedAlertCopy(
        title: 'Paghahanda ng Lupa',
        message:
            'Tapusin ang paghahanda ng lupa at siguraduhing pino at maayos ang drainage bago magtanim.',
      ),
      _alertKey('First Weeding & Fertilizer', 30, 45):
          const _LocalizedAlertCopy(
        title: 'Unang Paglilinis ng Damo at Abono',
        message:
            'Panatilihing malinis sa damo ang unang 90 araw at ilagay ang unang abono para pasiglahin ang paglaki.',
      ),
      _alertKey('Hilling-Up', 90, 120): const _LocalizedAlertCopy(
        title: 'Pagtatambak ng Lupa',
        message:
            'Tambakan ng lupa ang puno ng tubo para masuportahan ito at makatulong sa pagpigil ng damo.',
      ),
      _alertKey('Second Fertilizer Application', 120, 150):
          const _LocalizedAlertCopy(
        title: 'Ikalawang Pag-aabono',
        message:
            'Ibigay ang susunod at huling abono para sa tuloy-tuloy na paglaki ng tungkod.',
      ),
      _alertKey('Maturing Stage', 240, 300): const _LocalizedAlertCopy(
        title: 'Yugtong Paghinog',
        message:
            'Bantayan ang peste at tiyaking maayos ang tubig habang papahinog ang tubo.',
      ),
      _alertKey('Harvesting Window', 300, 420): const _LocalizedAlertCopy(
        title: 'Panahon ng Pag-aani',
        message:
            'Karaniwang inaani ang tubo pag 10-14 buwan na. Palatandaan ang paninilaw ng ibabang dahon at pagkatamis ng katas.',
      ),
      _alertKey('Seedling Stage', 0, 14): const _LocalizedAlertCopy(
        title: 'Yugtong Punla',
        message:
            'Panatilihin ang mababaw na tubig at bantayan ang kuhol sa palayan.',
      ),
      _alertKey('Early Tillering', 15, 30): const _LocalizedAlertCopy(
        title: 'Maagang Pagtutiller',
        message:
            'Ilagay ang unang Nitrogen fertilizer at simulan ang pag-aalis ng damo o paglalagay ng herbicide.',
      ),
      _alertKey('Panicle Initiation', 45, 60): const _LocalizedAlertCopy(
        title: 'Pagbuo ng Panicle',
        message:
            'Mag-top dress ng abono at panatilihing tuloy-tuloy ang suplay ng tubig.',
      ),
      _alertKey('Early Growth', 10, 20): const _LocalizedAlertCopy(
        title: 'Maagang Paglago',
        message:
            'Maglagay ng sidedress fertilizer at bantayan ang fall armyworm.',
      ),
      _alertKey('Knee High Stage', 30, 45): const _LocalizedAlertCopy(
        title: 'Yugtong Singtaas ng Tuhod',
        message:
            'Gawin ang hilling-up at ikalawang pag-aabono. Panatilihing malinis sa damo ang bukid.',
      ),
      _alertKey('Land Prep & Setts', 0, 30): const _LocalizedAlertCopy(
        title: 'Paghahanda ng Lupa at Binhi',
        message:
            'Araruhin nang malalim, maglagay ng compost, at ihanda ang mga tudling bago ihiga ang putol na tubo.',
      ),
      _alertKey('Planting & Moisture', 15, 90): const _LocalizedAlertCopy(
        title: 'Pagtatanim at Halumigmig',
        message:
            'Gumamit ng putol na may 2-3 mata, ilatag sa tudling, at panatilihing sapat ang halumigmig nang hindi binabaha.',
      ),
      _alertKey('Fertilizer Timing', 30, 150): const _LocalizedAlertCopy(
        title: 'Iskedyul ng Abono',
        message:
            'Ilagay ang base fertilizer sa pagtatanim at hatiin ang Nitrogen habang maaga ang pagtubo.',
      ),
      _alertKey('Grand Growth & Pests', 90, 240): const _LocalizedAlertCopy(
        title: 'Mabilis na Paglaki at Peste',
        message:
            'Dagdagan ang Potassium para sa tibay ng tungkod at bantayan ang stem borer at iba pang peste.',
      ),
      _alertKey('Ripening & Harvest Prep', 210, 360): const _LocalizedAlertCopy(
        title: 'Paghinog at Paghahanda sa Pag-aani',
        message:
            'Itigil ang Nitrogen mga 2 buwan bago umani, bawasan ang patubig, at ihanda ang pag-aani.',
      ),
      _alertKey('Ratoon Refresh', 300, 480): const _LocalizedAlertCopy(
        title: 'Pag-aalaga ng Ratoon',
        message:
            'Tabasan ang tuod nang mababa at maagang lagyan ng pataba upang lumakas ang susunod na tubo.',
      ),
    },
    GuidelineLanguage.visayan: {
      _alertKey('Herbicide Application', 5, 10): const _LocalizedAlertCopy(
        title: 'Pag-apply og Herbicide',
        message:
            'Maayo kini nga panahon para sa post-emergence herbicide batok sa sagbot.',
      ),
      _alertKey('First Fertilizer Application', 10, 15):
          const _LocalizedAlertCopy(
        title: 'Unang Pag-abono',
        message:
            'Ibutang ang unang basal fertilizer sama sa NPK aron kusog ang sayong pagtubo.',
      ),
      _alertKey('Top-Dressing Fertilizer', 30, 40): const _LocalizedAlertCopy(
        title: 'Top-Dressing nga Abono',
        message:
            'Panahon na para sa Nitrogen fertilizer aron mosiga ang vegetative growth.',
      ),
      _alertKey('Panicle Initiation', 55, 65): const _LocalizedAlertCopy(
        title: 'Pagsugod sa Panicle',
        message:
            'Siguroa nga igo ang tubig ug magdugang og abono kung gikinahanglan kay kritikal kini sa ani.',
      ),
      _alertKey('Flowering Stage', 70, 85): const _LocalizedAlertCopy(
        title: 'Yugto sa Pagpamiyuos',
        message:
            'Namiyuos na ang tanom. Likayi ang pesticide spray gawas kung tinuod nga kinahanglan.',
      ),
      _alertKey('Harvesting Window', 90, 120): const _LocalizedAlertCopy(
        title: 'Panahon sa Pag-ani',
        message:
            'Andama ang pag-ani. Susiha kung 80-85% sa liso kay kolor dayami na.',
      ),
      _alertKey('Planting Season', 0, 30): const _LocalizedAlertCopy(
        title: 'Panahon sa Pagtanom',
        message:
            'Maayo kini nga panahon sa pagtanom. Andama ang umahan ug gamita ang himsog nga binhi.',
      ),
      _alertKey('First Fertilizer & Herbicide', 1, 7):
          const _LocalizedAlertCopy(
        title: 'Unang Abono ug Herbicide',
        message:
            'Ibutang ang unang abono ug pre-emergence herbicide sulod sa unang semana sa pagtanom.',
      ),
      _alertKey('Weeding', 20, 25): const _LocalizedAlertCopy(
        title: 'Paglimpyo sa Sagbot',
        message:
            'Magbunot o maghimo og mabaw nga kultibasyon aron makontrol ang sagbot nga dili madaot ang gamot.',
      ),
      _alertKey('Second Fertilizer (Sidedress)', 30, 45):
          const _LocalizedAlertCopy(
        title: 'Ikaduhang Abono (Sidedress)',
        message:
            'Ibutang ang ikaduhang Nitrogen fertilizer kung singtaas na sa tuhod ang mais.',
      ),
      _alertKey('Tasseling Stage', 45, 55): const _LocalizedAlertCopy(
        title: 'Yugto sa Tasseling',
        message:
            'Kritikal kini sa polinasyon. Siguroa nga igo ang tubig ug bantayi ang corn borer.',
      ),
      _alertKey('Green Corn Harvest', 70, 80): const _LocalizedAlertCopy(
        title: 'Pag-ani sa Hilaw nga Mais',
        message:
            'Kung green corn ang anihon, maayong bintana kini para sa pamupo.',
      ),
      _alertKey('Grain Harvest Window', 100, 120): const _LocalizedAlertCopy(
        title: 'Panahon sa Pag-ani sa Lugas',
        message:
            'Para sa uga nga lugas, aniha kung naa na ang black layer sa ilawom sa kernel.',
      ),
      _alertKey('Land Preparation', -15, 0): const _LocalizedAlertCopy(
        title: 'Pag-andam sa Yuta',
        message:
            'Kompletoha ang pag-andam sa yuta ug siguroa nga pino ug maayo ang drainage sa dili pa motanom.',
      ),
      _alertKey('First Weeding & Fertilizer', 30, 45):
          const _LocalizedAlertCopy(
        title: 'Unang Paglimpyo sa Sagbot ug Abono',
        message:
            'Pabiling limpyo sa sagbot ang unang 90 ka adlaw ug ibutang ang unang abono aron paspas motubo.',
      ),
      _alertKey('Hilling-Up', 90, 120): const _LocalizedAlertCopy(
        title: 'Pagtambak sa Yuta',
        message:
            'Tambaki og yuta ang punoan sa tubo aron masuportahan kini ug makatabang sa pagpugong sa sagbot.',
      ),
      _alertKey('Second Fertilizer Application', 120, 150):
          const _LocalizedAlertCopy(
        title: 'Ikaduhang Pag-abono',
        message:
            'Ihatag ang sunod ug katapusang abono para sa padayon nga pagtubo sa tukog.',
      ),
      _alertKey('Maturing Stage', 240, 300): const _LocalizedAlertCopy(
        title: 'Yugto sa Pagkahinog',
        message:
            'Bantayi ang peste ug siguroa nga husto ang tubig samtang nagkahinog ang tubo.',
      ),
      _alertKey('Harvesting Window', 300, 420): const _LocalizedAlertCopy(
        title: 'Panahon sa Pag-ani',
        message:
            'Kasagaran anihon ang tubo kung 10-14 ka bulan na. Timailhan ang pagdilaw sa ubos nga dahon ug katam-is sa duga.',
      ),
      _alertKey('Seedling Stage', 0, 14): const _LocalizedAlertCopy(
        title: 'Yugto sa Punla',
        message: 'Pabiling mabaw ang tubig ug bantayi ang kuhol sa humayan.',
      ),
      _alertKey('Early Tillering', 15, 30): const _LocalizedAlertCopy(
        title: 'Sayong Tillering',
        message:
            'Ibutang ang unang Nitrogen fertilizer ug sugdi ang paglimpyo sa sagbot o pag-apply og herbicide.',
      ),
      _alertKey('Panicle Initiation', 45, 60): const _LocalizedAlertCopy(
        title: 'Pagsugod sa Panicle',
        message:
            'Mag-top dress og abono ug pabiling tuloy-tuloy ang suplay sa tubig.',
      ),
      _alertKey('Early Growth', 10, 20): const _LocalizedAlertCopy(
        title: 'Sayong Pagtubo',
        message:
            'Magbutang og sidedress fertilizer ug bantayi ang fall armyworm.',
      ),
      _alertKey('Knee High Stage', 30, 45): const _LocalizedAlertCopy(
        title: 'Yugto nga Singtaas sa Tuhod',
        message:
            'Buhata ang hilling-up ug ikaduhang pag-abono. Pabiling walay sagbot ang umahan.',
      ),
      _alertKey('Land Prep & Setts', 0, 30): const _LocalizedAlertCopy(
        title: 'Pag-andam sa Yuta ug Binhi',
        message:
            'Daruh-a pag-ayo ang yuta, butangi og compost, ug andama ang mga tudling sa dili pa ibutang ang putol nga tubo.',
      ),
      _alertKey('Planting & Moisture', 15, 90): const _LocalizedAlertCopy(
        title: 'Pagtanom ug Kaumog',
        message:
            'Gamita ang putol nga adunay 2-3 ka mata, ipahigda sa tudling, ug pabiling igo ang kaumog nga dili mabahaan.',
      ),
      _alertKey('Fertilizer Timing', 30, 150): const _LocalizedAlertCopy(
        title: 'Iskedyul sa Abono',
        message:
            'Ibutang ang basal fertilizer sa pagtanom ug bahin-bahina ang Nitrogen samtang sayo pa ang pagtubo.',
      ),
      _alertKey('Grand Growth & Pests', 90, 240): const _LocalizedAlertCopy(
        title: 'Dako nga Pagtubo ug Peste',
        message:
            'Dugangi ang Potassium para sa lig-on nga tukog ug bantayi ang stem borer ug uban pang peste.',
      ),
      _alertKey('Ripening & Harvest Prep', 210, 360): const _LocalizedAlertCopy(
        title: 'Pagkahinog ug Andam sa Pag-ani',
        message:
            'Hunonga ang Nitrogen mga 2 ka bulan sa dili pa pag-ani, pakunhod ang tubig, ug andama ang pag-ani.',
      ),
      _alertKey('Ratoon Refresh', 300, 480): const _LocalizedAlertCopy(
        title: 'Pagpabakod sa Ratoon',
        message:
            'Putla og ubos ang tuod ug sayo nga butangi og pataba aron kusgan ang sunod nga tubo.',
      ),
    },
  };
}

class _LocalizedAlertCopy {
  final String title;
  final String message;

  const _LocalizedAlertCopy({
    required this.title,
    required this.message,
  });
}
