// lib/screens/mock_test_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';

// ── Data Models ───────────────────────────────────────────────────────────────

class _Q {
  final String q;
  final List<String> opts;
  final int ans; // 0-indexed
  const _Q(this.q, this.opts, this.ans);
}

class _Pack {
  final String id, title, subtitle, emoji;
  final Color color;
  final bool isPyq;
  final List<_Q> questions;
  final int? questionCount; // set for API packs before questions are loaded
  int get count => questionCount ?? questions.length;
  const _Pack({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.questions,
    this.isPyq = false,
    this.questionCount,
  });
}

// ── Question Banks ────────────────────────────────────────────────────────────

const _practicePacks = [
  _Pack(
    id: 'ssc_gk',
    title: 'SSC General Knowledge',
    subtitle: 'Static GK for SSC CGL, CHSL, MTS',
    emoji: '🏛️',
    color: Color(0xFF1A6B3C),
    questions: [
      _Q('Who wrote the book "Discovery of India"?',
          ['Mahatma Gandhi', 'Jawaharlal Nehru', 'B.R. Ambedkar', 'Rabindranath Tagore'], 1),
      _Q('Which Article of the Indian Constitution abolishes untouchability?',
          ['Article 14', 'Article 15', 'Article 17', 'Article 21'], 2),
      _Q('The headquarters of ISRO is located in?',
          ['Mumbai', 'New Delhi', 'Hyderabad', 'Bengaluru'], 3),
      _Q('Which river is called the "Sorrow of Bihar"?',
          ['Gandak', 'Ganga', 'Kosi', 'Son'], 2),
      _Q('Who was the first woman IPS officer of India?',
          ['Sonia Gandhi', 'Pratibha Patil', 'Kiran Bedi', 'Bachendri Pal'], 2),
      _Q('Mt. K2 is also known as?',
          ['Godwin-Austen', 'Everest II', 'Black Mountain', 'Nanda Peak'], 0),
      _Q('Who composed the national song "Vande Mataram"?',
          ['Rabindranath Tagore', 'Sri Aurobindo', 'Sarojini Naidu', 'Bankim Chandra Chatterjee'], 3),
      _Q('Which state has the longest coastline in India?',
          ['Maharashtra', 'Andhra Pradesh', 'Tamil Nadu', 'Gujarat'], 3),
      _Q('"Operation Flood" was related to?',
          ['Flood management', 'Milk production', 'Wheat production', 'Fisheries'], 1),
      _Q('The Dandi March (Salt March) took place in which year?',
          ['1928', '1942', '1930', '1935'], 2),
      _Q('Which is the largest freshwater lake in India?',
          ['Chilika Lake', 'Wular Lake', 'Dal Lake', 'Loktak Lake'], 1),
      _Q('Project Tiger was launched in?',
          ['1970', '1972', '1973', '1975'], 2),
      _Q('Who is called the "Father of the Indian Constitution"?',
          ['Mahatma Gandhi', 'Jawaharlal Nehru', 'B.R. Ambedkar', 'Sardar Patel'], 2),
      _Q('Which is the smallest state of India by area?',
          ['Sikkim', 'Tripura', 'Goa', 'Manipur'], 2),
      _Q('Pradhan Mantri Awas Yojana (Urban) aims to provide?',
          ['Employment', 'Food security', 'Housing for all', 'Free education'], 2),
    ],
  ),
  _Pack(
    id: 'banking',
    title: 'Banking & Finance',
    subtitle: 'For SBI PO, IBPS PO, RBI Grade B',
    emoji: '🏦',
    color: Color(0xFF1565C0),
    questions: [
      _Q('RBI was established in which year?',
          ['1930', '1935', '1947', '1950'], 1),
      _Q('NEFT stands for?',
          ['National Electronic Funds Transfer', 'National Economy Finance Transfer',
           'Net Electronic Fund Transfer', 'National Exchange Finance Transfer'], 0),
      _Q('Who is called the "Father of White Revolution" in India?',
          ['M.S. Swaminathan', 'Verghese Kurien', 'Norman Borlaug', 'C. Subramaniam'], 1),
      _Q('The minimum lock-in period for a Tax Saving FD is?',
          ['3 years', '7 years', '10 years', '5 years'], 3),
      _Q('PMJDY stands for?',
          ['Pradhan Mantri Jan Dhan Yojana', 'Pradhan Mantri Jan Desh Yojana',
           'Prime Minister Jan Dhani Yojana', 'None of these'], 0),
      _Q('Which is the largest public sector bank in India?',
          ['Punjab National Bank', 'Bank of Baroda', 'Canara Bank', 'State Bank of India'], 3),
      _Q('SEBI regulates which market in India?',
          ['Commodity market only', 'Money market only',
           'Securities / Stock market', 'Foreign exchange market'], 2),
      _Q('CRR stands for?',
          ['Credit Reserve Ratio', 'Cash Reserve Ratio',
           'Capital Reserve Requirement', 'Currency Ratio Reserve'], 1),
      _Q('NABARD was established to provide credit for?',
          ['Industries', 'Agriculture & rural development', 'Housing sector', 'Export'], 1),
      _Q('Repo rate is the rate at which?',
          ['Banks borrow from each other', 'RBI lends to commercial banks',
           'Banks lend to customers', 'Government borrows from RBI'], 1),
      _Q('UPI was launched by which organization?',
          ['RBI', 'SBI', 'NPCI', 'SEBI'], 2),
      _Q('Which is NOT a function of RBI?',
          ['Issuing currency notes', 'Banker to government',
           'Granting retail loans to public', 'Regulating banking sector'], 2),
      _Q('SEBI was established as a statutory body in which year?',
          ['1988', '1990', '1992', '1994'], 2),
      _Q('KYC stands for?',
          ['Keep Your Cash', 'Know Your Customer', 'Know Your Credit', 'Keep Your Credit'], 1),
      _Q('The headquarters of NABARD is in?',
          ['New Delhi', 'Chennai', 'Mumbai', 'Kolkata'], 2),
    ],
  ),
  _Pack(
    id: 'railway',
    title: 'Railway GK',
    subtitle: 'For RRB NTPC, Group D, ALP',
    emoji: '🚂',
    color: Color(0xFFB71C1C),
    questions: [
      _Q('Indian Railways was nationalized in which year?',
          ['1947', '1948', '1950', '1951'], 3),
      _Q('The first railway in India ran between?',
          ['Delhi to Agra', 'Kolkata to Howrah',
           'Mumbai (Bombay) to Thane', 'Chennai to Madurai'], 2),
      _Q('Which station has the longest railway platform in India?',
          ['Gorakhpur', 'Kharagpur', 'Agra Cantt', 'Allahabad'], 0),
      _Q('IRCTC stands for?',
          ['Indian Railway Cargo & Travel Corporation',
           'Indian Railway Catering and Tourism Corporation',
           'Indian Rail Catering & Transport Company', 'None of these'], 1),
      _Q('Vande Bharat Express is classified as?',
          ['Bullet train', 'Freight train', 'Semi-high speed train', 'Metro train'], 2),
      _Q('The headquarters of Indian Railways is in?',
          ['Mumbai', 'Kolkata', 'Chennai', 'New Delhi'], 3),
      _Q('Lifeline Express is also known as?',
          ['Train of Hope', 'Hospital on Wheels', 'Mobile Medical Unit', 'Health Train'], 1),
      _Q('Which zone of Indian Railways is the largest by route km?',
          ['Central Railway', 'Western Railway', 'Northern Railway', 'South Central Railway'], 2),
      _Q('Rail Kaushal Vikas Yojana is related to?',
          ['Railway infrastructure', 'Skill development for youth',
           'Railway employee training', 'Station modernization'], 1),
      _Q('The first Metro rail in India started in which city?',
          ['Delhi', 'Mumbai', 'Chennai', 'Kolkata'], 3),
      _Q('Indian Railways mainly uses which gauge for broad gauge tracks?',
          ['762 mm', '1000 mm', '1676 mm', '1435 mm'], 2),
      _Q('Mission Raftaar was launched to?',
          ['Reduce accidents', 'Double freight and passenger speed',
           'Build new stations', 'Electrify all routes'], 1),
      _Q('The Konkan Railway connects Roha (Maharashtra) to?',
          ['Goa', 'Thivim (Goa)', 'Mangaluru (Karnataka)', 'Kochi'], 2),
      _Q('Rail Vikas Nigam Limited (RVNL) is under which ministry?',
          ['Finance Ministry', 'Commerce Ministry',
           'Ministry of Railways', 'Ministry of Transport'], 2),
      _Q('PM Gati Shakti National Master Plan is related to?',
          ['Agricultural supply chains', 'Integrated multimodal connectivity infrastructure',
           'Digital connectivity', 'Rural electrification'], 1),
    ],
  ),
  _Pack(
    id: 'reasoning',
    title: 'Reasoning Ability',
    subtitle: 'Logical & verbal reasoning basics',
    emoji: '🧠',
    color: Color(0xFF6A1B9A),
    questions: [
      _Q('Complete the series: 2, 4, 8, 16, ?',
          ['24', '32', '36', '28'], 1),
      _Q('If BOOK is coded as CPPL (each letter +1), how is FISH coded?',
          ['GJTI', 'GHTJ', 'GITH', 'GJTH'], 0),
      _Q('Find the odd one out: Apple, Mango, Potato, Banana',
          ['Apple', 'Mango', 'Potato', 'Banana'], 2),
      _Q('Dog is to Kennel as Bird is to?',
          ['Hole', 'Cage', 'Nest', 'Tree'], 2),
      _Q('Complete: 3, 6, 11, 18, 27, ?\n(differences: 3, 5, 7, 9, 11)',
          ['36', '38', '35', '40'], 1),
      _Q('Which number does NOT belong: 1, 4, 9, 16, 24, 36?',
          ['4', '9', '24', '36'], 2),
      _Q('Pointing to a boy, a girl says "His mother is the only daughter of my mother." '
         'How is the girl related to the boy?',
          ['Grandmother', 'Sister', 'Aunt', 'Mother'], 3),
      _Q('ACEG : BDFH :: IKMO : ?',
          ['JLNP', 'JLNO', 'ILNP', 'KLMP'], 0),
      _Q('Complete the Fibonacci series: 1, 1, 2, 3, 5, 8, ?',
          ['11', '12', '13', '14'], 2),
      _Q('If + means ×, − means +, ÷ means −, × means ÷\nFind: 15 + 3 − 20 ÷ 5',
          ['55', '60', '65', '70'], 1),
      _Q('Missing number: 8, 27, 64, 125, ?  (pattern: 2³, 3³, 4³, 5³...)',
          ['196', '216', '225', '243'], 1),
      _Q('Find the odd one out: January, March, June, August\n(Hint: months with 31 days)',
          ['January', 'March', 'June', 'August'], 2),
      _Q('ZONE → Z=26, O=15, N=14, E=5. Total = ?',
          ['55', '58', '60', '62'], 2),
      _Q('In a row of boys, Ravi is 7th from left and 13th from right. '
         'Total boys in the row?',
          ['18', '19', '20', '21'], 1),
      _Q('A man walks 5 km North, turns right and walks 3 km, '
         'then turns right again and walks 5 km. '
         'How far is he from starting point?',
          ['2 km', '3 km', '5 km', '13 km'], 1),
    ],
  ),
  _Pack(
    id: 'polity',
    title: 'Indian Polity',
    subtitle: 'Constitution & governance — UPSC / SSC',
    emoji: '⚖️',
    color: Color(0xFF00695C),
    questions: [
      _Q('The Constitution of India came into force on?',
          ['15 August 1947', '26 November 1949', '26 January 1950', '30 January 1948'], 2),
      _Q('How many Fundamental Rights are guaranteed by the Indian Constitution?',
          ['7', '6', '5', '8'], 1),
      _Q('Which article grants the Right to Constitutional Remedies?',
          ['Article 19', 'Article 21', 'Article 32', 'Article 44'], 2),
      _Q('The President of India is elected by?',
          ['Direct election by citizens', 'Lok Sabha members only',
           'Elected members of Parliament and State Legislative Assemblies',
           'Rajya Sabha members only'], 2),
      _Q('Which Schedule of the Constitution lists the Official Languages?',
          ['Sixth Schedule', 'Seventh Schedule', 'Eighth Schedule', 'Ninth Schedule'], 2),
      _Q('The term "Secular" was added to the Preamble by which Amendment?',
          ['42nd Amendment, 1976', '44th Amendment, 1978',
           '52nd Amendment, 1985', '61st Amendment, 1988'], 0),
      _Q('Which writ is issued for the release of a person illegally detained?',
          ['Mandamus', 'Certiorari', 'Habeas Corpus', 'Quo Warranto'], 2),
      _Q('Zero Hour in Parliament begins at?',
          ['9:00 AM', '11:00 AM', '12:00 Noon', '2:00 PM'], 2),
      _Q('The concept of "Directive Principles" was borrowed from?',
          ['USA', 'UK', 'Ireland', 'Canada'], 2),
      _Q('Under which Article can the President declare National Emergency?',
          ['Article 352', 'Article 356', 'Article 360', 'Article 370'], 0),
      _Q('The Election Commission of India is a/an?',
          ['Statutory body', 'Constitutional body', 'Executive body', 'Advisory body'], 1),
      _Q('How many members can the President nominate to the Rajya Sabha?',
          ['10', '14', '12', '16'], 2),
      _Q('Which part of the Constitution deals with Fundamental Duties?',
          ['Part III', 'Part IV', 'Part IVA', 'Part V'], 2),
      _Q('The minimum age to become a member of Rajya Sabha is?',
          ['21 years', '25 years', '30 years', '35 years'], 2),
      _Q('Which committee examines the estimates of government expenditure?',
          ['Public Accounts Committee', 'Estimates Committee',
           'Committee on Public Undertakings', 'Finance Committee'], 1),
    ],
  ),
];

