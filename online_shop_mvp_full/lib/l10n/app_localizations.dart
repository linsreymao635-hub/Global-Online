import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = [Locale('en'), Locale('km')];

  bool get isKhmer => locale.languageCode == 'km';

  String t(String en) => isKhmer ? (_km[en] ?? en) : en;

  String noProductsFor(String q) => isKhmer
      ? 'រកមិនឃើញផលិតផលសម្រាប់ "$q"'
      : 'No products found for "$q"';
  String oneResult(String q) =>
      isKhmer ? '1 លទ្ធផលសម្រាប់ "$q"' : '1 result for "$q"';
  String nResults(int n, String q) =>
      isKhmer ? '$n លទ្ធផលសម្រាប់ "$q"' : '$n results for "$q"';

  String productDescription(int id, String en) =>
      isKhmer ? (_descKm[id] ?? en) : en;

  String discountLine(String pct, String save) => isKhmer
      ? 'បញ្ចុះតម្លៃ $pct% • សន្សំ \$$save'
      : 'Discount $pct% • Save \$$save';

  String discountAlert(String pct, String save) => isKhmer
      ? 'ផលិតផលនេះមានបញ្ចុះតម្លៃ $pct% ឥឡូវនេះ។ អ្នកអាចសន្សំបាន \$$save។'
      : 'This product has a $pct% discount right now. You save \$$save.';

  static const Map<String, String> _km = {
    'Username': 'ឈ្មោះអ្នកប្រើ',
    'Password': 'ពាក្យសម្ងាត់',
    'Sign In': 'ចូល',
    'Create Account': 'បង្កើតគណនី',
    'Continue as guest': 'បន្តជាភ្ញៀវ',
    'Login failed': 'ការចូលបរាជ័យ',
    'Sign Up': 'ចុះឈ្មោះ',
    'Forgot Password?': 'ភ្លេចពាក្យសម្ងាត់?',
    'Forgot Password': 'ភ្លេចពាក្យសម្ងាត់',
    'Or continue with': 'ឬបន្តជាមួយ',
    'Continue with Google': 'បន្តជាមួយ Google',
    'Continue with Telegram': 'បន្តជាមួយ Telegram',
    'Google sign-in failed': 'ការចូលតាម Google បរាជ័យ',
    'Google sign-in is not configured yet':
        'ការចូលតាម Google មិនទាន់ត្រូវបានកំណត់រចនាសម្ព័ន្ធនៅឡើយទេ',
    'Add your Google Cloud OAuth client ID in Settings → Google Sign-In, or add android/app/google-services.json':
        'បន្ថែម OAuth Client ID របស់ Google Cloud នៅក្នុង ការកំណត់ → ការចូលតាម Google ឬបន្ថែម android/app/google-services.json',
    'Google Sign-In': 'ការចូលតាម Google',
    'Configured': 'បានកំណត់',
    'Not configured': 'មិនទាន់កំណត់',
    'Google Client ID': 'Google Client ID',
    'Paste your Google Cloud OAuth Web client ID here (ends with .apps.googleusercontent.com)':
        'បិទភ្ជាប់ OAuth Web Client ID របស់ Google Cloud នៅទីនេះ (បញ្ចប់ដោយ .apps.googleusercontent.com)',
    'Google client ID saved': 'Google Client ID ត្រូវបានរក្សាទុក',
    'Please enter your client ID': 'សូមបញ្ចូល Client ID របស់អ្នក',
    'Web client ID': 'Web Client ID',
    'Android client ID': 'Android Client ID',
    'Android client ID (optional)': 'Android Client ID (ស្រេចចិត្ត)',
    'Needed on Android so sign-in completes after you pick your Google account':
        'ត្រូវការនៅលើ Android ដើម្បីឱ្យការចូលបានបញ្ចប់ បន្ទាប់ពីអ្នកជ្រើសរើសគណនី Google របស់អ្នក',
    'Usually not needed on Android here':
        'ជាធម្មតាមិនចាំបាច់នៅលើ Android នៅទីនេះទេ',
    'Google account was not accepted':
        'គណនី Google របស់អ្នកមិនត្រូវបានទទួលយកទេ',
    'Your selected Google account cannot finish signing in yet. '
        'Add the Android client ID for this app (package com.example.online_shop_mvp_full and its SHA-1) in Google Cloud Console → Credentials → OAuth client ID → Android, then paste it here so this phone can complete Google sign-in.':
        'គណនី Google ដែលអ្នកបានជ្រើសរើស មិនអាចបញ្ចប់ការចូលនៅឡើយទេ។ '
        'សូមបន្ថែម Android client ID សម្រាប់កម្មវិធីនេះ (package com.example.online_shop_mvp_full និង SHA-1 របស់វា) នៅក្នុង Google Cloud Console → Credentials → OAuth client ID → Android រួចបិទភ្ជាប់នៅទីនេះ ដើម្បីឱ្យទូរស័ព្ទនេះអាចបញ្ចប់ការចូលតាម Google។',
    'Enter client IDs': 'បញ្ចូល Client ID',
    'Telegram login is not configured yet': 'ការចូលតាម Telegram មិនទាន់ត្រូវបានកំណត់រចនាសម្ព័ន្ធនៅឡើយទេ',
    'Create a Telegram bot and set its username in TelegramAuthService':
        'បង្កើត bot របស់ Telegram ហើយកំណត់ឈ្មោះអ្នកប្រើរបស់វានៅក្នុង TelegramAuthService',
    'Telegram sign-in failed': 'ការចូលតាម Telegram បរាជ័យ',
    'Telegram login could not load': 'មិនអាចផ្ទុកការចូលតាម Telegram បានទេ',
    'Check your internet connection and try again.':
        'សូមពិនិត្យការភ្ជាប់អ៊ីនធឺណិតរបស់អ្នក ហើយព្យាយាមម្តងទៀត។',
    'Telegram Sign-In': 'ការចូលតាម Telegram',
    'Telegram bot username': 'ឈ្មោះ bot របស់ Telegram',
    'Telegram bot username looks wrong': 'ឈ្មោះ bot របស់ Telegram មើលទៅខុស',
    'Telegram bot usernames must end with "bot", for example my_shop_bot. '
        'Create a bot in @BotFather, then paste its username.':
        'ឈ្មោះ bot របស់ Telegram ត្រូវតែបញ្ចប់ដោយ "bot" ឧទាហរណ៍ my_shop_bot ។ '
        'បង្កើត bot នៅក្នុង @BotFather បន្ទាប់មកបិទភ្ជាប់ឈ្មោះរបស់វា។',
    'Paste your Telegram bot username (without @). '
        'Create the bot in @BotFather first — it always ends with "bot", e.g. my_shop_bot.':
        'បិទភ្ជាប់ឈ្មោះ bot របស់អ្នក (ដោយគ្មាន @) ។ '
        'បង្កើត bot នៅក្នុង @BotFather ជាមុនសិន — វាតែងតែបញ្ចប់ដោយ "bot" ឧទាហរណ៍ my_shop_bot។',
    'Must end with "bot"': 'ត្រូវតែបញ្ចប់ដោយ "bot"',
    'Needs a bot ending with "bot"': 'ត្រូវការ bot ដែលបញ្ចប់ដោយ "bot"',
    'Fix username': 'កែឈ្មោះ',
    'Try anyway': 'ព្យាយាមដូចគ្នា',
    'Telegram bot username saved': 'ឈ្មោះ bot របស់ Telegram ត្រូវបានរក្សាទុក',
    'Support': 'ជំនួយ',
    'Online': 'តាមអ៊ីនធឺណិត',
    'Type your message…': 'វាយសាររបស់អ្នក…',
    'Typing…': 'កំពុងវាយ…',
    'Send': 'ផ្ញើ',
    'Hello! Welcome to Global Online support. How can I help you today?':
        'សួស្តី! សូមស្វាគមន៍មកកាន់ការគាំទ្រ Global Online។ តើខ្ញុំអាចជួយអ្នកយ៉ាងដូចម្តេចនៅថ្ងៃនេះ?',
    'Ask about orders, shipping, returns or payments, or tap a quick question below.':
        'សួរអំពីការបញ្ជាទិញ ការដឹកជញ្ជូន ការត្រឡប់មកវិញ ឬការទូទាត់ ឬប៉ះសំណួររហ័សខាងក្រោម។',
    'Track my order': 'តាមដានការបញ្ជាទិញរបស់ខ្ញុំ',
    'Shipping and delivery': 'ការដឹកជញ្ជូន និងការប្រគល់',
    'Returns and refunds': 'ការត្រឡប់មកវិញ និងការសងប្រាក់',
    'Payment methods': 'វិធីសាស្ត្រទូទាត់',
    'Contact a human': 'ទាក់ទងអ្នកតំណាង',
    'A human agent will reply here shortly. Meanwhile, tell us your order number to speed things up.':
        'អ្នកតំណាងនឹងឆ្លើយតបក្នុងពេលឆាប់ៗនេះ។ ក្នុងពេលនេះ សូមប្រាប់លេខបញ្ជាទិញរបស់អ្នក ដើម្បីឱ្យកាន់តែលឿន។',
    'You can view order status in Profile → Order History. Invoices are sent to your email, and delivery updates arrive by SMS and Telegram.':
        'អ្នកអាចមើលស្ថានភាពការបញ្ជាទិញនៅក្នុង ប្រវត្តិរូប → ប្រវត្តិការបញ្ជាទិញ។ វិក័យប័ត្រត្រូវបានផ្ញើទៅអ៊ីមែលរបស់អ្នក ហើយការអាប់ដេតការដឹកជញ្ជូនមកដល់តាមសារ SMS និង Telegram។',
    'Shipping takes 2–5 working days. Delivery is free for orders over the minimum and you can follow the courier link from your order details.':
        'ការដឹកជញ្ជូនចំណាយពេល 2–5 ថ្ងៃធ្វើការ។ ការដឹកជញ្ជូនមិនគិតថ្លៃសម្រាប់ការបញ្ជាទិញលើសពីតម្លៃអប្បបរមា ហើយអ្នកអាចតាមដានតំណកន្លែងដឹកជញ្ជូនពីព័ត៌មានលម្អិតនៃការបញ្ជាទិញរបស់អ្នក។',
    'Returns are accepted within 7 days with the item unused and its original packaging. Refunds are processed within 3–5 working days after we receive the item.':
        'ការត្រឡប់មកវិញត្រូវបានទទួលយកក្នុងរយៈពេល 7 ថ្ងៃ ដោយទំនិញមិនបានប្រើប្រាស់ និងមានការវេចខ្ចប់ដើម។ ការសងប្រាក់ត្រូវបានដំណើរការក្នុងរយៈពេល 3–5 ថ្ងៃធ្វើការ បន្ទាប់ពីយើងទទួលបានទំនិញ។',
    'We accept cash on delivery, credit/debit cards, KHQR, and mobile banking. Choose your payment method at checkout.':
        'យើងទទួលយកការបង់ប្រាក់តាមម៉ែតប្រាក់ កាតឥណទាន/ឥណពន្ធ KHQR និងធនាគារឌីជីថល។ ជ្រើសរើសវិធីទូទាត់របស់អ្នកនៅពេលបញ្ជាទិញ។',
    'For login problems, try the Forgot Password link, or sign in with Google or Telegram. Your cart and orders stay saved on this device.':
        'សម្រាប់បញ្ហាការចូល សូមសាកល្បងតំណភ្លេចពាក្យសម្ងាត់ ឬចូលជាមួយ Google ឬ Telegram។ កន្ត្រក និងការបញ្ជាទិញរបស់អ្នកនៅរក្សាទុកលើឧបករណ៍នេះ។',
    'You can save your default shipping address in Profile → My Address. It is prefilled at checkout automatically.':
        'អ្នកអាចរក្សាទុកអាសយដ្ឋានដឹកជញ្ជូនលំនាំដើមរបស់អ្នកនៅក្នុង ប្រវត្តិរូប → អាសយដ្ឋានរបស់ខ្ញុំ។ វាត្រូវបានបំពេញដោយស្វ័យប្រវត្តិនៅពេលបញ្ជាទិញ។',
    'Check the promotions banner on the home page. New coupons are announced there and on our Telegram channel regularly.':
        'សូមពិនិត្យមើលបដាកម្មវិធីផ្សព្វផ្សាយនៅលើទំព័រដើម។ ប័ណ្ណថ្មីៗត្រូវបានប្រកាសនៅទីនោះ និងនៅលើឆានែល Telegram របស់យើងជាប្រចាំ។',
    'Thanks for your message! Our team will reply as soon as possible. In the meantime you can find quick answers in the topics above.':
        'សូមអរគុណសម្រាប់សាររបស់អ្នក! ក្រុមរបស់យើងនឹងឆ្លើយតបឱ្យបានឆាប់តាមដែលអាចធ្វើទៅបាន។ ក្នុងពេលនេះ អ្នកអាចស្វែងរកចម្លើយរហ័សនៅក្នុងប្រធានបទខាងលើ។',
    'Global Online Support': 'ជំនួយ Global Online',
    'Chat Support': 'ជំនួយតាមឆាត',
    'Attach': 'ភ្ជាប់',
    'Hold to record': 'ចុចដើម្បីថតសំឡេង',
    'Microphone permission needed': 'ត្រូវការការអនុញ្ញាតិមីក្រូហ្វូន',
    'Could not start recording': 'មិនអាចចាប់ផ្តើមថតសំឡេងបានទេ',
    'Could not send recording': 'មិនអាចផ្ញើសំឡេងបានទេ',
    'Could not play audio': 'មិនអាចដំណើរការសំឡេងបានទេ',
    'Could not play video': 'មិនអាចដំណើរការវីដេអូបានទេ',
    'Photo from gallery': 'រូបភាពពីវិចិត្រសាល',
    'Video from gallery': 'វីដេអូពីវិចិត្រសាល',
    'Take a photo': 'ថតរូប',
    'Photo attached': 'រូបភាពត្រូវបានភ្ជាប់',
    'Video attached': 'វីដេអូត្រូវបានភ្ជាប់',
    'Recording… tap send to stop and send': 'កំពុងថត… ប៉ះផ្ញើដើម្បីបញ្ឈប់ និងផ្ញើ',
    'For any other questions, please contact our team and we will reply as soon as possible.':
        'សម្រាប់សំណួរផ្សេងទៀត សូមទាក់ទងក្រុមរបស់យើង ហើយយើងនឹងឆ្លើយតបឱ្យបានឆាប់តាមដែលអាចធ្វើទៅបាន។',
    'Continue as': 'បន្តជា',
    'Enter your email to receive a password reset link':
        'សូមបញ្ចូលអ៊ីមែលរបស់អ្នក ដើម្បីទទួលតំណកំណត់ពាក្យសម្ងាត់ឡើងវិញ',
    'Send reset link': 'ផ្ញើតំណកំណត់ឡើងវិញ',
    'Check your email': 'ពិនិត្យមើលអ៊ីមែលរបស់អ្នក',
    'If your email is registered, a reset link was sent to it.':
        'ប្រសិនបើអ៊ីមែលរបស់អ្នកបានចុះឈ្មោះ តំណកំណត់ឡើងវិញត្រូវបានផ្ញើទៅវា។',
    'Please enter your email': 'សូមបញ្ចូលអ៊ីមែលរបស់អ្នក',
    'First name': 'នាមខ្លួន',
    'Last name': 'គោត្រកូល',
    'Email': 'អ៊ីមែល',
    'Confirm password': 'បញ្ជាក់ពាក្យសម្ងាត់',
    'Could not create account': 'មិនអាចបង្កើតគណនីបានទេ',
    'Shop': 'ហាង',
    'Global Online': 'Global Online',
    'More': 'ច្រើនទៀត',
    'Back': 'ត្រឡប់',
    'Already have an account?': 'មានគណនីរួចហើយ?',
    'No account found for this phone number': 'រកមិនឃើញគណនីសម្រាប់លេខទូរស័ព្ទនេះ',
    'Favorites': 'ចំណូលចិត្ត',
    'Remove from favorites': 'ដកចេញពីចំណូលចិត្ត',
    'Categories': 'ប្រភេទ',
    'Order History': 'ប្រវត្តិការបញ្ជាទិញ',
    'Orders': 'ការបញ្ជាទិញ',
    'Profile': 'ប្រវត្តិរូប',
    'Edit Profile': 'កែប្រវត្តិរូប',
    'First Name': 'នាមខ្លួន',
    'Last Name': 'ត្រកូល',
    'Image': 'រូបភាព',
    'Choose from gallery': 'ជ្រើសរើសពីវិចិត្រសាល',
    'Remove photo': 'លុបរូបភាព',
    'Enter image URL': 'បញ្ចូលតំណរូបភាព',
    'Change photo': 'ប្តូររូបថត',
    'Cancel': 'បោះបង់',
    'Could not open the gallery. Please try entering an image URL.':
        'មិនអាចបើកវិចិត្រសាលបានទេ។ សូមព្យាយាមបញ្ចូលតំណរូបភាពជំនួសវិញ។',
    'Settings': 'ការកំណត់',
    'Logout': 'ចាកចេញ',
    'Search products or categories': 'ស្វែងរកផលិតផល ឬប្រភេទ',
    'Search': 'ស្វែងរក',
    'Retry': 'ព្យាយាមម្តងទៀត',
    'No products': 'គ្មានផលិតផល',
    'Product Details': 'ព័ត៌មានផលិតផល',
    'Description': 'ការពិពណ៌នា',
    'Stock': 'ស្តុក',
    'Added to cart': 'បានបន្ថែមទៅកន្ត្រក',
    'Add to Cart': 'បន្ថែមទៅកន្ត្រក',
    'Cart': 'កន្ត្រក',
    'Your cart is empty': 'កន្ត្រករបស់អ្នកទទេ',
    'Total': 'សរុប',
    'Checkout': 'ទូទាត់',
    'Looks like you have no items in your cart yet.':
        'វាហាក់ដូចជាអ្នកមិនទាន់បន្ថែមទំនិញណាមួយក្នុងកន្ត្រកទេ។',
    'Start shopping': 'ចាប់ផ្តើមទិញទំនិញ',
    'Subtotal': 'សរុបរង',
    'Shipping': 'ថ្លៃដឹកជញ្ជូន',
    'Tax': 'ពន្ធ',
    'Free': 'ឥតគិតថ្លៃ',
    'Remove': 'លុប',
    'Clear cart': 'ជម្រះកន្ត្រក',
    'Clear cart?': 'ជម្រះកន្ត្រក?',
    'Remove all items from your cart?': 'លុបទំនិញទាំងអស់ចេញពីកន្ត្រក?',
    'Clear': 'ជម្រះ',
    'Order placed': 'ការបញ្ជាទិញបានជោគជ័យ',
    'Your order was created successfully.':
        'ការបញ្ជាទិញរបស់អ្នកត្រូវបានបង្កើតដោយជោគជ័យ។',
    'OK': 'យល់ព្រម',
    'Delivery Address': 'អាសយដ្ឋានដឹកជញ្ជូន',
    'My Address': 'អាសយដ្ឋានរបស់ខ្ញុំ',
    'Open in Google Maps': 'បើកផែនទី Google',
    'Contact information': 'ព័ត៌មានទំនាក់ទំនង',
    'Add your address below': 'បន្ថែមអាសយដ្ឋានរបស់អ្នកខាងក្រោម',
    'Tap the map to select your delivery location':
        'ចុចលើផែនទីដើម្បីជ្រើសរើសទីតាំងដឹកជញ្ជូនរបស់អ្នក',
    'Use map center': 'ប្រើកណ្តាលផែនទី',
    'Full name': 'ឈ្មោះពេញ',
    'Phone': 'ទូរស័ព្ទ',
    'Enter your phone number to receive a verification code':
        'បញ្ចូលលេខទូរស័ព្ទរបស់អ្នកដើម្បីទទួលកូដផ្ទៀងផ្ទាត់',
    'Send code': 'ផ្ញើកូដ',
    'Verification code': 'កូដផ្ទៀងផ្ទាត់',
    'We sent a code to': 'យើងបានផ្ញើកូដទៅ',
    'Verify code': 'ផ្ទៀងផ្ទាត់កូដ',
    'Please enter a valid phone number':
        'សូមបញ្ចូលលេខទូរស័ព្ទត្រឹមត្រូវ',
    'Wrong code. Check your phone.': 'កូដមិនត្រឹមត្រូវ។ សូមពិនិត្យមើលទូរស័ព្ទរបស់អ្នក',
    'Reset password': 'កំណត់ពាក្យសម្ងាត់ថ្មី',
    'Password reset successful': 'បានកំណត់ពាក្យសម្ងាត់ថ្មីដោយជោគជ័យ',
    'Password must be at least 6 characters':
        'ពាក្យសម្ងាត់ត្រូវតែយ៉ាងហោចណាស់ 6 តួអក្សរ',
    'Address': 'អាសយដ្ឋាន',
    'City': 'ទីក្រុង',
    'Country': 'ប្រទេស',
    'Continue': 'បន្ត',
    'Please complete delivery information':
        'សូមបំពេញព័ត៌មានដឹកជញ្ជូន',
    'Select a category or search': 'ជ្រើសរើសប្រភេទ ឬស្វែងរក',
    'No products found': 'រកមិនឃើញផលិតផល',
    'Price: High to Low': 'តម្លៃ៖ ខ្ពស់ទៅទាប',
    'Price: Low to High': 'តម្លៃ៖ ទាបទៅខ្ពស់',
    '1 Column': 'មួយជួរ',
    '2 Columns': 'ពីរជួរ',
    'Sort': 'តម្រៀប',
    'No favorites': 'គ្មានចំណូលចិត្ត',
    'Sign in to continue shopping': 'ចូលដើម្បីបន្តការទិញទំនិញ',
    'New to Global Online?': 'ថ្មីសម្រាប់ Global Online?',
    'Name': 'ឈ្មោះ',
    'Language': 'ភាសា',
    'English': 'អង់គ្លេស',
    'Khmer': 'ខ្មែរ',
    'No orders yet': 'មិនទាន់មានការបញ្ជាទិញ',
    'Order': 'ការបញ្ជាទិញ',
    'Items': 'ធាតុ',
    'Date': 'កាលបរិច្ឆេទ',
    'beauty': 'សម្រស់',
    'fragrances': 'ទឹកអប់',
    'furniture': 'គ្រឿងសង្ហារឹម',
    'groceries': 'គ្រឿងនំ',
    'home-decoration': 'ការតុបតែងផ្ទះ',
    'kitchen-accessories': 'គ្រឿងផ្ទះបាយ',
    'laptops': 'កុំព្យូទ័រយួរដៃ',
    'mens-shirts': 'អាវបុរស',
    'mens-shoes': 'ស្បែកជើងបុរស',
    'mens-watches': 'នាឡិកាបុរស',
    'mobile-accessories': 'គ្រឿងបន្លាស់ទូរស័ព្ទ',
    'motorcycle': 'ម៉ូតូ',
    'skin-care': 'ការថែរក្សាស្បែក',
    'smartphones': 'ស្មាតហ្វូន',
    'sports-accessories': 'គ្រឿងកីឡា',
    'sunglasses': 'វ៉ែនតា',
    'tablet': 'ថេប្លេត',
    'tops': 'អាវផាយ',
    'vehicle': 'យានយន្ត',
    'womens-bags': 'កាបូបស្ត្រី',
    'womens-dresses': 'រ៉ូបស្ត្រី',
    'womens-jewellery': 'គ្រឿងអលង្កាស្ត្រី',
    'womens-shoes': 'ស្បែកជើងស្ត្រី',
    'womens-watches': 'នាឡិកាស្ត្រី',
    'Beauty': 'សម្រស់',
    'Fragrances': 'ទឹកអប់',
    'Furniture': 'គ្រឿងសង្ហារឹម',
    'Groceries': 'គ្រឿងនំប៉័ង',
    'Home Decoration': 'ការតុបតែងផ្ទះ',
    'Kitchen Accessories': 'គ្រឿងប្រើប្រាស់ផ្ទះបាយ',
    'Laptops': 'កុំព្យូទ័រយួរដៃ',
    'Mens Shirts': 'អាវបុរស',
    'Mens Shoes': 'ស្បែកជើងបុរស',
    'Mens Watches': 'នាឡិកាបុរស',
    'Mobile Accessories': 'គ្រឿងបន្លាស់ទូរស័ព្ទ',
    'Motorcycle': 'ម៉ូតូ',
    'Skin Care': 'ការថែរក្សាស្បែក',
    'Smartphones': 'ស្មាតហ្វូន',
    'Sports Accessories': 'គ្រឿងកីឡា',
    'Sunglasses': 'វ៉ែនតា',
    'Tablets': 'ថេប្លេត',
    'Tops': 'អាវផាយ',
    'Vehicle': 'យានយន្ត',
    'Womens Bags': 'កាបូបស្ត្រី',
    'Womens Dresses': 'រ៉ូបស្ត្រី',
    'Womens Jewellery': 'គ្រឿងអលង្កាស្ត្រី',
    'Womens Shoes': 'ស្បែកជើងស្ត្រី',
    'Womens Watches': 'នាឡិកាស្ត្រី',
    'Light mode': 'របៀបភ្លឺ',
    'Dark mode': 'របៀបងងឹត',
    'Theme': 'របៀប',
    'Notifications': 'ការជូនដំណឹង',
    'Receive discount alerts': 'ទទួលការជូនដំណឹងបញ្ចុះតម្លៃ',
    'Notifications are off. Turn them on in Settings.':
        'ការជូនដំណឹងត្រូវបានបិទ។ សូមបើកវានៅក្នុងការកំណត់។',
    'You will be notified about discounts for this product':
        'អ្នកនឹងទទួលការជូនដំណឹងអំពីការបញ្ចុះតម្លៃសម្រាប់ផលិតផលនេះ',
    'Notification removed for this product':
        'បានដកការជូនដំណឹងចេញសម្រាប់ផលិតផលនេះ',
    'Discount alert': 'ការជូនដំណឹងបញ្ចុះតម្លៃ',
    'Notify me': 'ជូនដំណឹងខ្ញុំ',
    'Save': 'សន្សំ',
    'About Us': 'អំពីពួកយើង',
    'Contact Us': 'ទាក់ទងយើង',
    'FAQs': 'សំណួរញឹកញាប់',
    'Terms & Conditions': 'លក្ខខណ្ឌ និងការប្រើប្រាស់',
    'Privacy Policy': 'គោលការណ៍ឯកជនភាព',
    'Change Password': 'ប្តូរពាក្យសម្ងាត់',
    'Delete Account': 'លុបគណនី',
    'Who We Are': 'ពួកយើងជានរណា',
    'Our Mission': 'បេសកកម្មរបស់យើង',
    'Our Values': 'តម្លៃរបស់យើង',
    'Why Shop With Us': 'ហេតុអ្វីទិញទំនិញជាមួយយើង',
    'Global Online is a modern online marketplace delivering quality products straight to your door in Cambodia. From electronics and fashion to home essentials and groceries, we bring thousands of curated items together in one easy app.':
        'Global Online ជាទីផ្សារអនឡាញទំនើប ដែលបញ្ជូនផលិតផលគុណភាពដល់មាត់ទ្វារអ្នកនៅកម្ពុជា។ ចាប់ពីគ្រឿងអេឡិចត្រូនិក និងម៉ូដ រហូតដល់របស់ប្រើប្រាស់ក្នុងផ្ទះ និងគ្រឿងឧបភោគភ័ណ្ឌ យើងនាំយកផលិតផលរាប់ពាន់មុខមករួមគ្នាក្នុងកម្មវិធីងាយស្រួលមួយ។',
    'Founded with a simple idea — trustworthy shopping from your phone — we combine fair prices, honest service, and fast delivery.':
        'បង្កើតឡើងដោយគំនិតសាមញ្ញ — ការទិញទំនិញដែលអាចទុកចិត្តបានពីទូរស័ព្ទរបស់អ្នក — យើងរួមបញ្ចូលតម្លៃសមរម្យ សេវាកម្មស្មោះត្រង់ និងការដឹកជញ្ជូនលឿន។',
    'Our mission is to make online shopping simple, safe and enjoyable for everyone. We work directly with suppliers so you get great value with every order.':
        'បេសកកម្មរបស់យើងគឺធ្វើឱ្យការទិញទំនិញតាមអនឡាញសាមញ្ញ មានសុវត្ថិភាព និងរីករាយសម្រាប់មនុស្សគ្រប់គ្នា។ យើងធ្វើការផ្ទាល់ជាមួយអ្នកផ្គត់ផ្គង់ ដើម្បីឱ្យអ្នកទទួលបានតម្លៃល្អបំផុតជាមួយរាល់ការបញ្ជាទិញ។',
    'Customer first — your happiness drives every decision we make.':
        'អតិថិជនជាអាទិភាព — សុភមង្គលរបស់អ្នកជំរុញរាល់ការសម្រេចចិត្តរបស់យើង។',
    'Honesty — clear prices, real stock and transparent policies.':
        'ភាពស្មោះត្រង់ — តម្លៃច្បាស់លាស់ ស្តុកពិតប្រាកដ និងគោលការណ៍ថ្លា។',
    'Sustainability — we reduce waste and support local partners.':
        'និរន្តរភាព — យើងកាត់បន្ថយកាកសំណល់ និងគាំទ្រដៃគូក្នុងស្រុក។',
    'Innovation — we keep improving the app around your needs.':
        'ការច្នៃប្រឌិត — យើងបន្តកែលម្អកម្មវិធីឱ្យសមនឹងតម្រូវការរបស់អ្នក។',
    'Fast, tracked delivery across Cambodia.':
        'ការដឹកជញ្ជូនលឿន និងតាមដានបានទូទាំងកម្ពុជា។',
    'Flexible payment: cash on delivery, cards, KHQR and mobile banking.':
        'ការទូទាត់បត់បែន៖ បង់ប្រាក់ពេលទទួលទំនិញ កាត ខេអេសខេអរ (KHQR) និងធនាគារឌីជីថល។',
    'Friendly support on chat, phone and Telegram.':
        'ការគាំទ្រមិត្តភាពតាមឆាត ទូរស័ព្ទ និង Telegram។',
    'Easy returns within 7 days of delivery.':
        'ការត្រឡប់ទំនិញងាយស្រួលក្នុងរយៈពេល 7 ថ្ងៃបន្ទាប់ពីទទួល។',
    'Get in touch': 'ទាក់ទងមកយើង',
    'Call': 'ហៅ',
    'Open map': 'បើកផែនទី',
    'Working hours': 'ម៉ោងបម្រើការ',
    'Monday – Sunday, 8:00 AM – 20:00 PM': 'ច័ន្ទ – អាទិត្យ 8:00 AM – 20:00 PM',
    'Faster help': 'ជំនួយលឿនជាងមុន',
    'We would love to hear from you. Reach out any time — our team replies as fast as possible.':
        'យើងរីករាយនឹងបានស្តាប់មតិពីអ្នក។ ទាក់ទងមកយើងបានគ្រប់ពេល — ក្រុមរបស់យើងឆ្លើយតបឱ្យបានលឿនតាមដែលអាចធ្វើទៅបាន។',
    'For order status, shipping questions and returns, check the FAQ or open Chat Support — our assistant answers instantly.':
        'សម្រាប់ស្ថានភាពការបញ្ជាទិញ ការដឹកជញ្ជូន និងការត្រឡប់ទំនិញ សូមពិនិត្យមើល FAQs ឬបើកការគាំទ្រតាមឆាត — ជំនួយការរបស់យើងឆ្លើយភ្លាមៗ។',
    'Send us an email': 'ផ្ញើអ៊ីមែលមកយើង',
    'Call us now': 'ហៅយើងឥឡូវនេះ',
    'Telegram': 'តេឡេក្រាម',
    'Facebook': 'ហ្វេសប៊ុក',
    'Open': 'បើក',
    'Leave a message': 'ទុកសារមួយ',
    'Thanks! We will get back to you soon.':
        'អរគុណ! យើងនឹងត្រឡប់មកទាក់ទងអ្នកវិញឆាប់ៗនេះ។',
    '1. Overview': '១. ទិដ្ឋភាពទូទៅ',
    'By using the Global Online application you agree to these terms. If you do not agree, please do not use the app. We may update these terms from time to time, and continued use means you accept the latest version.':
        'ដោយការប្រើប្រាស់កម្មវិធី Global Online អ្នកយល់ព្រមនឹងលក្ខខណ្ឌទាំងនេះ។ ប្រសិនបើអ្នកមិនយល់ព្រមទេ សូមកុំប្រើប្រាស់កម្មវិធីនេះ។ យើងអាចធ្វើបច្ចុប្បន្នភាពលក្ខខណ្ឌទាំងនេះតាមពេលវេលា ហើយការបន្តប្រើប្រាស់មានន័យថា អ្នកទទួលយកកំណែចុងក្រោយបំផុត។',
    '2. Orders & Payment': '២. ការបញ្ជាទិញ និងការទូទាត់',
    'All prices are shown in US dollars and include applicable taxes. An order is confirmed once you complete checkout. We accept cash on delivery, credit and debit cards, KHQR and mobile banking.':
        'តម្លៃទាំងអស់បង្ហាញជាដុល្លារអាមេរិក និងរួមបញ្ចូលពន្ធអនុវត្ត។ ការបញ្ជាទិញត្រូវបានបញ្ជាក់នៅពេលអ្នកបញ្ចប់ការទូទាត់។ យើងទទួលយកការបង់ប្រាក់ពេលទទួលទំនិញ កាតឥណទាន និងឥណពន្ធ KHQR និងធនាគារឌីជីថល។',
    'We reserve the right to refuse or cancel an order, for example when a product is out of stock or a price error occurred.':
        'យើងរក្សាសិទ្ធិបដិសេធ ឬលុបចោលការបញ្ជាទិញ ឧទាហរណ៍ នៅពេលផលិតផលអស់ស្តុក ឬមានកំហុសតម្លៃ។',
    '3. Shipping & Delivery': '៣. ការដឹកជញ្ជូន និងការប្រគល់',
    'Orders are delivered in 2–5 working days. Delivery is free for orders over the minimum amount. After dispatch you can track your order from Profile → Order History.':
        'ការបញ្ជាទិញត្រូវបានប្រគល់ក្នុងរយៈពេល 2–5 ថ្ងៃធ្វើការ។ ការដឹកជញ្ជូនមិនគិតថ្លៃសម្រាប់ការបញ្ជាទិញលើសពីតម្លៃអប្បបរមា។ បន្ទាប់ពីការផ្ញើចេញ អ្នកអាចតាមដានការបញ្ជាទិញរបស់អ្នកពី ប្រវត្តិរូប → ប្រវត្តិការបញ្ជាទិញ។',
    '4. Returns & Refunds': '៤. ការត្រឡប់ទំនិញ និងការសងប្រាក់',
    'You may return unused items in their original packaging within 7 days. Refunds are processed within 3–5 working days after we receive the returned item.':
        'អ្នកអាចត្រឡប់ទំនិញដែលមិនបានប្រើប្រាស់ ក្នុងការវេចខ្ចប់ដើម ក្នុងរយៈពេល 7 ថ្ងៃ។ ការសងប្រាក់ត្រូវបានដំណើរការក្នុងរយៈពេល 3–5 ថ្ងៃធ្វើការ បន្ទាប់ពីយើងទទួលបានទំនិញដែលត្រូវត្រឡប់។',
    '5. Account & Using the App': '៥. គណនី និងការប្រើប្រាស់កម្មវិធី',
    'You are responsible for keeping your login details safe and for all activity on your account. You may not misuse the app, attempt to break its security, or resell our content.':
        'អ្នកទទួលខុសត្រូវក្នុងការរក្សាព័ត៌មានចូលរបស់អ្នកឱ្យមានសុវត្ថិភាព និងរាល់សកម្មភាពលើគណនីរបស់អ្នក។ អ្នកមិនអាចប្រើប្រាស់កម្មវិធីខុសគោលបំណង ព្យាយាមបំបែកប្រព័ន្ធសន្តិសុខ ឬលក់បន្តខ្លឹមសាររបស់យើងបានទេ។',
    '6. Limitation of Liability': '៦. ដែនកំណត់នៃការទទួលខុសត្រូវ',
    'Global Online is not liable for damages caused by misuse of products or by events beyond our control, such as delays caused by third party couriers or natural disasters.':
        'Global Online មិនទទួលខុសត្រូវចំពោះការខូចខាតដែលបណ្តាលមកពីការប្រើប្រាស់ផលិតផលខុស ឬព្រឹត្តិការណ៍ហួសពីការគ្រប់គ្រងរបស់យើង ដូចជា ការពន្យារពេលដោយក្រុមហ៊ុនដឹកជញ្ជូនភាគីទីបី ឬគ្រោះធម្មជាតិ។',
    '7. Contact': '៧. ទំនាក់ទំនង',
    'For any question about these terms, contact us via email at support@globalonline.com or use Chat Support in the app.':
        'សម្រាប់សំណួរណាមួយអំពីលក្ខខណ្ឌទាំងនេះ សូមទាក់ទងយើងតាមអ៊ីមែល support@globalonline.com ឬប្រើការគាំទ្រតាមឆាតក្នុងកម្មវិធី។',
    'Information We Collect': 'ព័ត៌មានដែលយើងប្រមូល',
    'We collect the information you give us when you create an account or place an order: your name, phone number, email and delivery address. We also store minimal data on this device, such as your password for local logins, your saved address and your shopping cart.':
        'យើងប្រមូលព័ត៌មានដែលអ្នកផ្តល់ឱ្យយើង នៅពេលអ្នកបង្កើតគណនី ឬបញ្ជាទិញ៖ ឈ្មោះរបស់អ្នក លេខទូរស័ព្ទ អ៊ីមែល និងអាសយដ្ឋានដឹកជញ្ជូន។ យើងក៏រក្សាទុកទិន្នន័យតិចតួចនៅលើឧបករណ៍នេះ ដូចជា ពាក្យសម្ងាត់សម្រាប់ការចូលក្នុងស្រុក អាសយដ្ឋានដែលបានរក្សាទុក និងកន្ត្រកទិញទំនិញរបស់អ្នក។',
    'How We Use Your Information': 'របៀបដែលយើងប្រើប្រាស់ព័ត៌មានរបស់អ្នក',
    'To process and deliver your orders.': 'ដើម្បីដំណើរការ និងប្រគល់ការបញ្ជាទិញរបស់អ្នក។',
    'To send you order updates and, if you allow it, discount alerts.':
        'ដើម្បីផ្ញើការអាប់ដេតការបញ្ជាទិញ ហើយប្រសិនបើអ្នកអនុញ្ញាត ការជូនដំណឹងបញ្ចុះតម្លៃ។',
    'To provide customer support and answer your questions.':
        'ដើម្បីផ្តល់ការគាំទ្រអតិថិជន និងឆ្លើយសំណួររបស់អ្នក។',
    'To improve our products and services.': 'ដើម្បីកែលម្អផលិតផល និងសេវាកម្មរបស់យើង។',
    'Cookies & Local Storage': 'ខូគី និងការផ្ទុកក្នុងស្រុក',
    'The app stores only the information needed for it to work. This data stays on your device and is never sold to third parties.':
        'កម្មវិធីរក្សាទុកតែព័ត៌មានចាំបាច់សម្រាប់ប្រតិបត្តិការរបស់វាប៉ុណ្ណោះ។ ទិន្នន័យនេះស្ថិតនៅលើឧបករណ៍របស់អ្នក ហើយមិនត្រូវបានលក់ទៅឱ្យភាគីទីបីឡើយ។',
    'Data Sharing': 'ការចែករំលែកទិន្នន័យ',
    'We share your delivery details only with the courier that delivers your order, and with payment providers only to complete a payment you chose. We never sell your personal data.':
        'យើងចែករំលែកព័ត៌មានលម្អិតនៃការដឹកជញ្ជូនរបស់អ្នកតែជាមួយក្រុមហ៊ុនដឹកជញ្ជូនដែលប្រគល់ការបញ្ជាទិញរបស់អ្នក និងជាមួយអ្នកផ្តល់សេវាទូទាត់តែដើម្បីបញ្ចប់ការទូទាត់ដែលអ្នកជ្រើសរើសប៉ុណ្ណោះ។ យើងមិនដែលលក់ទិន្នន័យផ្ទាល់ខ្លួនរបស់អ្នកទេ។',
    'Data Security': 'សន្តិសុខទិន្នន័យ',
    'We take reasonable steps to protect your personal information. Local sign-in data is stored within the app on your own device.':
        'យើងចាត់វិធានការសមហេតុផល ដើម្បីការពារព័ត៌មានផ្ទាល់ខ្លួនរបស់អ្នក។ ទិន្នន័យចូលក្នុងស្រុកត្រូវបានរក្សាទុកនៅក្នុងកម្មវិធីលើឧបករណ៍របស់អ្នកផ្ទាល់។',
    'Your Rights': 'សិទ្ធិរបស់អ្នក',
    'You can edit your profile, change your password, or delete your account at any time from the Profile page. Deleting your account removes your saved data from this device.':
        'អ្នកអាចកែសម្រួលប្រវត្តិរូប ប្តូរពាក្យសម្ងាត់ ឬលុបគណនីរបស់អ្នកបានគ្រប់ពេលពីទំព័រប្រវត្តិរូប។ ការលុបគណនីរបស់អ្នកដកចេញនូវទិន្នន័យដែលបានរក្សាទុកពីឧបករណ៍នេះ។',
    'If you have questions about this privacy policy, email support@globalonline.com or use Chat Support in the app.':
        'ប្រសិនបើអ្នកមានសំណួរអំពីគោលការណ៍ឯកជនភាពនេះ សូមផ្ញើអ៊ីមែលមក support@globalonline.com ឬប្រើការគាំទ្រតាមឆាតក្នុងកម្មវិធី។',
    'Answers to the questions we are asked the most.':
        'ចម្លើយចំពោះសំណួរដែលគេសួរញឹកញាប់បំផុត។',
    'How do I place an order?': 'តើខ្ញុំបញ្ជាទិញដោយរបៀបណា?',
    'Browse products, add them to your cart, then tap Checkout. Enter your (or pick a saved) delivery address, confirm and the order is placed.':
        'រកមើលផលិតផល បន្ថែមទៅកន្ត្រក រួចប៉ះ ទូទាត់។ បញ្ចូលអាសយដ្ឋានដឹកជញ្ជូនរបស់អ្នក បញ្ជាក់ រួចការបញ្ជាទិញត្រូវបានធ្វើឡើង។',
    'What payment methods do you accept?': 'តើអ្នកទទួលយកវិធីទូទាត់អ្វីខ្លះ?',
    'We accept cash on delivery, credit/debit cards, KHQR and mobile banking. You choose the method at checkout.':
        'យើងទទួលយកការបង់ប្រាក់ពេលទទួលទំនិញ កាតឥណទាន/ឥណពន្ធ KHQR និងធនាគារឌីជីថល។ អ្នកជ្រើសរើសវិធីសាស្ត្រនៅពេលទូទាត់។',
    'How long does shipping take?': 'តើការដឹកជញ្ជូនចំណាយពេលប៉ុន្មាន?',
    'Shipping takes 2–5 working days depending on your location. You receive SMS and Telegram updates along the way.':
        'ការដឹកជញ្ជូនចំណាយពេល 2–5 ថ្ងៃធ្វើការ អាស្រ័យលើទីតាំងរបស់អ្នក។ អ្នកនឹងទទួលការអាប់ដេតតាម SMS និង Telegram ពេញដំណើរ។',
    'Is delivery free?': 'តើការដឹកជញ្ជូនមិនគិតថ្លៃទេ?',
    'Delivery is free for orders over the minimum order value. The exact shipping cost, if any, is shown at checkout.':
        'ការដឹកជញ្ជូនមិនគិតថ្លៃសម្រាប់ការបញ្ជាទិញលើសពីតម្លៃអប្បបរមា។ តម្លៃដឹកជញ្ជូនពិតប្រាកដ ប្រសិនបើមាន ត្រូវបានបង្ហាញនៅពេលទូទាត់។',
    'How can I track my order?': 'តើខ្ញុំអាចតាមដានការបញ្ជាទិញរបស់ខ្ញុំដោយរបៀបណា?',
    'Open Profile → Order History and tap your order. You can follow the courier link from your order details.':
        'បើក ប្រវត្តិរូប → ប្រវត្តិការបញ្ជាទិញ ហើយប៉ះការបញ្ជាទិញរបស់អ្នក។ អ្នកអាចតាមដានតំណកន្លែងដឹកជញ្ជូនពីព័ត៌មានលម្អិតនៃការបញ្ជាទិញរបស់អ្នក។',
    'What is your return and refund policy?': 'តើគោលការណ៍ត្រឡប់ទំនិញ និងសងប្រាក់របស់អ្នកជាអ្វី?',
    'Returns are accepted within 7 days with the item unused and in its original packaging. Refunds are processed within 3–5 working days after we receive the item.':
        'ការត្រឡប់ទំនិញត្រូវបានទទួលយកក្នុងរយៈពេល 7 ថ្ងៃ ដោយទំនិញមិនបានប្រើប្រាស់ និងមានការវេចខ្ចប់ដើម។ ការសងប្រាក់ត្រូវបានដំណើរការក្នុងរយៈពេល 3–5 ថ្ងៃធ្វើការបន្ទាប់ពីយើងទទួលបានទំនិញ។',
    'Can I change or cancel my order?': 'តើខ្ញុំអាចផ្លាស់ប្តូរ ឬលុបចោលការបញ្ជាទិញរបស់ខ្ញុំបានទេ?',
    'As soon as your order is placed it goes into processing. Contact support quickly and we will do our best to change or cancel it before dispatch.':
        'នៅពេលដាក់ការបញ្ជាទិញរួច វាចូលក្នុងដំណើរការ។ សូមទាក់ទងជំនួយឱ្យលឿន ហើយយើងនឹងព្យាយាមផ្លាស់ប្តូរ ឬលុបចោលវាមុនការផ្ញើចេញ។',
    'How do I change my password?': 'តើខ្ញុំប្តូរពាក្យសម្ងាត់ដោយរបៀបណា?',
    'Open Profile → Change Password, enter your current and new password, then save. The new password is used the next time you sign in.':
        'បើក ប្រវត្តិរូប → ប្តូរពាក្យសម្ងាត់ បញ្ចូលពាក្យសម្ងាត់បច្ចុប្បន្ន និងថ្មី រួចរក្សាទុក។ ពាក្យសម្ងាត់ថ្មីនឹងត្រូវប្រើនៅពេលអ្នកចូលលើកក្រោយ។',
    'How do I delete my account?': 'តើខ្ញុំលុបគណនីដោយរបៀបណា?',
    'Open Profile → Delete Account. If you have pending orders, they must be settled first. After deletion your saved data is removed from this device.':
        'បើក ប្រវត្តិរូប → លុបគណនី។ ប្រសិនបើអ្នកមានការបញ្ជាទិញដែលកំពុងដំណើរការ ពួកវាត្រូវតែត្រូវបានបញ្ចប់ជាមុនសិន។ បន្ទាប់ពីលុប ទិន្នន័យដែលបានរក្សាទុករបស់អ្នកត្រូវបានដកចេញពីឧបករណ៍នេះ។',
    'How do I contact support?': 'តើខ្ញុំទាក់ទងជំនួយដោយរបៀបណា?',
    'Use Chat Support in the app, call +855 12 345 678, or email support@globalonline.com.':
        'ប្រើការគាំទ្រតាមឆាតក្នុងកម្មវិធី ហៅ +855 12 345 678 ឬផ្ញើអ៊ីមែល support@globalonline.com។',
    'Current Password': 'ពាក្យសម្ងាត់បច្ចុប្បន្ន',
    'New Password': 'ពាក្យសម្ងាត់ថ្មី',
    'Confirm new password': 'បញ្ជាក់ពាក្យសម្ងាត់ថ្មី',
    'Password changed successfully': 'ពាក្យសម្ងាត់ត្រូវបានប្តូរដោយជោគជ័យ',
    'Current password is incorrect': 'ពាក្យសម្ងាត់បច្ចុប្បន្នមិនត្រឹមត្រូវទេ',
    'Passwords do not match': 'ពាក្យសម្ងាត់ទាំងពីរមិនត្រូវគ្នាទេ',
    'New password must be different from the current one':
        'ពាក្យសម្ងាត់ថ្មីត្រូវតែខុសពីពាក្យសម្ងាត់បច្ចុប្បន្ន',
    'Show passwords': 'បង្ហាញពាក្យសម្ងាត់',
    'Hide passwords': 'លាក់ពាក្យសម្ងាត់',
    'No password is set for this account yet. Set a password so you can sign in with it later.':
        'មិនទាន់មានពាក្យសម្ងាត់សម្រាប់គណនីនេះទេ។ កំណត់ពាក្យសម្ងាត់ ដើម្បីអាចចូលជាមួយវានៅពេលក្រោយ។',
    'Delete account?': 'លុបគណនី?',
    'Your profile, saved address, cart, favorites and local password will be removed from this device. This cannot be undone.':
        'ប្រវត្តិរូប អាសយដ្ឋានដែលបានរក្សាទុក កន្ត្រក ចំណូលចិត្ត និងពាក្យសម្ងាត់ក្នុងស្រុករបស់អ្នក នឹងត្រូវបានដកចេញពីឧបករណ៍នេះ។ សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។',
    'Delete': 'លុប',
    'Edit': 'កែសម្រួល',
    'Actions': 'សកម្មភាព',
    'Status': 'ស្ថានភាព',
    'Inactive': 'អសកម្ម',
    'Image URL': 'តំណរូបភាព',
    'e.g. Beauty & Skincare': 'ឧ. អាយភាព និងការថែសម្បក់',
    'Short description of this category': 'ការពិពណ៌នាខ្លីអំពីប្រភេទនេះ',
    'Short description of this product': 'ការពិពណ៌នាខ្លីអំពីផលិតផលនេះ',
    'Create a new company for the catalog':
        'បង្កើតក្រុមហ៊ុនថ្មីសម្រាប់កាតាឡុក',
    'Update the company details':
        'ធ្វើបច្ចុប្បន្នភាពព័ត៌មានក្រុមហ៊ុន',
    'Add Company': 'បន្ថែមក្រុមហ៊ុន',
    'Edit Company': 'កែសម្រួលក្រុមហ៊ុន',
    'e.g. Essence': 'ឧ. Essence',
    'Only the name is required — the rest is optional.':
        'ត្រូវការត្រឹមឈ្មោះប៉ុណ្ណោះ — ដទៃទៀតស្រេចចិត្ត។',
    'Deleting your account removes your saved profile, address, cart, favorites and local password from this device. This action cannot be undone.':
        'ការលុបគណនីរបស់អ្នក ដកចេញនូវប្រវត្តិរូប អាសយដ្ឋាន កន្ត្រក ចំណូលចិត្ត និងពាក្យសម្ងាត់ក្នុងស្រុកពីឧបករណ៍នេះ។ សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។',
    'Active orders': 'ការបញ្ជាទិញសកម្ម',
    'You have pending (processing) orders. Please wait until they are completed before deleting your account.':
        'អ្នកមានការបញ្ជាទិញដែលកំពុងដំណើរការ។ សូមរង់ចាំរហូតដល់ពួកវាត្រូវបានបញ្ចប់ មុនពេលលុបគណនីរបស់អ្នក។',
    'Delete my account': 'លុបគណនីរបស់ខ្ញុំ',
    'Keep my account': 'រក្សាគណនីរបស់ខ្ញុំ',
    'After deleting your account, you will not be able to use it again.':
        'បន្ទាប់ពីលុបគណនីរបស់អ្នក អ្នកនឹងមិនអាចប្រើវាម្តងទៀតបានទេ។',
    'Are you sure you want to delete your account?': 'តើអ្នកប្រាកដថាចង់លុបគណនីរបស់អ្នកឬ?',
    'Order Cancellation': 'ការលុបចោលការបញ្ជាទិញ',
    'Before deleting your account, make sure you don\'t have any order that is in progress.':
        'មុនពេលលុបគណនីរបស់អ្នក សូមប្រាកដថាអ្នកមិនមានការបញ្ជាទិញណាមួយដែលកំពុងដំណើរការទេ។',
    'Account Deletion Reason': 'មូលហេតុនៃការលុបគណនី',
    'We are really sorry to hear that you decided to leave us. However, your feedback can be useful for us to improve our system.':
        'យើងពិតជាសោកស្តាយដែលឮថាអ្នកសម្រេចចិត្តចាកចេញពីយើង។ ទោះជាយ៉ាងណា មតិរបស់អ្នកអាចមានប្រយោជន៍សម្រាប់យើងក្នុងការកែលម្អប្រព័ន្ធរបស់យើង។',
    'Add your reason here': 'បន្ថែមមូលហេតុរបស់អ្នកនៅទីនេះ',
    'Share your feedback...': 'ចែករំលែកមតិរបស់អ្នក...',
    'Feedback': 'មតិយោបល់',
    'Feedback deleted': 'បានលុបមតិយោបល់',
    'Message': 'សារ',
    'Share your feedback': 'ចែករំលែកមតិរបស់អ្នក',
    'Help us improve your shopping experience.':
        'ជួយយើងកែលម្អបទពិសោធន៍ទិញទំនិញរបស់អ្នក។',
    'Your rating': 'ការវាយតម្លៃរបស់អ្នក',
    'Your message': 'សាររបស់អ្នក',
    'Write your feedback here...': 'សរសេរមតិរបស់អ្នកនៅទីនេះ...',
    'Submit Feedback': 'ដាក់ស្នើមតិ',
    'Please enter your message': 'សូមបញ្ចូលសាររបស់អ្នក',
    'Thanks for your feedback!': 'សូមអរគុណសម្រាប់មតិរបស់អ្នក!',
    'Could not send feedback. Please try again.':
        'មិនអាចផ្ញើមតិបានទេ។ សូមព្យាយាមម្តងទៀត។',
    'Search feedback...': 'ស្វែងរកមតិយោបល់...',
    'User': 'អ្នកប្រើ',
    'Are you sure you want to delete this account?': 'តើអ្នកប្រាកដថាចង់លុបគណនីនេះឬ?',
    'Give feedback': 'ផ្តល់មតិ',
    'Why are you leaving? (optional)': 'ហេតុអ្វីបានជាអ្នកចាកចេញ? (មិនចាំបាច់)',
    'Password is required': 'សូមបញ្ចូលពាក្យសម្ងាត់',
    'Enter your password to confirm.': 'សូមបញ្ចូលពាក្យសម្ងាត់របស់អ្នកដើម្បីបញ្ជាក់។',
    'No password is set for this account yet.': 'មិនទាន់មានពាក្យសម្ងាត់សម្រាប់គណនីនេះទេ។',
'Admin Panel': 'ផ្ទាំងគ្រប់គ្រង',
    'Admin login (computer only): 066778213 / admin123':
        'ការចូលអ្នកគ្រប់គ្រង (តែក្នុងកុំព្យូទ័រ)៖ 066778213 / admin123',
    'Phone number or Username': 'លេខទូរស័ព្ទ ឬ ឈ្មោះអ្នកប្រើ',
    'Welcome back': 'សូមស្វាគមន៍ត្រឡប់មកវិញ',
    'Welcome to Global Online': 'សូមស្វាគមន៍មកកាន់ Global Online',
    'This page is coming soon': 'ទំព័រនេះនឹងមកដល់ឆាប់ៗ',
    'Refresh data': 'ផ្ទុកទិន្នន័យឡើងវិញ',
    'Super Admin': 'អ្នកគ្រប់គ្រងជាន់ខ្ពស់',
    'User ID': 'លេខសម្គាល់អ្នកប្រើ',
    'Best prices & daily deals': 'តម្លៃល្អបំផុត និងបញ្ចុះតម្លៃរាល់ថ្ងៃ',
    'Fast delivery to your door': 'ការដឹកជញ្ជូនលឿនដល់ផ្ទះ',
    'Secure payments & easy returns': 'ការទូទាត់សុវត្ថិភាព និងសងប្រាក់ងាយស្រួល',
    'Shop anywhere.': 'ទិញឥវ៉ាន់គ្រប់ទីកន្លែង។',
    'Save everything.': 'សន្សំសំចៃគ្រប់យ៉ាង។',
    'Trusted by 10,000+ shoppers': 'អ្នកទិញជាង 10,000 នាក់ទុកចិត្ត',
    'Shop Manager': 'អ្នកគ្រប់គ្រងហាង',
    'Admin': 'អ្នកគ្រប់គ្រង',
    'Products': 'ផលិតផល',
    'Users': 'អ្នកប្រើប្រាស់',
    'Revenue': 'ចំណូល',
    'Order ID': 'លេខបញ្ជាទិញ',
    'Companies': 'ក្រុមហ៊ុន',
    'Dashboard': 'ផ្ទាំងព័ត៌មាន',
    'Reports': 'របាយការណ៍',
    'Administration': 'ការគ្រប់គ្រងប្រព័ន្ធ',
    'Company': 'ក្រុមហ៊ុន',
    'Location': 'ទីតាំង',
    'Website': 'គេហទំព័រ',
    'Verified': 'បានផ្ទៀងផ្ទាត់',
    'Unverified': 'មិនទាន់ផ្ទៀងផ្ទាត់',
    'Active': 'សកម្ម',
    'Search companies...': 'ស្វែងរកក្រុមហ៊ុន...',
    'Search categories...': 'ស្វែងរកប្រភេទ...',
    'Search products...': 'ស្វែងរកផលិតផល...',
    'Search users...': 'ស្វែងរកអ្នកប្រើប្រាស់...',
    'Search orders...': 'ស្វែងរកការបញ្ជាទិញ...',
    'New Company': 'ក្រុមហ៊ុនថ្មី',
    'New Product': 'ផលិតផលថ្មី',
    'Are you sure?': 'តើអ្នកប្រាកដទេ?',
    'No connection': 'គ្មានការតភ្ជាប់',
    'Manage': 'គ្រប់គ្រង',
    'Manage Products': 'គ្រប់គ្រងផលិតផល',
    'Manage Categories': 'គ្រប់គ្រងប្រភេទ',
    'Manage Users': 'គ្រប់គ្រងអ្នកប្រើប្រាស់',
    'Manage Orders': 'គ្រប់គ្រងការបញ្ជាទិញ',
    'Low stock': 'សន្ទស្សន៍ទាប',
    'Low Stock': 'សន្ទស្សន៍ទាប',
    'Recent Orders': 'ការបញ្ជាទិញថ្មីៗ',
    'Total Revenue': 'ចំណូលសរុប',
    'Total Orders': 'ការបញ្ជាទិញសរុប',
    'Customers': 'អតិថិជន',
    'Order Status': 'ស្ថានភាពការបញ្ជាទិញ',
    'Top Categories': 'ប្រភេទកំពូល',
    'View All': 'មើលទាំងអស់',
    'Processing': 'កំពុងដំណើរការ',
    'Shipped': 'បានដឹកជញ្ជូន',
    'Delivered': 'បានដល់ដៃ',
    'Cancelled': 'បានលុបចោល',
    'paid orders': 'ការបញ្ជាទិញដែលបានបង់ប្រាក់',
    'pending': 'កំពុងរង់ចាំ',
    'admins': 'អ្នកគ្រប់គ្រង',
    'low stock': 'សន្ទស្សន៍ទាប',
    'All products in stock': 'ផលិតផលទាំងអស់មាននៅក្នុងស្តុក',
    'Unknown': 'មិនស្គាល់',
    'Out of stock': 'អស់ស្តុក',
    'Add Product': 'បន្ថែមផលិតផល',
    'Edit Product': 'កែសម្រួលផលិតផល',
    'Add Category': 'បន្ថែមប្រភេទ',
    'Edit Category': 'កែសម្រួលប្រភេទ',
    'Slug': 'Slug',
    'Category updated': 'ប្រភេទត្រូវបានអាប់ដេត',
    'Leave empty to create it from the name automatically':
        'ទុកឲ្យទទេ ដើម្បីបង្កើតដោយស្វ័យប្រវត្តិពីឈ្មោះ',
    'Create a new category for the shop':
        'បង្កើតប្រភេទថ្មីសម្រាប់ហាង',
    'Update the category details':
        'ធ្វើបច្ចុប្បន្នភាពព័ត៌មានប្រភេទ',
    'Auto-generate from name': 'បង្កើតដោយស្វ័យប្រវត្តិពីឈ្មោះ',
    'Will use:': 'នឹងប្រើ៖',
    'Add': 'បន្ថែម',
    'Delete product?': 'លុបផលិតផល?',
    'Delete category?': 'លុបប្រភេទ?',
    'Delete this user?': 'លុបអ្នកប្រើប្រាស់នេះ?',
    'This action cannot be undone.': 'សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។',
    'Product added': 'ផលិតផលត្រូវបានបន្ថែម',
    'Product updated': 'ផលិតផលត្រូវបានអាប់ដេត',
    'Product deleted': 'ផលិតផលត្រូវបានលុប',
    'Category added': 'ប្រភេទត្រូវបានបន្ថែម',
    'New feedback received': 'មានមតិយោបល់ថ្មី',
    'Category deleted': 'ប្រភេទត្រូវបានលុប',
    'User deleted': 'អ្នកប្រើប្រាស់ត្រូវបានលុប',
    'Cannot delete the built-in admin account':
        'មិនអាចលុបគណនីអ្នកគ្រប់គ្រងដែលបានបង្កើតមកជាមួយកម្មវិធីទេ',
    'Brand': 'ម៉ាក',
    'Thumbnail URL': 'តំណរូបភាពតូច',
    'Images URL (comma separated)': 'តំណរូបភាព (បំបែកដោយសញ្ញាក្បៀស)',
    'Discount %': 'បញ្ចុះតម្លៃ %',
    'Rating': 'ការវាយតម្លៃ',
    'Price': 'តម្លៃ',
    'Customer': 'អតិថិជន',
    'Update status': 'ធ្វើបច្ចុប្បន្នភាពស្ថានភាព',
    'Order status updated': 'ស្ថានភាពការបញ្ជាទិញត្រូវបានអាប់ដេត',
    'Guest': 'ភ្ញៀវ',
    'No users yet': 'មិនទាន់មានអ្នកប្រើប្រាស់ទេ',
    'No categories yet': 'មិនទាន់មានប្រភេទទេ',
    'Please enter a name': 'សូមបញ្ចូលឈ្មោះ',
    'Enter a valid price': 'សូមបញ្ចូលតម្លៃត្រឹមត្រូវ',
    'Enter a valid rating': 'សូមបញ្ចូលការវាយតម្លៃត្រឹមត្រូវ',
  };

  static const Map<int, String> _descKm = {
    1: 'ម៉ាស្ការ៉ា Essence Lash Princess ដ៏ពេញនិយម ជួយធ្វើឲ្យរោមភ្នែកវែង និងស្អាត ជាប់បានយូរ និងមិនធ្វើបាបសត្វ។',
    2: 'Palette ស្រមោលភ្នែក ជាមួយកញ្ចក់ ផ្តល់ស្រមោលច្រើនមុខ សម្រាប់ភ្នែកស្អាត ងាយស្រួលយកតាមខ្លួន។',
    3: 'ម្សៅ Powder ម៉ដ្ឋល្អិត សម្រាប់តម្រាមមុខ និងបញ្ឈប់ស្លស ផ្តល់ស្បែករលោង និងម៉ាត់។',
    4: 'ក្រមួនមាត់ក្រហម ជម្រើសបុរាណ និងខ្លាំង សម្រាប់បន្ថែមពណ៌ដល់បបូរមាត់ ជាប់បានយូរ និងភ្លឺស្អាត។',
    5: 'ការបាយក្រហម ផ្តល់ពណ៌ក្រហមភ្លឺរលោង សម្រាប់ក្រចកស្អាត ស្ងួតលឿន ដូចបានធ្វើនៅហាង។',
    6: 'ទឹកអប់ CK One របស់ Calvin Klein ជាទឹកអប់រួមគ្នា (unisex) បុរាណ មានក្លិនស្រស់ស្អាត សម្រាប់ពាក់ប្រចាំថ្ងៃ។',
    7: 'Coco Noir របស់ Chanel ជាទឹកអប់ឆើតឆាយ និងអាថ៌កំបាំង មានក្លិនផ្លែទំពាំងស្ពឺរ ផ្កាកុលាប និងឈើ sandalwood ស័ក្តិសមសម្រាប់ពេលល្ងាច។',
    8: 'Jadore របស់ Dior ជាទឹកអប់ដ៏ប្រណិត មានក្លិនផ្កា លាយ ylang-ylang ផ្កាកុលាប និង jasmine បង្ហាញពីភាពស្ត្រី និងឆើតឆាយ។',
    9: 'Dolce Shine ដោយ Dolce & Gabbana ជាទឹកអប់ភ្លឺស្វាង ក្លិនផ្លែឈើ លាយផ្លែម៉ង់ហ្គោ ផ្កាម្លិះ និងឈើ blonde ជាក្លិនស្រស់ថ្លា និងក្មេង។',
    10: 'Gucci Bloom របស់ Gucci ជាទឹកអប់ផ្កា គួរឲ្យចាប់អារម្មណ៍ ក្លិន tuberose, jasmine និង Rangoon creeper ទំនើប និងរ៉ូមែនទិក។',
    11: 'គ្រែ Annibale Colombo ជាគ្រែប្រណិត ឆើតឆាយ ធ្វើពីសម្ភារៈគុណភាពខ្ពស់ សម្រាប់បន្ទប់គេងស្រួល និងស្អាត។',
    12: 'សាឡុង Annibale Colombo ជាកន្លែងអង្គុយឆើតឆាយ និងស្រួល ការរចនាដ៏ល្អ និងក្រណាត់គុណភាពខ្ពស់ សម្រាប់បន្ទប់ទទួលភ្ញៀវ។',
    13: 'តុក្បែរគ្រែ African Cherry ស្អាត និងមានប្រយោជន៍ ផ្តល់កន្លែងផ្ទុកងាយស្រួល និងឆើតឆាយសម្រាប់បន្ទប់គេង។',
    14: 'កៅអី Knoll Saarinen ទំនើប និងមាន ergonomics ល្អ សម្រាប់ការិយាល័យ ឬបន្ទប់ប្រជុំ ជាមួយការរចនាមិនចេះចាស់។',
    15: 'បន្ទោះឈើ ជាមួយកញ្ចក់ ប្លែកពីគេ និងស្អាត ជាមួយតុឈើ និងកញ្ចក់ផ្គូផ្គង។',
    16: 'ផ្លែប៉ោមស្រស់ និងក្រាញ់ ល្អសម្រាប់ហូប ឬប្រើក្នុងមុខម្ហូបផ្សេងៗ។',
    17: 'សាច់គោ steak គុណភាពខ្ពស់ ល្អសម្រាប់អាំង ឬចម្អិនតាមចំណូលចិត្ត។',
    18: 'អាហារឆ្មាដែលមានជីវជាតិ ផ្សំសម្រាប់បំពេញតម្រូវការអាហារូបត្ថម្ភរបស់ឆ្មាអ្នក។',
    19: 'សាច់មាន់ស្រស់ និងទន់ សម្រាប់ចម្អិនមុខម្ហូបផ្សេងៗ។',
    20: 'ប្រេងឆា សម្រាប់ចៀន កូរ និងការប្រើផ្សេងៗក្នុងផ្ទះបាយ។',
    21: 'ត្រសក់ស្រស់ និងស្រោចស្រព ល្អសម្រាប់សាឡាត់ អាហារសម្រន់ ឬម្ហូបម្ខាង។',
    22: 'អាហារឆ្កែ ផ្សំពិសេស មានសារធាតុចិញ្ចឹមសំខាន់ សម្រាប់ឆ្កែអ្នក។',
    23: 'ស៊ុតស្រស់ ជាគ្រឿងផ្សំច្រើនប្រភេទ សម្រាប់ដុតនំ ចម្អិន ឬអាហារពេលព្រឹក។',
    24: 'សាច់ត្រី steak គុណភាព សម្រាប់អាំង ដុតលើចង្ក្រាន ឬឆ្អិន។',
    25: 'ម្រេចកណ្តឹងបៃតងស្រស់ ល្អសម្រាប់បន្ថែមពណ៌ និងរសជាតិដល់មុខម្ហូប។',
    26: 'ម្ទេសហឹរបៃតង ល្អសម្រាប់បន្ថែមភាពហិរដល់មុខម្ហូបដែលអ្នកចូលចិត្ត។',
    27: 'ទឹកឃ្មុំសុទ្ធ ពីធម្មជាតិ ក្នុងពាងងាយស្រួល ល្អសម្រាប់ផ្អែមភេសជ្ជៈ ឬចាក់ពីលើអាហារ។',
    28: 'ការ៉េមផ្អែម និងឆ្ងាញ់ មានរសជាតិផ្សេងៗ សម្រាប់ភាពរីករាយ។',
    29: 'ទឹកផ្លែឈើស្រស់ ពេញដោយវីតាមីន ល្អសម្រាប់សុខភាព និងផ្តល់សំណើមដល់រាងកាយ។',
    30: 'គីវីសម្បូរជីវជាតិ ល្អសម្រាប់ហូប ឬបន្ថែមភាពត្រូពិចដល់មុខម្ហូប។',
    31: 'ក្រូចឆ្មារជូរ និងមានក្លិន អាចប្រើសម្រាប់ចម្អិន ដុតនំ ឬធ្វើភេសជ្ជៈស្រស់ៗ។',
    32: 'ទឹកដោះគោស្រស់ និងមានជីវជាតិ ជាគ្រឿងសំខាន់សម្រាប់មុខម្ហូប និងការទទួលទានប្រចាំថ្ងៃ។',
    33: 'ផ្លែប័ររីផ្អែម និងមានទឹក ល្អសម្រាប់ហូប ឬបន្ថែមទៅបង្អែម និងគ្រាប់ធញ្ញជាតិ។',
    34: 'កាហ្វេគុណភាព Nescafe មានរសជាតិច្រើនប្រភេទ សម្រាប់កាហ្វេសម្បូររសជាតិ។',
    35: 'ដំឡូងបារាំងគ្រប់ប្រភេទ ល្អសម្រាប់អាំង កិន ឬជាម្ហូបម្ខាង។',
    36: 'ម្សៅប្រូតេអ៊ីន សម្បូរសារធាតុចិញ្ចឹម ល្អសម្រាប់បន្ថែមប្រូតេអ៊ីនសំខាន់ដល់របបអាហារ។',
    37: 'ខ្ទឹមបារាំងក្រហម មានរសជាតិ និងក្លិនក្រអូប ល្អសម្រាប់បន្ថែមស៊ីជម្រៅដល់មុខម្ហូប។',
    38: 'អង្ករគុណភាពខ្ពស់ ជាគ្រឿងសំខាន់សម្រាប់ម្ហូបផ្សេងៗ និងជាមូលដ្ឋានសម្រាប់ចានជាច្រើន។',
    39: 'ភេសជ្ជៈសូដាផ្សេងៗ រសជាតិច្រើនមុខ ល្អសម្រាប់បំបាត់ការស្រេក។',
    40: 'ផ្លែស្ត្របឺរីផ្អែម និងរសជាតិឈ្ងុយ ល្អសម្រាប់ហូប បង្អែម ឬលាយស្មិទ្ធី។',
    41: 'ប្រអប់ Tissue ងាយស្រួល សម្រាប់ប្រើប្រចាំថ្ងៃ ផ្តល់ក្រដាសទន់ និងស្រូបល្អ។',
    42: 'ទឹកបរិសុទ្ធ ក្នុងដប ចាំបាច់សម្រាប់សុខភាព និងការផឹកពេញមួយថ្ងៃ។',
    43: 'យោលតុបតែងផ្ទះ គួរឲ្យស្រលាញ់ ការរចនាលម្អិត បន្ថែមភាពឆើតឆាយ និងរីករាយដល់បន្ទប់។',
    44: 'ក្របរូបថត Family Tree ជាវិធីស្អាត និងមានអត្ថន័យ ដើម្បីបង្ហាញការចងចាំគ្រួសារជាទីស្រឡាញ់។',
    45: 'រុក្ខជាតិក្លែងសម្រាប់តុបតែង នាំធម្មជាតិចូលផ្ទះ ដោយមិនបាច់ថែទាំ។',
    46: 'ថូផ្កា ឆើតឆាយ សម្រាប់រុក្ខជាតិដែលអ្នកចូលចិត្ត រចនាទំនើប សម្រាប់ក្នុងផ្ទះ ឬក្រៅផ្ទះ។',
    47: 'ចង្កៀងតុ ជាការតុបតែង និងបំភ្លឺ មានប្រយោជន៍សម្រាប់កន្លែងរស់នៅ រចនាទំនើប ផ្តល់ពន្លឺទាំងជុំវិញ និងសម្រាប់ការងារ។',
    48: 'ច្រខ្លា bamboo ជាឧបករណ៍ផ្ទះបាយ ធ្វើពីឫស្សីមិត្តភាពបរិស្ថាន ល្អសម្រាប់ត្រឡប់ កូរ និងដាក់ម្ហូប។',
    49: 'កែវអាលុយមីញ៉ូមខ្មៅ ស្អាត និងជាប់លាប់ សម្រាប់ភេសជ្ជៈក្តៅ និងត្រជាក់។',
    50: 'Whisk ខ្មៅ ជាគ្រឿងសំខាន់ក្នុងផ្ទះបាយ សម្រាប់វាយគ្រឿងផ្សំ ergonomics ល្អ និងទាន់សម័យ។',
    51: 'Blender ខ្លាំង និងតូចសម សម្រាប់ smoothie និងផ្សេងៗ ងាយស្រួល និងច្រើនមុខងារ។',
    52: 'ខ្ទះដែកថែប សម្រាប់ចៀន កូរ និងចៀនជ្រៅ ជាប់លាប់ កម្តៅស្មើគ្នា សម្រាប់ម្ហូបឆ្ងាញ់។',
    53: 'ក្តារកាត់ ជាគ្រឿងសំខាន់សម្រាប់រៀបចំអាហារ ធ្វើពីសម្ភារៈជាប់លាប់ សុវត្ថិភាព និងអនាម័យសម្រាប់កាត់។',
    54: 'Citrus Squeezer ពណ៌លឿង ឧបករណ៍ងាយស្រួល សម្រាប់ច្របាច់ទឹកផ្លែឈើ ពណ៌ភ្លឺបន្ថែមភាពស្រស់ស្រាយដល់ផ្ទះបាយ។',
    55: 'ឧបករណ៍ប្រឡាក់ស៊ុត ងាយស្រួល សម្រាប់កាត់ស៊ុតឆ្អិនឲ្យស្មើ ល្អសម្រាប់សាឡាត់ និងនំសាំងវិច។',
    56: 'ចង្ក្រានអគ្គិសនី ចល័ត និងមានប្រសិទ្ធភាព ល្អសម្រាប់ផ្ទះបាយតូច ឬផ្ទៃចម្អិនបន្ថែម។',
    57: 'ចម្រោះសំណាញ់ល្អិត ច្រើនប្រភេទ សម្រាប់ចម្រោះរាវ និងរែងគ្រឿងស្ងួត សំណាញ់ល្អិតធានាបានលទ្ធផលរលូន។',
    58: 'សម ជាប្រដាប់ប្រើបុរាណ សម្រាប់បរិភោគ និងចាក់អាហារ រចនាជាប់លាប់ និង ergonomic ល្អសម្រាប់ប្រើប្រចាំថ្ងៃ។',
    59: 'កែវ ជាទីកន្លែងផឹកឆើតឆាយ ច្រើនប្រភេទ កញ្ចក់ថ្លាអនុញ្ញាតឲ្យមើលឃើញពណ៌ និងវាយនភាពភេសជ្ជៈ។',
    60: 'Grater ខ្មៅ ឧបករណ៍ងាយស្រួល សម្រាប់កិនឈីស បន្លែ និងផ្សេងៗ កាំបិតមុត ធ្វើឲ្យការរៀបចំអាហាររហ័ស។',
    61: 'Hand Blender ជាឧបករណ៍ផ្ទះបាយ សម្រាប់លាយ កិន និងកូរ រចនាបង្រួម ម៉ូទ័រខ្លាំង ងាយស្រួលសម្រាប់រូបមន្តផ្សេងៗ។',
    62: 'ថាសដុតទឹកកក ងាយស្រួល សម្រាប់ធ្វើដុំទឹកកករាងផ្សេងៗ ល្អសម្រាប់ភេសជ្ជៈត្រជាក់ និងរីករាយ។',
    63: 'ចម្រោះផ្ទះបាយ ច្រើនប្រភេទ សម្រាប់រែង និងចម្រោះគ្រឿងស្ងួត និងសើម សំណាញ់ល្អិត ផ្តល់លទ្ធផលរលូនក្នុងការចម្អិន។',
    64: 'កាំបិត ជាឧបករណ៍សំខាន់សម្រាប់ច្របាច់ កាត់ និងធ្វើល្អិត កាំបិតមុត និងចំណុចទាញ ergonomic ជម្រើសដ៏គួរទុកចិត្ត។',
    65: 'ប្រអប់ដាក់អាហារ ងាយស្រួល និងចល័ត សម្រាប់ខ្ចប់ និងយកអាហារអម មានកន្លែងបំបែកសម្រាប់អាហារផ្សេងៗ។',
    66: 'មីក្រូវ៉េវ ជាឧបករណ៍ផ្ទះបាយ សម្រាប់កំដៅ ចម្អិនលឿន និងកកសំដៅ ទំហំបង្រួម សមរម្យសម្រាប់ផ្ទះបាយគ្រប់ប្រភេទ។',
    67: 'ទូរដាក់កែវ Mug ស្អាត និងសន្សំកន្លែង សម្រាប់រៀបចំកែវដែលអ្នកចូលចិត្ត ឲ្យមើលឃើញងាយស្រួល។',
    68: 'ខ្ទះ ជាប្រដាប់ចម្អិនចាំបាច់ សម្រាប់ចៀន កូរ និងចម្អិនចានផ្សេងៗ ស្រោបមិនជាប់ សម្អាតងាយ។',
    69: 'ចាន ជាប្រដាប់ចាំបាច់ សម្រាប់ដាក់ម្ហូប រចនាជាប់លាប់ និងស្អាត សម្រាប់ប្រើប្រចាំថ្ងៃ ឬឱកាសពិសេស។',
    70: 'Tongs ក្រហម ច្រើនប្រភេទ សម្រាប់ចម្អិន និងចាក់ម្ហូប ពណ៌ភ្លឺបន្ថែមភាពរីករាយដល់ផ្ទះបាយ។',
    71: 'ឆ្នាំងប្រាក់ ជាមួយគំរបកញ្ចក់ ស្អាត និងមានប្រយោជន៍ សម្រាប់ស្ងោរ និងចម្អិនម្ហូបឆ្ងាញ់ គំរបកញ្ចក់មើលឃើញការចម្អិន។',
    72: 'Slotted Turner ឧបករណ៍ផ្ទះបាយ សម្រាប់ត្រឡប់ និងកូរអាហារ រន្ធអនុញ្ញាតឲ្យរាវហូរចេញ ល្អសម្រាប់ចៀន និងកូរ។',
    73: 'ទូដាក់គ្រឿងគ្រឿត្ថ័ ងាយស្រួល សម្រាប់រៀបចំគ្រឿងគ្រឿត្ថ័ និងគ្រឿងផ្សំ ខាងក្នុងកន្លែងដាក់ស្អាត និងចូលដល់ងាយស្រួល។',
    74: 'ស្លាបព្រា ជាឧបករណ៍ផ្ទះបាយ សម្រាប់កូរ ចាក់ និងភ្លក់ រចនា ergonomic និងជាប់លាប់ ជាគ្រឿងសំខាន់ក្នុងផ្ទះបាយ។',
    75: 'ថាស មានប្រយោជន៍ និងតុបតែង សម្រាប់ដាក់អាហារសម្រន់ ឬភេសជ្ជៈ រចនាស្អាត ជាគ្រឿងបន្លាស់សម្រាប់កម្សាន្តភ្ញៀវ។',
    76: 'Rolling Pin ឈើ ឧបករណ៍បុរាណ សម្រាប់រាស់ម្សៅដុតនំ ផ្ទៃរលោង ចំណុចទាញរឹងមាំ ងាយស្រួលឲ្យកម្រាស់ស្មើ។',
    77: 'Peeler លឿង ឧបករណ៍ងាយស្រួល សម្រាប់បកសំបកផ្លែឈើ និងបន្លែ ពណ៌លឿងភ្លឺបន្ថែមភាពស្រស់ថ្លាដល់ផ្ទះបាយ។',
    };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}