import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

final localeProvider = NotifierProvider<LocaleController, String>(
  LocaleController.new,
);

class LocaleController extends Notifier<String> {
  @override
  String build() => ref.read(preferencesProvider).getString('locale') ?? 'kk';
  void set(String value) {
    state = value;
    ref.read(preferencesProvider).setString('locale', value);
  }
}

class Strings {
  const Strings(this.language);
  final String language;
  String get(String key) =>
      _copy[key]?[['kk', 'ru', 'en'].indexOf(language).clamp(0, 2)] ?? key;
  static Strings of(BuildContext context) =>
      Localizations.of<Strings>(context, Strings)!;
}

class StringsDelegate extends LocalizationsDelegate<Strings> {
  const StringsDelegate();
  @override
  bool isSupported(Locale locale) =>
      ['kk', 'ru', 'en'].contains(locale.languageCode);
  @override
  Future<Strings> load(Locale locale) async => Strings(locale.languageCode);
  @override
  bool shouldReload(StringsDelegate old) => false;
}

extension TranslatedContext on BuildContext {
  String t(String key) => Strings.of(this).get(key);
}

const _copy = <String, List<String>>{
  'mapLoading': ['Карта жүктелуде…', 'Загружаем карту…', 'Loading the map…'],
  'mapLoadError': [
    'Құрылғыдағы картаны ашу мүмкін болмады. Қайталап көріңіз.',
    'Не удалось открыть карту на устройстве. Попробуйте ещё раз.',
    'Could not open the map on this device. Try again.',
  ],
  'localWalk': ['Офлайн серуендеу', 'Прогулка офлайн', 'Walk offline'],
  'localMode': [
    'Офлайн · Карта мен маршрут құрылғыда',
    'Офлайн · Карта и маршрут на устройстве',
    'Offline · Map and routes on this device',
  ],
  'offlineMapInfo': [
    'Қызылорданың көшелері, ғимараттары және атаулары қолданбада сақталған. Интернетсіз ашылады.',
    'Улицы, здания и названия Кызылорды уже сохранены в приложении. Карта открывается без интернета.',
    'Kyzylorda streets, buildings and names are bundled with the app. The map opens without internet.',
  ],
  'offlineOutside': [
    'Қызылорда картасынан тыс жердесіз. GPS маршруты жазыла береді.',
    'Вы за пределами карты Кызылорды. GPS-маршрут продолжает записываться.',
    'Outside the Kyzylorda map. GPS recording still works.',
  ],
  'offlineSocial': [
    'Бұл нұсқа офлайн жұмыс істейді. Командалар мен ортақ рейтинг кейін қосылады. Серуендеріңіз құрылғыда сақталады.',
    'Эта версия работает офлайн. Команды и общий рейтинг подключим позже. Ваши прогулки сохраняются на устройстве.',
    'This version works offline. Teams and shared rankings will be connected later. Walks are saved on your device.',
  ],
  'localTeam': [
    'Командаға қосылу үшін аккаунтқа кіріңіз.',
    'Войдите в аккаунт, чтобы присоединиться к команде.',
    'Sign in to join a team.',
  ],
  'locationInfo': [
    'Орныңызды картада көрсету үшін GPS рұқсатын сұраймыз. Үздіксіз жазу тек БАСТАУ басылғаннан кейін қосылады.',
    'Запросим доступ к GPS, чтобы показать ваше положение на карте. Непрерывная запись включается только после БАСТАУ.',
    'Allow GPS to show your position on the map. Continuous recording starts only after START.',
  ],
  'privacyTitle': ['Құпиялық', 'Конфиденциальность', 'Privacy'],
  'privacyPolicy': [
    'GPS пен қадамдар тек өзіңіз бастаған серуен кезінде оқылады. GPS маршруты құрылғыда сақталады; кірген аккаунтыңыз болса, жеке Supabase жазбасына жіберіледі. Басқа қатысушылар маршрутты, туған күніңізді немесе денсаулық деректеріңізді көрмейді. Қадамдар жарнама үшін пайдаланылмайды. Рұқсаттарды телефонның баптауынан қайтарып алуға болады. Бұл әзірлеу нұсқасы: іске қосар алдында оператордың байланыс деректері мен деректерді жою тәртібі қосылады.',
    'GPS и шаги читаются только во время прогулки, которую вы запустили. Маршрут сохраняется на устройстве; при входе в аккаунт синхронизируется с вашей личной записью Supabase. Другие участники не видят маршрут, дату рождения или данные здоровья. Шаги не используются для рекламы. Разрешения можно отозвать в настройках телефона. Это версия для разработки: перед запуском нужно добавить контакты оператора и порядок удаления данных.',
    'GPS and steps are read only during a walk you start. Routes are saved on your device and synced to your private Supabase record when signed in. Other members cannot see your route, date of birth, or health data. Steps are not used for advertising. You can revoke permissions in device settings. This is a development version: operator contact details and data deletion procedures must be added before launch.',
  ],
  'map': ['Карта', 'Карта', 'Map'],
  'activity': ['Белсенділік', 'Активность', 'Activity'],
  'team': ['Команда', 'Команда', 'Team'],
  'ranking': ['Рейтинг', 'Рейтинг', 'Ranking'],
  'profile': ['Профиль', 'Профиль', 'Profile'],
  'city': ['Қызылорда', 'Кызылорда', 'Kyzylorda'],
  'slogan': [
    'Қадам бас. Аумақты иелен.\nӨзіңді жең.',
    'Сделай шаг. Забери территорию.\nПобеди себя.',
    'Take a step. Claim your ground.\nBecome stronger.',
  ],
  'welcomeTitle': [
    'Әр қадам —\nжаңа жеңіс.',
    'Каждый шаг —\nновая победа.',
    'Every step.\nA new victory.',
  ],
  'welcomeBody': [
    'Таңды қозғалыспен баста. Қалаңды аш. Командаңмен бірге күшей.',
    'Начни утро с движения. Открой свой город. Стань сильнее вместе с командой.',
    'Start your morning moving. Explore your city. Grow stronger with your team.',
  ],
  'begin': ['Қосылу', 'Присоединиться', 'Get started'],
  'signIn': ['Кіру', 'Войти', 'Sign in'],
  'signingIn': ['Кіру орындалуда', 'Выполняется вход', 'Signing in'],
  'loginEmail': ['Логин (email)', 'Логин (email)', 'Login (email)'],
  'password': ['Құпиясөз', 'Пароль', 'Password'],
  'showPassword': ['Құпиясөзді көрсету', 'Показать пароль', 'Show password'],
  'hidePassword': ['Құпиясөзді жасыру', 'Скрыть пароль', 'Hide password'],
  'passwordAuthBody': [
    'Әкімші берген логин мен құпиясөзді енгізіңіз.',
    'Введи логин и пароль, которые выдал администратор.',
    'Enter the login and password provided by your administrator.',
  ],
  'adminCreatesAccounts': [
    'Аккаунттарды әкімші жасайды. Кіру деректерін алу немесе құпиясөзді қалпына келтіру үшін оған хабарласыңыз.',
    'Аккаунты создаёт администратор. Для получения доступа или восстановления пароля обратись к нему.',
    'Accounts are created by the administrator. Contact them for access or password recovery.',
  ],
  'invalidLogin': [
    'Логин ретінде дұрыс email енгізіңіз.',
    'Введи корректный email в поле логина.',
    'Enter a valid email address as your login.',
  ],
  'passwordRequired': [
    'Құпиясөзді енгізіңіз.',
    'Введи пароль.',
    'Enter your password.',
  ],
  'incorrectLogin': [
    'Логин немесе құпиясөз қате.',
    'Неверный логин или пароль.',
    'Incorrect login or password.',
  ],
  'accountNotReady': [
    'Аккаунт әлі расталмаған. Әкімшіге хабарласыңыз.',
    'Аккаунт ещё не подтверждён. Обратись к администратору.',
    'This account is not confirmed yet. Contact your administrator.',
  ],
  'tooManyAttempts': [
    'Кіру әрекеттері тым көп. Кейінірек қайталаңыз.',
    'Слишком много попыток входа. Попробуй позже.',
    'Too many sign-in attempts. Try again later.',
  ],
  'demo': ['Демо режим', 'Демо-режим', 'Demo mode'],
  'exploreDemo': ['Демо режимді көру', 'Посмотреть демо', 'Explore the demo'],
  'demoNotice': [
    'Демо: маршрут пен көрсеткіштер үлгі ретінде берілген.',
    'Демо: маршрут и показатели приведены для примера.',
    'Demo: routes and stats are simulated.',
  ],
  'auth': ['Алғашқы қадамың.', 'Твой первый шаг.', 'Your first step.'],
  'authBody': [
    'Кіру үшін бір реттік код жібереміз.',
    'Отправим одноразовый код для входа.',
    'We’ll send a one-time sign-in code.',
  ],
  'phone': ['Телефон нөмірі', 'Номер телефона', 'Phone number'],
  'email': ['Email', 'Email', 'Email'],
  'authEmailBody': [
    'Кіру сілтемесін email-ге жібереміз.',
    'Отправим ссылку для входа на email.',
    'We will email you a sign-in link.',
  ],
  'emailSentBody': [
    'Осы телефондағы хатты ашып, кіру сілтемесін басыңыз. Қосымша автоматты түрде ашылады.',
    'Открой письмо на этом телефоне и нажми ссылку входа. Приложение откроется автоматически.',
    'Open the email on this phone and tap the sign-in link. The app will open automatically.',
  ],
  'checkEmail': ['Поштаны тексеріңіз', 'Проверь почту', 'Check your email'],
  'sendLink': ['Сілтеме жіберу', 'Отправить ссылку', 'Send link'],
  'enterEmailCode': ['Менде код бар', 'У меня есть код', 'I have a code'],
  'useEmailLink': [
    'Сілтеме арқылы кіру',
    'Войти по ссылке',
    'Use the email link',
  ],
  'sendCode': ['Код жіберу', 'Отправить код', 'Send code'],
  'code': ['Растау коды', 'Код подтверждения', 'Verification code'],
  'verify': ['Растау', 'Подтвердить', 'Verify'],
  'changeContact': [
    'Нөмірді / email өзгерту',
    'Изменить номер / email',
    'Change phone / email',
  ],
  'configureBackend': [
    'Кіру үшін Supabase баптауы қажет. Әзірге демо режимді көріңіз.',
    'Для входа нужно настроить Supabase. Пока можно посмотреть демо.',
    'Configure Supabase to enable sign-in. You can explore the demo now.',
  ],
  'invalidContact': [
    'Дұрыс телефон нөмірін немесе email енгізіңіз.',
    'Введите корректный номер телефона или email.',
    'Enter a valid phone number or email.',
  ],
  'invalidCode': [
    'Кодты толық енгізіңіз.',
    'Введите код полностью.',
    'Enter the complete code.',
  ],
  'authError': [
    'Кіру орындалмады. Байланысты тексеріп, қайталап көріңіз.',
    'Не удалось войти. Проверь соединение и попробуй ещё раз.',
    'Could not sign in. Check your connection and try again.',
  ],
  'profileSetup': ['Танысайық.', 'Давай знакомиться.', 'Make it yours.'],
  'name': ['Атыңыз', 'Имя', 'Name'],
  'username': ['Username', 'Username', 'Username'],
  'save': ['Сақтау', 'Сохранить', 'Save'],
  'required': [
    'Бұл өрісті толтырыңыз',
    'Заполните это поле',
    'This field is required',
  ],
  'usernameHint': [
    '3–24 таңба: a–z, 0–9, _',
    '3–24 символа: a–z, 0–9, _',
    '3–24 characters: a–z, 0–9, _',
  ],
  'saveError': [
    'Сақталмады. Username бос емес болуы мүмкін.',
    'Не удалось сохранить. Возможно, username уже занят.',
    'Could not save. The username may already be taken.',
  ],
  'photo': ['Фото қосу', 'Добавить фото', 'Add photo'],
  'birthDate': [
    'Туған күні (міндетті емес)',
    'Дата рождения (необязательно)',
    'Date of birth (optional)',
  ],
  'gender': [
    'Жынысы (міндетті емес)',
    'Пол (необязательно)',
    'Gender (optional)',
  ],
  'unspecified': ['Көрсетілмеген', 'Не указан', 'Prefer not to say'],
  'male': ['Ер', 'Мужской', 'Male'],
  'female': ['Әйел', 'Женский', 'Female'],
  'joinTitle': ['Бірге мықтымыз.', 'Вместе мы сильнее.', 'Stronger together.'],
  'joinBody': [
    'Қызылорданың алғашқы командасына қосыл. Әр қадамың ортақ жеңіске үлес қосады.',
    'Присоединяйся к первой команде Кызылорды. Каждый шаг приближает общую победу.',
    'Join Kyzylorda’s first team. Every step contributes to a shared victory.',
  ],
  'join': ['Командаға қосылу', 'Вступить в команду', 'Join the team'],
  'goodMorning': ['Қайырлы таң,', 'Доброе утро,', 'Good morning,'],
  'today': ['Бүгін', 'Сегодня', 'Today'],
  'steps': ['қадам', 'шагов', 'steps'],
  'distance': ['Қашықтық', 'Расстояние', 'Distance'],
  'km': ['км', 'км', 'km'],
  'area': ['Аумақ', 'Территория', 'Territory'],
  'captured': ['Иеленген аумақ', 'Захваченная территория', 'Claimed territory'],
  'start': ['БАСТАУ', 'БАСТАУ', 'START'],
  'startHint': [
    'Таңғы серуенді баста',
    'Начни утреннюю прогулку',
    'Start your morning walk',
  ],
  'finish': ['АЯҚТАУ', 'АЯҚТАУ', 'FINISH'],
  'finishHint': [
    'Серуенді сақтап, аяқтау',
    'Завершить и сохранить прогулку',
    'Finish and save your walk',
  ],
  'live': ['Серуен жүріп жатыр', 'Прогулка идёт', 'Walk in progress'],
  'gpsWaiting': [
    'GPS сигналы күтілуде…',
    'Ожидаем сигнал GPS…',
    'Waiting for GPS…',
  ],
  'gpsError': [
    'GPS үзіліп қалды. Жазбаны сақтап аяқтауға болады.',
    'GPS прервался. Можно завершить и сохранить запись.',
    'GPS was interrupted. You can finish and save your walk.',
  ],
  'gpsReady': ['GPS дайын', 'GPS готов', 'GPS ready'],
  'locate': ['Менің орным', 'Моё местоположение', 'My location'],
  'layers': ['Карта қабаттары', 'Слои карты', 'Map layers'],
  'legend': ['Командалар аумағы', 'Территории команд', 'Team territories'],
  'free': ['Бос аумақ', 'Свободная территория', 'Unclaimed'],
  'mapSetup': [
    'Нақты карта үшін Mapbox токенін қосыңыз.',
    'Добавьте токен Mapbox для реальной карты.',
    'Add a Mapbox token for the real map.',
  ],
  'permissionTitle': [
    'Серуенге дайынсың ба?',
    'Готов к прогулке?',
    'Ready to head out?',
  ],
  'permissionBody': [
    'GPS маршрут пен қашықтықты жазады, тек серуен кезінде. Қадамдарды телефонның қадам датчигі санайды. Қозғалыс деректеріне рұқсат беріңіз. Фондық режим экран сөнсе де маршрутты сақтайды.',
    'GPS записывает маршрут и расстояние только во время прогулки. Шаги считает датчик телефона. Разрешите доступ к физической активности. Фоновый режим сохраняет маршрут при выключенном экране.',
    'GPS records your route and distance only during a walk. The phone’s step sensor counts your steps. Allow access to motion activity. Background location keeps your route when the screen is off.',
  ],
  'privacyNote': [
    'Маршрут тек сізге көрінеді. Жария бөлісу осы нұсқада өшірулі.',
    'Маршрут виден только вам. Публичная публикация в этой версии отключена.',
    'Your route is private. Public sharing is disabled in this version.',
  ],
  'allow': ['Рұқсат беру және бастау', 'Разрешить и начать', 'Allow and start'],
  'cancel': ['Болдырмау', 'Отмена', 'Cancel'],
  'locationDenied': [
    'GPS рұқсатын беріңіз немесе телефон баптауын ашыңыз.',
    'Разрешите геолокацию или откройте настройки телефона.',
    'Allow location access or open device settings.',
  ],
  'settings': ['Баптаулар', 'Настройки', 'Settings'],
  'stepsUnavailable': [
    'Қадамдар қолжетімсіз. Қозғалыс рұқсатын тексеріңіз. Телефонда қадам датчигі болмауы мүмкін.',
    'Шаги недоступны. Проверьте разрешение на физическую активность. Возможно, в телефоне нет датчика шагов.',
    'Steps unavailable. Check motion activity permission. This phone may not have a step sensor.',
  ],
  'time': ['Уақыт', 'Время', 'Time'],
  'speed': ['Жылдамдық', 'Скорость', 'Speed'],
  'history': ['Серуендерің', 'Твои прогулки', 'Your walks'],
  'historySubtitle': [
    'Әр таңның өз тарихы бар.',
    'У каждого утра своя история.',
    'Every morning has a story.',
  ],
  'walk': ['Таңғы серуен', 'Утренняя прогулка', 'Morning walk'],
  'emptyHistory': [
    'Алғашқы серуенің осы жерден басталады.',
    'Здесь появится твоя первая прогулка.',
    'Your first walk will appear here.',
  ],
  'saved': ['Сақталды', 'Сохранено', 'Saved'],
  'pending': ['Синхрондау күтілуде', 'Ожидает синхронизации', 'Sync pending'],
  'sync': ['Синхрондау', 'Синхронизировать', 'Sync now'],
  'wellDone': ['ЖАРАЙСЫҢ!', 'ЖАРАЙСЫҢ!', 'WELL DONE!'],
  'resultBody': [
    'Бүгін өзіңнен бір қадам алдасың.',
    'Сегодня ты на шаг сильнее себя вчерашнего.',
    'Today you’re one step stronger.',
  ],
  'returnMap': ['Картаға оралу', 'Вернуться к карте', 'Back to the map'],
  'territoryNext': [
    'Аумақты иелену келесі кезеңде қосылады.',
    'Захват территории будет добавлен на следующем этапе.',
    'Territory capture is coming in the next milestone.',
  ],
  'territoryCaptured': [
    'АУМАҚ АЛЫНДЫ',
    'ТЕРРИТОРИЯ ЗАХВАЧЕНА',
    'TERRITORY CAPTURED',
  ],
  'territoryDefended': [
    'Аумақ нығайтылды',
    'Территория укреплена',
    'Territory reinforced',
  ],
  'territoryAttacked': [
    'Қарсылас аумағына шабуыл',
    'Территория противника атакована',
    'Enemy territory attacked',
  ],
  'cells': ['ұяшық', 'клеток', 'cells'],
  'capturePending': [
    'Аумақ серверде тексерілуде. Интернет қосылғанда нәтиже жаңарады.',
    'Сервер проверяет захват. Результат обновится после подключения к интернету.',
    'The server is checking the capture. Results update when connected.',
  ],
  'captureOnlineOnly': [
    'Ортақ аумақты иелену үшін аккаунтқа кіріңіз.',
    'Войдите в аккаунт для захвата общей территории.',
    'Sign in to capture shared territory.',
  ],
  'captureDisabled': [
    'Аумақты иелену серверде өшірулі.',
    'Захват отключён на сервере.',
    'Capture is disabled on the server.',
  ],
  'captureNoPlayable': [
    'Контур ішінде қолжетімді ұяшық жоқ.',
    'Внутри контура нет доступных игровых клеток.',
    'No playable cells inside this loop.',
  ],
  'captureRequirements': [
    'Жүріп өткен сызықтың кез келген жеріне оралыңыз: 25 м дейін. Контур: кемінде 100 м және 1 000 м².',
    'Вернитесь к любому месту пройденной линии: до 25 м. Контур: от 100 м пути и 1 000 м² площади.',
    'Return within 25 m of any part of your trail. Loop: at least 100 m and 1,000 m².',
  ],
  'territoryLayers': [
    'Жабық контур ішіндегі ұяшықтар команда түсімен боялады.',
    'Клетки внутри замкнутого контура окрашиваются цветом команды.',
    'Cells inside closed loops use their team color.',
  ],
  'days': ['күн', 'дней', 'days'],
  'streak': ['Күнделікті серия', 'Ежедневная серия', 'Daily streak'],
  'morningBonus': ['Таңғы бонус', 'Утренний бонус', 'Morning bonus'],
  'bonusNote': [
    '05:00–06:00 · ×3 XP. Аумақ көлемі өзгермейді.',
    '05:00–06:00 · ×3 XP. Площадь территории не меняется.',
    '05:00–06:00 · ×3 XP. Territory area stays the same.',
  ],
  'members': ['қатысушы', 'участников', 'members'],
  'teamBody': [
    'Бір қала. Бір мақсат.\nМыңдаған қадам.',
    'Один город. Одна цель.\nТысячи шагов.',
    'One city. One goal.\nThousands of steps.',
  ],
  'teamMembers': ['Команда қатысушылары', 'Участники команды', 'Team members'],
  'week': ['Апта', 'Неделя', 'Week'],
  'month': ['Ай', 'Месяц', 'Month'],
  'players': ['Ойыншылар', 'Игроки', 'Players'],
  'teams': ['Командалар', 'Команды', 'Teams'],
  'rankingBody': [
    'Қала қозғалыста. Сен нешіншісің?',
    'Город в движении. На каком месте ты?',
    'The city is moving. Where do you stand?',
  ],
  'noRanking': [
    'Тексерілген нәтижелер әлі жоқ.',
    'Проверенных результатов пока нет.',
    'No verified results yet.',
  ],
  'loadError': [
    'Деректер жүктелмеді. Қайта көріңіз.',
    'Данные не загрузились. Попробуйте снова.',
    'Could not load data. Try again.',
  ],
  'retry': ['Қайта көру', 'Повторить', 'Retry'],
  'level': ['Деңгей', 'Уровень', 'Level'],
  'totalSteps': ['Барлық қадам', 'Всего шагов', 'Total steps'],
  'achievements': ['Жетістіктер', 'Достижения', 'Achievements'],
  'firstWalk': ['Алғашқы қадам', 'Первый шаг', 'First step'],
  'first5k': ['Алғашқы 5 км', 'Первые 5 км', 'First 5 km'],
  'sevenDays': ['7 күн қатарынан', '7 дней подряд', '7 days in a row'],
  'firstCapture': ['Алғашқы аумақ', 'Первый захват', 'First capture'],
  'language': ['Тіл', 'Язык', 'Language'],
  'editProfile': ['Профильді өзгерту', 'Редактировать профиль', 'Edit profile'],
  'signOut': ['Шығу', 'Выйти', 'Sign out'],
  'activeSignOut': [
    'Алдымен серуенді аяқтаңыз.',
    'Сначала завершите прогулку.',
    'Finish your walk first.',
  ],
  'recover': [
    'Аяқталмаған серуен сақталған. Жазбаны аяқтаңыз.',
    'Сохранена незавершённая прогулка. Завершите запись.',
    'An unfinished walk was recovered. Finish to save it.',
  ],
  'localOnly': [
    'Құрылғыда сақталған',
    'Сохранено на устройстве',
    'Saved on this device',
  ],
  'season': ['1 МАУСЫМ · ҚАЗАН', 'СЕЗОН 1 · ОКТЯБРЬ', 'SEASON 1 · OCTOBER'],
  'goal': ['Мақсат: 8 000 қадам', 'Цель: 8 000 шагов', 'Goal: 8,000 steps'],
  'you': ['Сен', 'Ты', 'You'],
};