const _pyqPacks = [
  _Pack(
    id: 'pyq_ssc',
    title: 'SSC CGL / CHSL — PYQ',
    subtitle: 'Frequently repeated questions from past papers',
    emoji: '📋',
    color: Color(0xFF2E7D32),
    isPyq: true,
    questions: [
      _Q('"Jai Jawan, Jai Kisan" slogan was given by?',
          ['Mahatma Gandhi', 'Jawaharlal Nehru', 'Lal Bahadur Shastri', 'Indira Gandhi'], 2),
      _Q('Chipko Movement is associated with?',
          ['Water conservation', 'Conservation of forests', 'Soil conservation', 'Wildlife protection'], 1),
      _Q('The Battle of Plassey was fought in?',
          ['1747', '1757', '1764', '1775'], 1),
      _Q('Which is the largest gland in the human body?',
          ['Pancreas', 'Thyroid', 'Liver', 'Kidney'], 2),
      _Q('"Wings of Fire" is the autobiography of?',
          ['Manmohan Singh', 'Narendra Modi', 'A.P.J. Abdul Kalam', 'Atal Bihari Vajpayee'], 2),
      _Q('Vitamin D is also known as?',
          ['Beauty Vitamin', 'Sunshine Vitamin', 'Energy Vitamin', 'Blood Vitamin'], 1),
      _Q('Durand Line is the border between?',
          ['India and Pakistan', 'India and China', 'Afghanistan and Pakistan', 'China and Tibet'], 2),
      _Q('The headquarters of WTO is located in?',
          ['New York', 'London', 'Paris', 'Geneva'], 3),
      _Q('The Munda Ulgulan (revolt) was led by?',
          ['Tantia Tope', 'Mangal Pandey', 'Birsa Munda', 'Alluri Sitarama Raju'], 2),
      _Q('"Do or Die" slogan was associated with which movement?',
          ['Non-Cooperation Movement', 'Civil Disobedience Movement',
           'Quit India Movement 1942', 'Swadeshi Movement'], 2),
      _Q('Palk Strait separates India from?',
          ['Maldives', 'Bangladesh', 'Sri Lanka', 'Myanmar'], 2),
      _Q('Who discovered Penicillin?',
          ['Louis Pasteur', 'Alexander Fleming', 'Robert Koch', 'Edward Jenner'], 1),
      _Q('The smallest bone in the human body is?',
          ['Femur', 'Stapes (in ear)', 'Patella', 'Radius'], 1),
      _Q('International Yoga Day is celebrated on?',
          ['June 5', 'June 21', 'July 11', 'August 12'], 1),
      _Q('India\'s first artificial satellite was?',
          ['Bhaskara', 'INSAT-1A', 'Aryabhata', 'Rohini'], 2),
    ],
  ),
  _Pack(
    id: 'pyq_rrb',
    title: 'RRB NTPC / Group D — PYQ',
    subtitle: 'Frequently repeated questions from past papers',
    emoji: '🚆',
    color: Color(0xFFC62828),
    isPyq: true,
    questions: [
      _Q('The "Hornbill Festival" is celebrated in which state?',
          ['Manipur', 'Assam', 'Meghalaya', 'Nagaland'], 3),
      _Q('Who invented the telephone?',
          ['Thomas Edison', 'Nikola Tesla', 'Alexander Graham Bell', 'James Watt'], 2),
      _Q('"Jai Hind" slogan was popularized by?',
          ['Mahatma Gandhi', 'Jawaharlal Nehru', 'Bhagat Singh', 'Subhas Chandra Bose'], 3),
      _Q('Swaraj Party was co-founded by?',
          ['Gandhi and Nehru', 'C.R. Das and Motilal Nehru',
           'Tilak and Gokhale', 'Jinnah and Ambedkar'], 1),
      _Q('Blood group system was discovered by?',
          ['Louis Pasteur', 'Robert Koch', 'Karl Landsteiner', 'Alexander Fleming'], 2),
      _Q('India\'s National Aquatic Animal is?',
          ['Irrawaddy Dolphin', 'Blue Whale', 'Gangetic River Dolphin', 'Great White Shark'], 2),
      _Q('The National Tree of India is?',
          ['Neem', 'Peepal', 'Ashoka', 'Banyan'], 3),
      _Q('Khajuraho temples are located in which state?',
          ['Rajasthan', 'Uttar Pradesh', 'Madhya Pradesh', 'Bihar'], 2),
      _Q('INS Vikrant is India\'s?',
          ['Nuclear submarine', 'Destroyer', 'Aircraft carrier', 'Frigate'], 2),
      _Q('India won its first Olympic gold medal (team sport) in?',
          ['1924 Paris (Hockey)', '1928 Amsterdam (Hockey)',
           '1932 Los Angeles (Hockey)', '1936 Berlin (Hockey)'], 1),
      _Q('"Godan" (गोदान), a famous Hindi novel, was written by?',
          ['Premchand', 'Jaishankar Prasad', 'Mahadevi Verma', 'Suryakant Tripathi'], 0),
      _Q('Hydrogen bomb works on the principle of?',
          ['Nuclear fission', 'Nuclear fusion', 'Chemical reaction', 'Radioactive decay'], 1),
      _Q('The largest ocean in the world is?',
          ['Atlantic Ocean', 'Indian Ocean', 'Arctic Ocean', 'Pacific Ocean'], 3),
      _Q('The height of Mount Everest is approximately?',
          ['8611 m', '8586 m', '8849 m', '8091 m'], 2),
      _Q('Which is the highest civilian award in India?',
          ['Padma Vibhushan', 'Padma Bhushan', 'Bharat Ratna', 'Param Vir Chakra'], 2),
    ],
  ),
  _Pack(
    id: 'pyq_banking',
    title: 'SBI / IBPS PO — PYQ',
    subtitle: 'Frequently repeated Banking Awareness questions',
    emoji: '💳',
    color: Color(0xFF1565C0),
    isPyq: true,
    questions: [
      _Q('SWIFT stands for?',
          ['Secure Worldwide Interbank Finance Transfer',
           'Society for Worldwide Interbank Financial Telecommunication',
           'System for Worldwide Interbank Fund Transfer',
           'Standard Worldwide Interbank Finance Transaction'], 1),
      _Q('Basel III norms are related to?',
          ['Insurance regulations', 'Capital requirements of banks',
           'Stock market regulations', 'Foreign exchange rules'], 1),
      _Q('CPI (Consumer Price Index) measures?',
          ['Industrial production', 'Stock market performance',
           'Changes in price level of consumer goods & services', 'GDP growth'], 2),
      _Q('MUDRA stands for?',
          ['Micro Units Development and Refinance Agency',
           'Micro Urban Development and Rural Agency',
           'Monetary Unit Development and Regulatory Authority',
           'None of these'], 0),
      _Q('PM SVANidhi scheme was launched to help?',
          ['Farmers', 'Street vendors', 'Small industries', 'Tribal communities'], 1),
      _Q('NEFT operates on a _____ basis (from December 2019)?',
          ['8 hours a day, 5 days a week', '12 hours a day, 6 days a week',
           '24×7 basis', 'Only on bank working days'], 2),
      _Q('World Bank headquarters is located in?',
          ['Geneva', 'New York', 'Washington D.C.', 'London'], 2),
      _Q('"Ease of Doing Business" index is published by?',
          ['IMF', 'WTO', 'World Bank', 'UNCTAD'], 2),
      _Q('RBI is also called the "Banker\'s Bank" because it?',
          ['Gives loans to individuals', 'Acts as banker to commercial banks',
           'Prints currency', 'Manages stock exchanges'], 1),
      _Q('India\'s first bank was?',
          ['Bank of Bombay', 'Bank of Bengal', 'Bank of Hindustan', 'Imperial Bank'], 2),
      _Q('CAMELS rating is used to evaluate?',
          ['Real estate companies', 'Automobile companies',
           'Banks and financial institutions', 'Insurance companies'], 2),
      _Q('Priority Sector Lending (PSL) target for domestic banks is what % of ANBC?',
          ['30%', '35%', '40%', '45%'], 2),
      _Q('Bancassurance refers to?',
          ['Bank mergers', 'Banks selling insurance products',
           'Insurance companies acquiring banks', 'Government bank guarantee'], 1),
      _Q('The Payment and Settlement Systems Act was enacted in?',
          ['2001', '2005', '2007', '2010'], 2),
      _Q('Under Pradhan Mantri MUDRA Yojana, maximum loan amount is?',
          ['₹5 lakh', '₹10 lakh', '₹20 lakh', '₹50 lakh'], 1),
    ],
  ),
  _Pack(
    id: 'pyq_upsc',
    title: 'UPSC Prelims GS — PYQ',
    subtitle: 'General Studies questions from past papers',
    emoji: '🎯',
    color: Color(0xFF4527A0),
    isPyq: true,
    questions: [
      _Q('Project Snow Leopard was launched by which ministry?',
          ['Ministry of Defence', 'Ministry of Agriculture',
           'Ministry of Environment, Forest & Climate Change', 'Ministry of Tribal Affairs'], 2),
      _Q('"The Great Indian Bustard" bird is mainly found in?',
          ['Gujarat', 'Rajasthan', 'Madhya Pradesh', 'Assam'], 1),
      _Q('Madhubani painting is a traditional art form of?',
          ['Rajasthan', 'Odisha', 'Bihar', 'Gujarat'], 2),
      _Q('The Asiatic Lion is found only in?',
          ['Sariska National Park, Rajasthan', 'Gir National Park, Gujarat',
           'Corbett National Park, Uttarakhand', 'Bandipur National Park, Karnataka'], 1),
      _Q('"Silambam" is a traditional martial art associated with?',
          ['Kerala', 'Karnataka', 'Andhra Pradesh', 'Tamil Nadu'], 3),
      _Q('The concept of UNESCO Biosphere Reserves aims to?',
          ['Protect only wildlife', 'Only forest conservation',
           'Reconcile conservation and sustainable use', 'Prevent human habitation'], 2),
      _Q('The term "Stagflation" means?',
          ['Rapid economic growth', 'Deflation in rural areas',
           'High inflation with stagnant economic growth', 'Only stagnant wages'], 2),
      _Q('"Panchayati Raj" in India was introduced based on recommendations of?',
          ['Ashok Mehta Committee', 'Balwant Rai Mehta Committee',
           'G.V.K. Rao Committee', 'L.M. Singhvi Committee'], 1),
      _Q('Which Constitutional Amendment lowered the voting age from 21 to 18?',
          ['44th Amendment', '52nd Amendment', '61st Amendment', '73rd Amendment'], 2),
      _Q('CAMPA (Compensatory Afforestation Fund) is used for?',
          ['Compensation to farmers', 'Plantation and afforestation activities',
           'Pollution control', 'Tribal welfare'], 1),
      _Q('Mt. Everest is located on the international border of?',
          ['India and China', 'Nepal and China (Tibet)', 'Nepal and India', 'Tibet and Bhutan'], 1),
      _Q('Kovalam Beach is located in which state?',
          ['Goa', 'Maharashtra', 'Tamil Nadu', 'Kerala'], 3),
      _Q('How many Schedules are there in the Indian Constitution (as amended)?',
          ['10', '11', '12', '14'], 2),
      _Q('Article 370 (now abrogated) was related to special status of?',
          ['Nagaland', 'Sikkim', 'Mizoram', 'Jammu & Kashmir'], 3),
      _Q('Pradhan Mantri Vaya Vandana Yojana is a pension scheme for?',
          ['Below Poverty Line families', 'Government employees',
           'Senior citizens (60+ years)', 'Disabled persons'], 2),
      _Q('The "Doctrine of Lapse" was introduced by?',
          ['Lord Dalhousie', 'Lord Cornwallis', 'Lord Wellesley', 'Lord Curzon'], 0),
      _Q('India\'s first Five Year Plan was from?',
          ['1947–52', '1951–56', '1952–57', '1950–55'], 1),
      _Q('Which Article of the Indian Constitution provides for the creation of new states?',
          ['Article 1', 'Article 2', 'Article 3', 'Article 4'], 2),
      _Q('The term "Epicentre" is associated with?',
          ['Typhoon', 'Earthquake', 'Volcano', 'Tsunami'], 1),
      _Q('Which planet has the most natural satellites?',
          ['Jupiter', 'Saturn', 'Uranus', 'Neptune'], 1),
      _Q('The "Quit India" resolution was passed at which Congress session?',
          ['Lahore 1929', 'Karachi 1931', 'Bombay 1942', 'Lucknow 1936'], 2),
      _Q('Who was the first woman Chief Minister of an Indian state?',
          ['Indira Gandhi', 'Vijaya Lakshmi Pandit', 'Sucheta Kriplani', 'Nandini Satpathy'], 2),
      _Q('The standard time of India is based on the longitude of?',
          ['77.5°E', '80°E', '82.5°E', '85°E'], 2),
      _Q('Headquarters of the International Court of Justice is in?',
          ['New York', 'Brussels', 'The Hague', 'Geneva'], 2),
    ],
  ),
  _Pack(
    id: 'pyq_banking',
    title: 'IBPS / SBI — Banking PYQ',
    subtitle: 'Frequently repeated Banking & GA questions',
    emoji: '🏦',
    color: Color(0xFF1565C0),
    isPyq: true,
    questions: [
      _Q('IMPS allows fund transfer?',
          ['Only on bank working days', 'Monday to Saturday', '24×7 including holidays', 'Only weekdays'], 2),
      _Q('The headquarters of SEBI is located in?',
          ['New Delhi', 'Kolkata', 'Mumbai', 'Chennai'], 2),
      _Q('Which bank launched the first RuPay credit card?',
          ['SBI', 'PNB', 'Bank of Baroda', 'Union Bank'], 0),
      _Q('SIDBI stands for?',
          ['Small Industries Development Bank of India',
           'State Industrial Development Bank of India',
           'Special Industrial Development Bank Initiative',
           'None of the above'], 0),
      _Q('The Open Market Operations (OMO) are conducted by?',
          ['SEBI', 'Finance Ministry', 'RBI', 'IRDA'], 2),
      _Q('Which is NOT a Negotiable Instrument?',
          ['Cheque', 'Bill of Exchange', 'Promissory Note', 'Fixed Deposit Receipt'], 3),
      _Q('SLR stands for?',
          ['Statutory Liquidity Ratio', 'Standard Lending Rate', 'Systematic Liquidity Reserve', 'None'], 0),
      _Q('Base Rate was replaced by which rate?',
          ['PLR', 'MCLR', 'Repo Rate', 'Bank Rate'], 1),
      _Q('The concept of "Priority Sector Lending" means banks must lend to?',
          ['Only government projects', 'Agriculture, MSMEs, weaker sections',
           'Only large industries', 'Exports only'], 1),
      _Q('"White Label ATMs" are operated by?',
          ['RBI', 'Only PSU banks', 'Non-bank entities', 'Finance Ministry'], 2),
      _Q('India\'s largest commercial bank by assets?',
          ['HDFC Bank', 'Punjab National Bank', 'Bank of Baroda', 'State Bank of India'], 3),
      _Q('RTGS is used for transactions of minimum?',
          ['₹1 lakh', '₹2 lakh', '₹5 lakh', '₹10 lakh'], 1),
      _Q('Fiscal deficit means?',
          ['Total revenue minus total expenditure',
           'Total expenditure minus total receipts (excluding borrowings)',
           'Current account deficit', 'Trade deficit'], 1),
      _Q('Which authority regulates insurance in India?',
          ['RBI', 'SEBI', 'IRDAI', 'PFRDA'], 2),
      _Q('The "Kisan Credit Card" scheme was launched in?',
          ['1995', '1998', '2001', '2004'], 1),
      _Q('Core Banking Solution (CBS) connects?',
          ['All branches of a bank on a real-time network', 'Different banks', 'RBI with banks', 'None'], 0),
      _Q('Which of the following is a "Money Market" instrument?',
          ['Equity shares', 'Debentures', 'Treasury Bills', 'Bonds'], 2),
      _Q('Financial Inclusion aims to?',
          ['Increase bank profits', 'Provide affordable financial services to all',
           'Reduce foreign investment', 'Control inflation'], 1),
      _Q('CIBIL score range is?',
          ['0–500', '300–900', '0–999', '100–800'], 1),
      _Q('Mudra Yojana classifies loans into three categories: Shishu, Kishore, and?',
          ['Tarun', 'Yuva', 'Pragati', 'Unnati'], 0),
    ],
  ),
  _Pack(
    id: 'pyq_upsc_science',
    title: 'UPSC — Science & Environment PYQ',
    subtitle: 'Science, Ecology & Environment from past papers',
    emoji: '🌿',
    color: Color(0xFF00695C),
    isPyq: true,
    questions: [
      _Q('Which gas is mainly responsible for the Greenhouse Effect?',
          ['Oxygen', 'Nitrogen', 'Carbon Dioxide', 'Hydrogen'], 2),
      _Q('The process by which plants lose water through leaves is called?',
          ['Transpiration', 'Respiration', 'Photosynthesis', 'Osmosis'], 0),
      _Q('Which of the following is a Kharif crop?',
          ['Wheat', 'Mustard', 'Rice', 'Gram'], 2),
      _Q('The "Red List" of threatened species is maintained by?',
          ['WWF', 'IUCN', 'UNEP', 'UNESCO'], 1),
      _Q('National Action Plan on Climate Change (NAPCC) has how many missions?',
          ['6', '7', '8', '10'], 2),
      _Q('Bioremediation uses _____ to clean pollutants.',
          ['Chemicals', 'Microorganisms', 'UV radiation', 'Heat'], 1),
      _Q('The "Fly Ash" is a by-product of?',
          ['Oil refineries', 'Thermal power plants', 'Steel plants', 'Chemical factories'], 1),
      _Q('Which schedule of Wildlife Protection Act 1972 gives highest protection?',
          ['Schedule I', 'Schedule II', 'Schedule IV', 'Schedule VI'], 0),
      _Q('CITES regulates?',
          ['Climate change', 'International trade in endangered species', 'Ozone depletion', 'Marine pollution'], 1),
      _Q('Bioaccumulation refers to?',
          ['Accumulation of toxins in water', 'Accumulation of toxins in organisms over time',
           'Natural decomposition', 'Build-up of CO₂'], 1),
      _Q('The "Blue Revolution" is related to?',
          ['Water conservation', 'Fisheries development', 'Dairy development', 'Wheat production'], 1),
      _Q('Carbon dating is used for?',
          ['Estimating age of fossils and artifacts', 'Finding new elements',
           'Measuring radiation levels', 'Treating cancer'], 0),
      _Q('Neem is called a "wonder tree" because?',
          ['It grows very fast', 'It has pesticidal and medicinal properties',
           'It produces maximum oxygen', 'It fixes nitrogen'], 1),
      _Q('The concept of "Ecological Footprint" measures?',
          ['Carbon emission levels', 'Human demand on Earth\'s ecosystems',
           'Land degradation', 'Water consumption only'], 1),
      _Q('Which is the largest Tiger Reserve in India?',
          ['Jim Corbett', 'Nagarjunasagar-Srisailam', 'Sundarbans', 'Ranthambore'], 1),
      _Q('Nitrogen fixation is done by?',
          ['Penicillium', 'Rhizobium bacteria', 'Aspergillus', 'Yeast'], 1),
      _Q('Wetlands are important because?',
          ['They increase urban area', 'They act as "kidneys of the landscape" filtering water & supporting biodiversity',
           'They reduce rainfall', 'They provide only drinking water'], 1),
      _Q('Which radiation is most harmful to human body?',
          ['Alpha', 'Beta', 'Gamma', 'Infrared'], 2),
      _Q('The "Green House Effect" naturally keeps Earth warm; without it, Earth\'s temperature would be?',
          ['Same as now', 'About 33°C warmer', 'About 33°C colder', 'Extremely hot'], 2),
      _Q('"Montreal Protocol" deals with?',
          ['Greenhouse gases', 'Ozone depleting substances', 'Marine pollution', 'Biodiversity'], 1),
    ],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

enum _Stage { list, quiz, result }

class MockTestScreen extends StatefulWidget {
  final ApiService? api;
  const MockTestScreen({super.key, this.api});
  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  _Stage _stage   = _Stage.list;
  late _Pack _pack;
  Map<String, int> _bestScores = {};

  // API-loaded packs (null = not fetched yet, empty = API returned nothing)
  List<_Pack>? _apiPracticePacks;
  List<_Pack>? _apiPyqPacks;
  bool _packLoading = false; // loading questions for a specific pack

  // effective packs — API if loaded, else static
  List<_Pack> get _effectivePractice => (_apiPracticePacks != null && _apiPracticePacks!.isNotEmpty)
      ? _apiPracticePacks!
      : _practicePacks;
  List<_Pack> get _effectivePyq => (_apiPyqPacks != null && _apiPyqPacks!.isNotEmpty)
      ? _apiPyqPacks!
      : _pyqPacks;

  // quiz state
  int  _qIndex    = 0;
  int  _selected  = -1;
  bool _answered  = false;
  int  _score     = 0;
  List<int> _userAnswers = [];

  // timer
  static const _secsPerQ  = 30;
  int  _secsLeft  = _secsPerQ;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadBestScores();
    _loadApiPacks();
  }

  Future<void> _loadBestScores() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, int>{};
    for (final p in [..._practicePacks, ..._pyqPacks]) {
      map[p.id] = prefs.getInt('mock_best_${p.id}') ?? -1;
    }
    if (mounted) setState(() => _bestScores = map);
  }

  Future<void> _loadApiPacks() async {
    if (widget.api == null) return;
    try {
      final raw = await widget.api!.getMockTestPacks();
      if (raw == null || raw.isEmpty) return;

      final practice = <_Pack>[];
      final pyq = <_Pack>[];
      for (final p in raw) {
        final pack = _Pack(
          id:            p['pack_id'] as String,
          title:         p['title'] as String,
          subtitle:      (p['subtitle'] as String?) ?? '',
          emoji:         (p['emoji'] as String?) ?? '📝',
          color:         _colorFromHex((p['color_hex'] as String?) ?? '#1565C0'),
          isPyq:         p['is_pyq'] == true,
          questions:     const [],
          questionCount: p['question_count'] as int?,
        );
        if (pack.isPyq) pyq.add(pack); else practice.add(pack);
      }

      final prefs = await SharedPreferences.getInstance();
      final map = Map<String, int>.from(_bestScores);
      for (final p in [...practice, ...pyq]) {
        map[p.id] = prefs.getInt('mock_best_${p.id}') ?? -1;
      }
      if (mounted) setState(() {
        _apiPracticePacks = practice;
        _apiPyqPacks = pyq;
        _bestScores = map;
      });
    } catch (_) {}
  }

  static Color _colorFromHex(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF1565C0);
    }
  }

  Future<void> _saveBestScore(String id, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final prev = prefs.getInt('mock_best_$id') ?? -1;
    if (score > prev) {
      await prefs.setInt('mock_best_$id', score);
      setState(() => _bestScores[id] = score);
    }
  }

  void _startPack(_Pack pack) {
    setState(() {
      _pack        = pack;
      _qIndex      = 0;
      _selected    = -1;
      _answered    = false;
      _score       = 0;
      _secsLeft    = _secsPerQ;
      _userAnswers = [];
      _stage       = _Stage.quiz;
      _packLoading = false;
    });
    _startTimer();
  }

  /// Tap handler — lazily fetches questions for API packs if needed.
  Future<void> _tapPack(_Pack pack) async {
    if (pack.questions.isNotEmpty) {
      _startPack(pack);
      return;
    }
    // API pack with lazy questions
    if (widget.api == null) {
      // No API — try matching static fallback
      final local = [..._practicePacks, ..._pyqPacks]
          .where((p) => p.id == pack.id)
          .firstOrNull;
      if (local != null) _startPack(local);
      return;
    }
    setState(() => _packLoading = true);
    try {
      final raw = await widget.api!.getMockTestQuestions(pack.id);
      if (raw != null && raw.isNotEmpty) {
        final qs = raw.map((q) => _Q(
          q['question'] as String,
          List<String>.from(q['options'] as List),
          q['correct'] as int,
        )).toList();
        _startPack(_Pack(
          id: pack.id, title: pack.title, subtitle: pack.subtitle,
          emoji: pack.emoji, color: pack.color, isPyq: pack.isPyq,
          questions: qs,
        ));
        return;
      }
    } catch (_) {}
    setState(() => _packLoading = false);
    // Fallback to local pack
    final local = [..._practicePacks, ..._pyqPacks]
        .where((p) => p.id == pack.id)
        .firstOrNull;
    if (local != null) {
      _startPack(local);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Questions unavailable — check connection and try again'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secsLeft <= 1) {
        _timer?.cancel();
        if (!_answered) _submitAnswer(-1);
      } else {
        setState(() => _secsLeft--);
      }
    });
  }

  void _submitAnswer(int chosen) {
    if (_answered) return;
    _timer?.cancel();
    final correct = _pack.questions[_qIndex].ans;
    setState(() {
      _selected  = chosen;
      _answered  = true;
      if (chosen == correct) _score++;
      _userAnswers.add(chosen);
    });
  }

  void _nextQuestion() {
    if (_qIndex + 1 >= _pack.questions.length) {
      _saveBestScore(_pack.id, _score);
      setState(() => _stage = _Stage.result);
      return;
    }
    setState(() {
      _qIndex++;
      _selected  = -1;
      _answered  = false;
      _secsLeft  = _secsPerQ;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: switch (_stage) {
            _Stage.list   => _buildList(),
            _Stage.quiz   => _buildQuiz(),
            _Stage.result => _buildResult(),
          },
        ),
        if (_packLoading)
          const ColoredBox(
            color: Color(0x88000000),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  // ── Test List ─────────────────────────────────────────────────────────────

  Widget _buildList() {
    final practice   = _effectivePractice;
    final pyq        = _effectivePyq;
    final totalPacks = practice.length + pyq.length;
    final attempted  = _bestScores.values.where((s) => s >= 0).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(totalPacks, attempted)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(child: _sectionLabel('📚 Practice Tests', '${practice.length} sets')),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PackCard(
                  pack: practice[i],
                  bestScore: _bestScores[practice[i].id] ?? -1,
                  onTap: () => _tapPack(practice[i]),
                ),
              ),
              childCount: practice.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(child: _sectionLabel('🏆 Previous Year Papers', '${pyq.length} exams')),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PackCard(
                  pack: pyq[i],
                  bestScore: _bestScores[pyq[i].id] ?? -1,
                  onTap: () => _tapPack(pyq[i]),
                ),
              ),
              childCount: pyq.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(int total, int attempted) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📝 Mock Tests',
                            style: TextStyle(color: Colors.white, fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('SSC · RRB · Banking · UPSC — free practice',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Stats bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('${_practicePacks.length + _pyqPacks.length}', 'Test Sets'),
                  Container(width: 1, height: 30, color: Colors.white38),
                  _statItem('${_practicePacks.length * 15 + _pyqPacks.length * 15}', 'Questions'),
                  Container(width: 1, height: 30, color: Colors.white38),
                  _statItem('$attempted/$total', 'Attempted'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 18,
            fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
      ],
    );
  }

  Widget _sectionLabel(String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(sub, style: const TextStyle(fontSize: 11,
                color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Quiz ──────────────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    final q = _pack.questions[_qIndex];
    final total = _pack.questions.length;
    final timeProgress = _secsLeft / _secsPerQ;
    final timerColor = _secsLeft <= 10
        ? Colors.red
        : _secsLeft <= 20 ? Colors.orange : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => setState(() { _timer?.cancel(); _stage = _Stage.list; }),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_pack.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                if (_pack.isPyq) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF9933),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('PYQ',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                  ),
                                ],
                              ],
                            ),
                            Text('Q${_qIndex + 1} of $total',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: timerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: timerColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, size: 13, color: timerColor),
                            const SizedBox(width: 3),
                            Text('${_secsLeft}s', style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: timerColor)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$_score ✓', style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_qIndex + 1) / total,
                            minHeight: 4,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(_pack.color),
                          ),
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: timeProgress,
                            minHeight: 3,
                            backgroundColor: Colors.grey[100],
                            valueColor: AlwaysStoppedAnimation(timerColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Question + Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _pack.color.withValues(alpha: 0.2)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Text(q.q, style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.45)),
                    ),
                    const SizedBox(height: 14),
                    ...List.generate(4, (i) => _OptionTile(
                      label: String.fromCharCode(65 + i),
                      text: q.opts[i],
                      state: !_answered
                          ? _OptionState.normal
                          : i == q.ans
                              ? _OptionState.correct
                              : i == _selected
                                  ? _OptionState.wrong
                                  : _OptionState.normal,
                      selected: _selected == i,
                      onTap: _answered ? null : () => _submitAnswer(i),
                    )),
                    if (_answered) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selected == q.ans
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selected == q.ans
                                ? const Color(0xFF81C784)
                                : const Color(0xFFFFB74D),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _selected == q.ans ? '🎉' : (_selected == -1 ? '⏰' : '❌'),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selected == q.ans
                                    ? 'Correct! Well done.'
                                    : _selected == -1
                                        ? 'Time up!\nCorrect: ${q.opts[q.ans]}'
                                        : 'Wrong.\nCorrect: ${q.opts[q.ans]}',
                                style: const TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_answered)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pack.color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _qIndex + 1 < _pack.questions.length
                          ? 'Next Question →'
                          : 'See Results',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Result ────────────────────────────────────────────────────────────────

  Widget _buildResult() {
    final total = _pack.questions.length;
    final pct = _score / total;
    final (grade, msg, gradeColor) = pct >= 0.8
        ? ('Excellent! 🏆', 'Outstanding! You are exam-ready.', const Color(0xFF1A6B3C))
        : pct >= 0.6
            ? ('Good! 👍', 'Nice work! Review the ones you missed.', const Color(0xFF1565C0))
            : pct >= 0.4
                ? ('Average 📈', 'Keep practicing — you\'re improving!', const Color(0xFFE65100))
                : ('Needs Work 💪', 'Don\'t give up — practice daily!', const Color(0xFFB71C1C));

    final best = _bestScores[_pack.id] ?? _score;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Result header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradeColor, gradeColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(grade, style: const TextStyle(color: Colors.white,
                      fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(msg, textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _resultStat('$_score/$total', 'Score', Colors.white),
                      const SizedBox(width: 32),
                      _resultStat('${(pct * 100).round()}%', 'Accuracy', Colors.white),
                      const SizedBox(width: 32),
                      _resultStat('$best/${total}', 'Best', const Color(0xFFFFD700)),
                    ],
                  ),
                ],
              ),
            ),

            // Review list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _pack.questions.length,
                itemBuilder: (_, i) {
                  final q = _pack.questions[i];
                  final userAns = i < _userAnswers.length ? _userAnswers[i] : -1;
                  final correct = userAns == q.ans;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: correct ? const Color(0xFF81C784) : const Color(0xFFEF9A9A),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: correct ? const Color(0xFF1A6B3C) : const Color(0xFFB71C1C),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              correct ? Icons.check_rounded : Icons.close_rounded,
                              color: Colors.white, size: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Q${i + 1}. ${q.q}',
                                  style: const TextStyle(fontSize: 12.5,
                                      fontWeight: FontWeight.w600, height: 1.4)),
                              const SizedBox(height: 4),
                              if (!correct)
                                Text(
                                  'Your answer: ${userAns == -1 ? "Skipped (time up)" : q.opts[userAns]}',
                                  style: const TextStyle(fontSize: 11.5,
                                      color: Color(0xFFB71C1C)),
                                ),
                              Text('Correct: ${q.opts[q.ans]}',
                                  style: const TextStyle(fontSize: 11.5,
                                      color: Color(0xFF1A6B3C), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _stage = _Stage.list),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        side: BorderSide(color: _pack.color),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('All Tests',
                          style: TextStyle(color: _pack.color, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _startPack(_pack),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: _pack.color,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Retry',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultStat(String val, String label, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
      ],
    );
  }
}

// ── Pack Card ─────────────────────────────────────────────────────────────────

class _PackCard extends StatelessWidget {
  final _Pack pack;
  final int bestScore;  // -1 = never attempted
  final VoidCallback onTap;
  const _PackCard({required this.pack, required this.bestScore, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = pack.count;
    final hasBest = bestScore >= 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pack.color.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: pack.color.withValues(alpha: 0.07),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(width: 5, height: 82, color: pack.color),
              const SizedBox(width: 14),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: pack.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(pack.emoji, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(pack.title,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                          if (pack.isPyq) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9933),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('PYQ', style: TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(pack.subtitle,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.quiz_outlined, size: 12, color: pack.color),
                          const SizedBox(width: 3),
                          Text('$total Q  •  30s each',
                              style: TextStyle(fontSize: 11, color: pack.color,
                                  fontWeight: FontWeight.w600)),
                          if (hasBest) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                color: pack.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Best: $bestScore/$total',
                                  style: TextStyle(fontSize: 10, color: pack.color,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.play_circle_fill_rounded, color: pack.color, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Option Tile ───────────────────────────────────────────────────────────────

enum _OptionState { normal, correct, wrong }

class _OptionTile extends StatelessWidget {
  final String label, text;
  final _OptionState state;
  final bool selected;
  final VoidCallback? onTap;
  const _OptionTile({
    required this.label, required this.text,
    required this.state, required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border, textColor, labelBg) = switch (state) {
      _OptionState.correct => (
          const Color(0xFFE8F5E9), const Color(0xFF81C784),
          const Color(0xFF1A6B3C), const Color(0xFF1A6B3C)),
      _OptionState.wrong => (
          const Color(0xFFFFEBEE), const Color(0xFFEF9A9A),
          const Color(0xFFB71C1C), const Color(0xFFB71C1C)),
      _OptionState.normal => selected
          ? (const Color(0xFFE3F2FD), const Color(0xFF1565C0),
             const Color(0xFF1565C0), const Color(0xFF1565C0))
          : (Colors.white, const Color(0xFFE0E0E0),
             AppColors.textPrimary, const Color(0xFF9E9E9E)),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: labelBg, shape: BoxShape.circle),
              child: Center(
                child: Text(label, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(
                  fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
            ),
            if (state == _OptionState.correct)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF1A6B3C), size: 20),
            if (state == _OptionState.wrong)
              const Icon(Icons.cancel_rounded, color: Color(0xFFB71C1C), size: 20),
          ],
        ),
      ),
    );
  }
}
