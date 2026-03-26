// lib/screens/daily_quiz_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class _Q {
  final String q;
  final List<String> opts;
  final int ans;
  const _Q(this.q, this.opts, this.ans);
}

// 60 daily sets × 5 questions = 2-month rotation
// Topics: Polity, History, Geography, Science, Economy, Awards, Sports, Banking, Schemes
const _allSets = <List<_Q>>[
  // Day 0
  [
    _Q('Who is the constitutional head of India?', ['Prime Minister', 'Chief Justice', 'President', 'Lok Sabha Speaker'], 2),
    _Q('India\'s first satellite Aryabhata was launched in?', ['1972', '1975', '1980', '1969'], 1),
    _Q('National Animal of India is?', ['Lion', 'Elephant', 'Tiger', 'Leopard'], 2),
    _Q('Which river forms the Sunder­bans delta?', ['Ganga', 'Brahmaputra', 'Mahanadi', 'Krishna'], 0),
    _Q('The RBI was nationalized in which year?', ['1947', '1948', '1949', '1950'], 2),
  ],
  // Day 1
  [
    _Q('How many Fundamental Rights are in the Indian Constitution?', ['5', '6', '7', '8'], 1),
    _Q('Which is the largest planet in our solar system?', ['Saturn', 'Neptune', 'Jupiter', 'Uranus'], 2),
    _Q('Silent Valley National Park is in which state?', ['Tamil Nadu', 'Karnataka', 'Kerala', 'Andhra Pradesh'], 2),
    _Q('Who invented the telephone?', ['Thomas Edison', 'Nikola Tesla', 'Graham Bell', 'Marconi'], 2),
    _Q('The Quit India Movement was launched in?', ['1940', '1941', '1942', '1943'], 2),
  ],
  // Day 2
  [
    _Q('What is the capital of Australia?', ['Sydney', 'Melbourne', 'Canberra', 'Brisbane'], 2),
    _Q('Who was the first President of India?', ['Jawaharlal Nehru', 'B.R. Ambedkar', 'Rajendra Prasad', 'C. Rajagopalachari'], 2),
    _Q('Mount Everest is located in?', ['India', 'China', 'Nepal', 'Tibet'], 2),
    _Q('Which gas is most abundant in Earth\'s atmosphere?', ['Oxygen', 'Carbon Dioxide', 'Nitrogen', 'Hydrogen'], 2),
    _Q('India\'s National Flower is?', ['Rose', 'Marigold', 'Lotus', 'Sunflower'], 2),
  ],
  // Day 3
  [
    _Q('Who wrote "Arthashastra"?', ['Chandragupta', 'Kautilya', 'Ashoka', 'Vikramaditya'], 1),
    _Q('The speed of light is approximately?', ['3×10⁵ km/s', '3×10⁸ m/s', '3×10⁶ km/s', '3×10⁴ m/s'], 1),
    _Q('Which Article deals with Right to Equality?', ['Article 12', 'Article 14', 'Article 19', 'Article 21'], 1),
    _Q('Headquarters of UNESCO is in?', ['Geneva', 'New York', 'Paris', 'London'], 2),
    _Q('Who is called the "Iron Man of India"?', ['Bhagat Singh', 'Bal Gangadhar Tilak', 'Sardar Patel', 'Subhash Bose'], 2),
  ],
  // Day 4
  [
    _Q('Which river is known as the "Ganga of the South"?', ['Kaveri', 'Krishna', 'Godavari', 'Tungabhadra'], 2),
    _Q('INS Vikrant is a?', ['Submarine', 'Destroyer', 'Aircraft Carrier', 'Frigate'], 2),
    _Q('Chemical symbol of Gold?', ['Go', 'Gd', 'Au', 'Ag'], 2),
    _Q('Chipko Movement was related to?', ['Save Water', 'Save Trees', 'Save Animals', 'Save Rivers'], 1),
    _Q('GST in India was implemented on?', ['1 April 2017', '1 July 2017', '1 Jan 2017', '1 Oct 2016'], 1),
  ],
  // Day 5
  [
    _Q('India\'s National Sport is?', ['Cricket', 'Kabaddi', 'Hockey', 'Chess'], 2),
    _Q('Who invented the steam engine?', ['James Watt', 'Newton', 'Darwin', 'Faraday'], 0),
    _Q('"Battle of Plassey" was fought in?', ['1757', '1857', '1764', '1776'], 0),
    _Q('Which state has the most districts?', ['Maharashtra', 'Uttar Pradesh', 'Madhya Pradesh', 'Rajasthan'], 1),
    _Q('Headquarters of ISRO is in?', ['Mumbai', 'Hyderabad', 'Bengaluru', 'Chennai'], 2),
  ],
  // Day 6
  [
    _Q('India\'s highest civilian award is?', ['Padma Bhushan', 'Bharat Ratna', 'Padma Vibhushan', 'Padma Shri'], 1),
    _Q('Largest producer of milk in the world?', ['USA', 'Brazil', 'India', 'China'], 2),
    _Q('Durand Cup is associated with which sport?', ['Cricket', 'Hockey', 'Football', 'Tennis'], 2),
    _Q('Lakshadweep consists of how many islands?', ['23', '27', '32', '36'], 3),
    _Q('National Science Day is observed on?', ['January 28', 'February 28', 'March 28', 'April 28'], 1),
  ],
  // Day 7
  [
    _Q('"Do or Die" slogan was given by?', ['Nehru', 'Gandhi', 'Tilak', 'Bose'], 1),
    _Q('Which vitamin is produced from sunlight?', ['Vitamin A', 'Vitamin B12', 'Vitamin C', 'Vitamin D'], 3),
    _Q('Manas Wildlife Sanctuary is in?', ['Assam', 'Uttarakhand', 'Madhya Pradesh', 'Rajasthan'], 0),
    _Q('India\'s first Five-Year Plan started in?', ['1947', '1950', '1951', '1952'], 2),
    _Q('NITI Aayog replaced which body?', ['Planning Commission', 'Finance Commission', 'Election Commission', 'CAG'], 0),
  ],
  // Day 8
  [
    _Q('Kaziranga is famous for?', ['Bengal Tiger', 'Indian Elephant', 'One-horned Rhinoceros', 'Snow Leopard'], 2),
    _Q('Which planet is the "Red Planet"?', ['Venus', 'Jupiter', 'Mars', 'Saturn'], 2),
    _Q('Jalianwala Bagh Massacre occurred in?', ['1915', '1917', '1919', '1921'], 2),
    _Q('Headquarters of WTO is in?', ['Washington DC', 'London', 'Geneva', 'New York'], 2),
    _Q('Who designed the Indian Parliament building?', ['Edwin Lutyens', 'Herbert Baker', 'Charles Correa', 'Bimal Patel'], 1),
  ],
  // Day 9
  [
    _Q('"Theory of Relativity" was given by?', ['Newton', 'Darwin', 'Einstein', 'Bohr'], 2),
    _Q('Smallest country in the world?', ['Monaco', 'San Marino', 'Vatican City', 'Liechtenstein'], 2),
    _Q('PM Kisan Samman Nidhi provides per year?', ['₹2,000', '₹4,000', '₹6,000', '₹8,000'], 2),
    _Q('Currency of Japan?', ['Yuan', 'Won', 'Yen', 'Ringgit'], 2),
    _Q('Tropic of Cancer passes through how many Indian states?', ['6', '7', '8', '9'], 2),
  ],
  // Day 10
  [
    _Q('"Jai Jawan Jai Kisan" was given by?', ['Nehru', 'Shastri', 'Gandhi', 'Indira Gandhi'], 1),
    _Q('First Indian to go to space?', ['Sunita Williams', 'Kalpana Chawla', 'Rakesh Sharma', 'Ravish Malhotra'], 2),
    _Q('Article 19 of Constitution provides?', ['Right to Equality', 'Freedom of Speech', 'Right to Life', 'Right to Education'], 1),
    _Q('India became a Republic on?', ['15 Aug 1947', '26 Jan 1950', '26 Nov 1949', '15 Aug 1950'], 1),
    _Q('Decimal system was invented by?', ['Arabs', 'Greeks', 'Indians', 'Chinese'], 2),
  ],
  // Day 11
  [
    _Q('Largest ocean in the world?', ['Atlantic', 'Indian', 'Arctic', 'Pacific'], 3),
    _Q('Amartya Sen won Nobel Prize for?', ['Physics', 'Chemistry', 'Economics', 'Literature'], 2),
    _Q('NABARD was established in?', ['1980', '1981', '1982', '1983'], 2),
    _Q('Author of "Wings of Fire"?', ['Manmohan Singh', 'A.P.J. Abdul Kalam', 'Vikram Sarabhai', 'Homi Bhabha'], 1),
    _Q('Right to Education Act was passed in?', ['2007', '2008', '2009', '2010'], 2),
  ],
  // Day 12
  [
    _Q('The UN was established in?', ['1944', '1945', '1946', '1947'], 1),
    _Q('India\'s first nuclear power plant is at?', ['Kalpakkam', 'Tarapur', 'Narora', 'Kakrapar'], 1),
    _Q('Gas used in fire extinguishers?', ['Nitrogen', 'Oxygen', 'Carbon Dioxide', 'Helium'], 2),
    _Q('Ex-officio Chairman of Rajya Sabha?', ['President', 'Prime Minister', 'Vice President', 'Chief Justice'], 2),
    _Q('Palk Strait separates India from?', ['Bangladesh', 'Myanmar', 'Sri Lanka', 'Maldives'], 2),
  ],
  // Day 13
  [
    _Q('Indian Army Day is on?', ['15 January', '26 January', '15 August', '8 September'], 0),
    _Q('Pink City of India is?', ['Ahmedabad', 'Jodhpur', 'Jaipur', 'Udaipur'], 2),
    _Q('First artificial satellite was launched by?', ['USA', 'UK', 'USSR', 'China'], 2),
    _Q('Operation Flood was related to?', ['Flood management', 'Milk production', 'Wheat production', 'Fisheries'], 1),
    _Q('Dandi March took place in?', ['1928', '1930', '1932', '1935'], 1),
  ],
  // Day 14 — Polity
  [
    _Q('Which Schedule of the Constitution lists official languages?', ['6th', '7th', '8th', '9th'], 2),
    _Q('Impeachment of President is governed by which Article?', ['Article 56', 'Article 61', 'Article 65', 'Article 72'], 1),
    _Q('Fundamental Duties were added by which Constitutional Amendment?', ['40th', '42nd', '44th', '46th'], 1),
    _Q('Directive Principles of State Policy are in which Part of Constitution?', ['Part III', 'Part IV', 'Part V', 'Part VI'], 1),
    _Q('Which court is the Guardian of Fundamental Rights?', ['District Court', 'High Court', 'Supreme Court', 'Sessions Court'], 2),
  ],
  // Day 15 — Geography
  [
    _Q('Longest river in India is?', ['Yamuna', 'Ganga', 'Godavari', 'Brahmaputra'], 1),
    _Q('Highest peak entirely within India is?', ['K2', 'Kangchenjunga', 'Nanda Devi', 'Kamet'], 2),
    _Q('Largest state of India by area is?', ['Madhya Pradesh', 'Maharashtra', 'Rajasthan', 'Uttar Pradesh'], 2),
    _Q('Brahmaputra river is known as in China?', ['Mekong', 'Yangtze', 'Tsangpo', 'Irrawaddy'], 2),
    _Q('Chilika Lake is located in which state?', ['Andhra Pradesh', 'Tamil Nadu', 'West Bengal', 'Odisha'], 3),
  ],
  // Day 16 — Science
  [
    _Q('SI unit of electric current is?', ['Watt', 'Volt', 'Ampere', 'Ohm'], 2),
    _Q('Which gas is used in balloons?', ['Oxygen', 'Hydrogen', 'Nitrogen', 'Helium'], 3),
    _Q('Photosynthesis occurs in which part of a plant?', ['Root', 'Stem', 'Chloroplast', 'Mitochondria'], 2),
    _Q('Hardest natural substance on Earth?', ['Iron', 'Platinum', 'Diamond', 'Quartz'], 2),
    _Q('pH value of pure water is?', ['0', '5', '7', '14'], 2),
  ],
  // Day 17 — Economy
  [
    _Q('India\'s apex bank is?', ['SBI', 'NABARD', 'RBI', 'SEBI'], 2),
    _Q('SEBI regulates which sector?', ['Banking', 'Insurance', 'Capital Markets', 'Telecom'], 2),
    _Q('GDP stands for?', ['Gross Domestic Product', 'General Domestic Production', 'Gross Dollar Product', 'General Development Plan'], 0),
    _Q('Base year for current GDP calculation in India?', ['2004-05', '2011-12', '2016-17', '2019-20'], 1),
    _Q('Which committee recommended GST in India?', ['Kelkar Committee', 'Asim Das Gupta Committee', 'Chellaiah Committee', 'Narasimham Committee'], 1),
  ],
  // Day 18 — Modern History
  [
    _Q('Indian National Congress was founded in?', ['1875', '1880', '1885', '1892'], 2),
    _Q('First session of INC was held at?', ['Bombay', 'Calcutta', 'Lahore', 'Surat'], 0),
    _Q('Who presided the historic Lahore Session (1929) of INC?', ['Gandhiji', 'Bal Gangadhar Tilak', 'Jawaharlal Nehru', 'Subhash Bose'], 2),
    _Q('"Swaraj is my birthright" — said by?', ['Gandhiji', 'Bal Gangadhar Tilak', 'Bhagat Singh', 'Gokhale'], 1),
    _Q('Partition of Bengal took place in?', ['1901', '1903', '1905', '1907'], 2),
  ],
  // Day 19 — Awards & Honours
  [
    _Q('Nobel Peace Prize 2014 was awarded to?', ['Malala Yousafzai', 'Kailash Satyarthi', 'Both A and B', 'Nelson Mandela'], 2),
    _Q('Bharat Ratna is awarded by?', ['Prime Minister', 'President', 'Vice President', 'Parliament'], 1),
    _Q('First Indian woman to win an Olympic medal?', ['P.V. Sindhu', 'Sania Mirza', 'Karnam Malleswari', 'Mary Kom'], 2),
    _Q('Man Booker Prize is given for?', ['Science', 'Fiction literature', 'Peace', 'Economics'], 1),
    _Q('Dada Saheb Phalke Award is given for contributions to?', ['Indian Cinema', 'Indian Music', 'Indian Literature', 'Indian Dance'], 0),
  ],
  // Day 20 — Sports
  [
    _Q('Cricket World Cup 2011 was won by?', ['Australia', 'Sri Lanka', 'India', 'West Indies'], 2),
    _Q('India\'s first Olympic gold in Individual event was won by?', ['Sushil Kumar', 'Abhinav Bindra', 'Leander Paes', 'Vijay Amritraj'], 1),
    _Q('ICC headquarters is in?', ['London', 'Sydney', 'Dubai', 'New York'], 2),
    _Q('Davis Cup is associated with?', ['Cricket', 'Football', 'Tennis', 'Hockey'], 2),
    _Q('First Asian country to host the Olympic Games?', ['India', 'China', 'Japan', 'South Korea'], 2),
  ],
  // Day 21 — Banking & Finance
  [
    _Q('CRR is set by?', ['Government of India', 'RBI', 'SEBI', 'Finance Ministry'], 1),
    _Q('Repo Rate is the rate at which?', ['Banks borrow from RBI', 'RBI borrows from banks', 'Banks lend to public', 'Govt borrows from RBI'], 0),
    _Q('NEFT stands for?', ['National Electronic Funds Transfer', 'Net Electronic Financial Transfer', 'National Effective Finance Transfer', 'None'], 0),
    _Q('First bank established in India?', ['Bank of Hindustan', 'SBI', 'Bank of Bombay', 'Allahabad Bank'], 0),
    _Q('NABARD provides finance to?', ['Industry', 'Trade', 'Agriculture & Rural Development', 'Infrastructure'], 2),
  ],
  // Day 22 — Ancient History
  [
    _Q('Harappan Civilisation belongs to which age?', ['Paleolithic', 'Neolithic', 'Chalcolithic', 'Bronze Age'], 3),
    _Q('Megasthenes was ambassador of which ruler?', ['Chandragupta Maurya', 'Ashoka', 'Bindusara', 'Kanishka'], 0),
    _Q('"Indica" was written by?', ['Kautilya', 'Megasthenes', 'Strabo', 'Fahien'], 1),
    _Q('First Jain Tirthankara was?', ['Parshva', 'Mahavira', 'Rishabhanatha', 'Neminatha'], 2),
    _Q('Ajanta Caves are located in?', ['Karnataka', 'Maharashtra', 'Madhya Pradesh', 'Rajasthan'], 1),
  ],
  // Day 23 — Science: Biology
  [
    _Q('Which organ produces insulin?', ['Liver', 'Kidney', 'Pancreas', 'Spleen'], 2),
    _Q('Deficiency of Vitamin C causes?', ['Rickets', 'Night blindness', 'Scurvy', 'Beri-beri'], 2),
    _Q('DNA stands for?', ['Deoxyribonucleic Acid', 'Diribonucleic Acid', 'Deoxyribonicotinic Acid', 'Dinuclear Acid'], 0),
    _Q('Largest gland in human body?', ['Kidney', 'Heart', 'Liver', 'Pancreas'], 2),
    _Q('Blood group discovered by?', ['Louis Pasteur', 'Karl Landsteiner', 'Alexander Fleming', 'William Harvey'], 1),
  ],
  // Day 24 — Indian Schemes
  [
    _Q('Pradhan Mantri Jan Dhan Yojana aims at?', ['Crop insurance', 'Financial inclusion', 'Rural employment', 'Housing'], 1),
    _Q('MGNREGS guarantees employment for how many days per year?', ['90', '100', '150', '200'], 1),
    _Q('Beti Bachao Beti Padhao was launched from?', ['Panipat', 'Panaji', 'Agra', 'Lucknow'], 0),
    _Q('PM Ujjwala Yojana provides?', ['Free electricity', 'LPG connections to BPL women', 'Solar panels', 'Water connections'], 1),
    _Q('Swachh Bharat Mission was launched on?', ['2 Oct 2014', '26 Jan 2015', '15 Aug 2014', '1 April 2014'], 0),
  ],
  // Day 25 — Polity
  [
    _Q('India\'s Constitution came into force on?', ['15 Aug 1947', '26 Nov 1949', '26 Jan 1950', '2 Oct 1951'], 2),
    _Q('Who is the Father of Indian Constitution?', ['Jawaharlal Nehru', 'Sardar Patel', 'B.R. Ambedkar', 'Rajendra Prasad'], 2),
    _Q('Emergency under Article 352 is called?', ['President\'s Rule', 'Financial Emergency', 'National Emergency', 'Constitutional Emergency'], 2),
    _Q('Right to Education is under which Article?', ['Article 19', 'Article 21', 'Article 21A', 'Article 29'], 2),
    _Q('India has how many Union Territories?', ['5', '6', '7', '8'], 3),
  ],
  // Day 26 — Geography
  [
    _Q('Laterite soil is found in?', ['Rajasthan', 'Punjab', 'Kerala and Karnataka', 'Uttar Pradesh'], 2),
    _Q('Project Tiger was launched in?', ['1971', '1973', '1975', '1980'], 1),
    _Q('Sundarbans is famous for?', ['Indian Lion', 'Royal Bengal Tiger', 'Snow Leopard', 'Asiatic Elephant'], 1),
    _Q('Which state has the largest forest cover in India?', ['Arunachal Pradesh', 'Madhya Pradesh', 'Chhattisgarh', 'Assam'], 1),
    _Q('Bhakra Nangal dam is on which river?', ['Yamuna', 'Sutlej', 'Beas', 'Chenab'], 1),
  ],
  // Day 27 — Science: Chemistry
  [
    _Q('Chemical formula of table salt?', ['NaOH', 'Na₂CO₃', 'NaCl', 'NaHCO₃'], 2),
    _Q('Which element has the symbol Fe?', ['Fluorine', 'Francium', 'Iron', 'Fermium'], 2),
    _Q('Acid rain is caused by?', ['CO₂ and O₂', 'SO₂ and NO₂', 'N₂ and H₂', 'O₃ and CO'], 1),
    _Q('LPG is mainly composed of?', ['Methane', 'Ethane', 'Propane and Butane', 'Acetylene'], 2),
    _Q('Ozone layer is found in?', ['Troposphere', 'Stratosphere', 'Mesosphere', 'Thermosphere'], 1),
  ],
  // Day 28 — Medieval History
  [
    _Q('Battle of Panipat (1526) was fought between?', ['Akbar & Hemu', 'Babur & Ibrahim Lodi', 'Humayun & Sher Shah', 'Babur & Rana Sanga'], 1),
    _Q('Who built the Taj Mahal?', ['Akbar', 'Jahangir', 'Shah Jahan', 'Aurangzeb'], 2),
    _Q('Akbar\'s finance minister was?', ['Birbal', 'Man Singh', 'Todar Mal', 'Abul Fazl'], 2),
    _Q('Sher Shah Suri introduced which currency?', ['Tanka', 'Rupiya', 'Paisa', 'Dinar'], 1),
    _Q('Din-i-Ilahi was founded by?', ['Babur', 'Humayun', 'Akbar', 'Aurangzeb'], 2),
  ],
  // Day 29 — Indian Economy
  [
    _Q('India is a _____ economy?', ['Capitalist', 'Socialist', 'Mixed', 'Communist'], 2),
    _Q('Planning Commission was replaced by NITI Aayog in?', ['2013', '2014', '2015', '2016'], 2),
    _Q('National Income of India is estimated by?', ['RBI', 'CSO (MOSPI)', 'Finance Ministry', 'NITI Aayog'], 1),
    _Q('The Economic Survey is published by?', ['RBI', 'Ministry of Finance', 'NITI Aayog', 'Ministry of Commerce'], 1),
    _Q('India\'s largest trading partner is?', ['USA', 'UAE', 'China', 'Saudi Arabia'], 2),
  ],
  // Day 30 — Science: Physics
  [
    _Q('Newton\'s first law is also called?', ['Law of Gravitation', 'Law of Inertia', 'Law of Momentum', 'Law of Acceleration'], 1),
    _Q('Speed of sound in air is approximately?', ['340 m/s', '3×10⁸ m/s', '1500 m/s', '150 m/s'], 0),
    _Q('Which mirror is used in vehicles\' rear-view mirrors?', ['Plane', 'Concave', 'Convex', 'Cylindrical'], 2),
    _Q('Decibel (dB) is a unit of?', ['Light intensity', 'Sound intensity', 'Electric current', 'Frequency'], 1),
    _Q('The SI unit of power is?', ['Joule', 'Newton', 'Watt', 'Pascal'], 2),
  ],
  // Day 31 — Sports & Games
  [
    _Q('Arjuna Award is given for excellence in?', ['Sports', 'Science', 'Arts', 'Social service'], 0),
    _Q('The term "Grand Slam" is associated with?', ['Cricket', 'Football', 'Tennis', 'Golf'], 2),
    _Q('India won its first Hockey World Cup in?', ['1971', '1975', '1980', '1983'], 1),
    _Q('The Santosh Trophy is related to?', ['Hockey', 'Cricket', 'Football', 'Badminton'], 2),
    _Q('"The Golden Girl" of Indian athletics is?', ['P.T. Usha', 'Sania Mirza', 'Mary Kom', 'Anju Bobby George'], 0),
  ],
  // Day 32 — International Organizations
  [
    _Q('IMF stands for?', ['International Monetary Fund', 'Indian Money Fund', 'International Market Foundation', 'None'], 0),
    _Q('Headquarters of United Nations is in?', ['Washington DC', 'London', 'Geneva', 'New York'], 3),
    _Q('How many permanent members does the UN Security Council have?', ['3', '5', '7', '10'], 1),
    _Q('World Health Organization HQ is in?', ['New York', 'Paris', 'Geneva', 'London'], 2),
    _Q('SAARC headquarters is in?', ['New Delhi', 'Islamabad', 'Colombo', 'Kathmandu'], 3),
  ],
  // Day 33 — Indian Polity
  [
    _Q('Rajya Sabha has how many nominated members?', ['2', '10', '12', '15'], 2),
    _Q('Who appoints the Chief Election Commissioner?', ['Prime Minister', 'Parliament', 'President', 'Chief Justice'], 2),
    _Q('The 73rd Amendment Act deals with?', ['Municipalities', 'Panchayati Raj', 'Languages', 'Scheduled Tribes'], 1),
    _Q('Zero Hour in Parliament starts at?', ['10 AM', '11 AM', '12 PM', '1 PM'], 2),
    _Q('The Comptroller and Auditor General is appointed by?', ['Prime Minister', 'President', 'Speaker', 'Finance Minister'], 1),
  ],
  // Day 34 — Indian Geography
  [
    _Q('Siachen Glacier is located in?', ['Himachal Pradesh', 'Uttarakhand', 'Jammu & Kashmir / Ladakh', 'Sikkim'], 2),
    _Q('Which is the longest National Highway in India?', ['NH 44', 'NH 27', 'NH 48', 'NH 16'], 0),
    _Q('India shares the longest border with?', ['China', 'Pakistan', 'Bangladesh', 'Nepal'], 2),
    _Q('The Deccan Plateau is mainly composed of?', ['Limestone rocks', 'Igneous rocks (Basalt)', 'Sedimentary rocks', 'Metamorphic rocks'], 1),
    _Q('Western Ghats are also known as?', ['Sahyadris', 'Vindhyas', 'Aravalli', 'Satpura'], 0),
  ],
  // Day 35 — Science: General
  [
    _Q('Laughing gas is?', ['N₂', 'N₂O', 'NO₂', 'NO'], 1),
    _Q('Who invented the computer?', ['Bill Gates', 'Charles Babbage', 'Alan Turing', 'Steve Jobs'], 1),
    _Q('Malaria is caused by?', ['Bacteria', 'Virus', 'Protozoan (Plasmodium)', 'Fungus'], 2),
    _Q('Richter scale measures?', ['Wind speed', 'Temperature', 'Earthquake intensity', 'Rainfall'], 2),
    _Q('Filament of an electric bulb is made of?', ['Copper', 'Aluminium', 'Tungsten', 'Iron'], 2),
  ],
  // Day 36 — Indian History
  [
    _Q('Who established the Mughal Empire in India?', ['Humayun', 'Akbar', 'Babur', 'Timur'], 2),
    _Q('Chauri Chaura incident occurred in?', ['1919', '1920', '1922', '1930'], 2),
    _Q('Simon Commission visited India in?', ['1925', '1927', '1928', '1930'], 2),
    _Q('Who founded the Arya Samaj?', ['Raja Ram Mohan Roy', 'Swami Vivekananda', 'Dayanand Saraswati', 'Annie Besant'], 2),
    _Q('Vernacular Press Act was passed in?', ['1876', '1878', '1880', '1882'], 1),
  ],
  // Day 37 — Banking
  [
    _Q('KYC stands for?', ['Know Your Customer', 'Know Your Credit', 'Know Your Currency', 'Know Your Costs'], 0),
    _Q('Which is the first payment bank of India?', ['Airtel Payment Bank', 'Paytm Payment Bank', 'India Post Payment Bank', 'FINO Payment Bank'], 0),
    _Q('SWIFT is related to?', ['Banking communication network', 'Stock exchange', 'Insurance', 'Taxation'], 0),
    _Q('A crossed cheque can be encashed at?', ['Any bank counter', 'Only payee\'s bank account', 'Post office', 'ATM'], 1),
    _Q('Which bank was the first to introduce ATM in India?', ['SBI', 'HSBC', 'Citibank', 'Punjab National Bank'], 2),
  ],
  // Day 38 — General Knowledge
  [
    _Q('Who wrote "The God of Small Things"?', ['Arundhati Roy', 'Vikram Seth', 'Amitav Ghosh', 'Salman Rushdie'], 0),
    _Q('The first Indian to climb Mount Everest?', ['Bachendri Pal', 'Tenzing Norgay', 'Edmund Hillary', 'Arunima Sinha'], 1),
    _Q('National Calendar of India is based on?', ['Gregorian calendar', 'Saka Era', 'Vikram Samvat', 'Hijri calendar'], 1),
    _Q('The study of flag is called?', ['Philately', 'Numismatics', 'Vexillology', 'Heraldry'], 2),
    _Q('Which city is called the "Silicon Valley of India"?', ['Mumbai', 'Delhi', 'Hyderabad', 'Bengaluru'], 3),
  ],
  // Day 39 — Polity: Elections & Rights
  [
    _Q('Minimum age to vote in India?', ['16', '18', '21', '25'], 1),
    _Q('Minimum age to become President of India?', ['25', '30', '35', '40'], 2),
    _Q('Article 32 of the Constitution deals with?', ['Right to Equality', 'Right against Exploitation', 'Right to Constitutional Remedies', 'Right to Religion'], 2),
    _Q('By which writ, a person is produced before court?', ['Mandamus', 'Habeas Corpus', 'Certiorari', 'Quo Warranto'], 1),
    _Q('The Preamble of the Constitution can be amended by?', ['Simple majority', 'Special majority', 'Special majority + state ratification', 'It cannot be amended'], 1),
  ],
  // Day 40 — Science: Space & Technology
  [
    _Q('India\'s first moon mission was?', ['Mangalyaan', 'Chandrayaan-1', 'Chandrayaan-2', 'Gaganyaan'], 1),
    _Q('ISRO was established in?', [' 1962', '1969', '1975', '1980'], 1),
    _Q('India\'s first indigenously built aircraft carrier is?', ['INS Vikramaditya', 'INS Viraat', 'INS Vikrant', 'INS Arihant'], 2),
    _Q('Chandrayaan-3 successfully landed on Moon in?', ['2022', '2023', '2024', '2021'], 1),
    _Q('What does GPS stand for?', ['Global Positioning System', 'General Postal Service', 'Geographical Projection System', 'Ground Patrol Service'], 0),
  ],
  // Day 41 — Indian Economy
  [
    _Q('MUDRA Bank provides loans to?', ['Large enterprises', 'Micro and small enterprises', 'Farmers', 'Government projects'], 1),
    _Q('Jan Dhan Yojana was launched in?', ['2013', '2014', '2015', '2016'], 1),
    _Q('The Monetary Policy in India is decided by?', ['Government of India', 'RBI Monetary Policy Committee', 'Finance Commission', 'NITI Aayog'], 1),
    _Q('Which is not a direct tax?', ['Income Tax', 'Corporate Tax', 'GST', 'Capital Gains Tax'], 2),
    _Q('WPI stands for?', ['Wholesale Price Index', 'Worldwide Price Index', 'Weighted Price Indicator', 'Worker Pay Index'], 0),
  ],
  // Day 42 — Geography: Rivers
  [
    _Q('Which river is known as the "Sorrow of China"?', ['Yangtze', 'Yellow River (Huang He)', 'Pearl River', 'Mekong'], 1),
    _Q('Godavari river originates from?', ['Nasik (Maharashtra)', 'Nagpur', 'Pune', 'Hyderabad'], 0),
    _Q('Which river flows between Vindhya and Satpura ranges?', ['Narmada', 'Tapti', 'Mahanadi', 'Chambal'], 0),
    _Q('Tehri Dam is built on which river?', ['Ganga', 'Bhagirathi', 'Yamuna', 'Sutlej'], 1),
    _Q('The river Luni drains into?', ['Bay of Bengal', 'Arabian Sea', 'Rann of Kutch', 'Indian Ocean'], 2),
  ],
  // Day 43 — Books & Authors
  [
    _Q('"My Experiments with Truth" was written by?', ['Nehru', 'Gandhi', 'Ambedkar', 'Rajagopalachari'], 1),
    _Q('"Discovery of India" was written during imprisonment at?', ['Andaman', 'Yerwada', 'Almora', 'Ahmednagar Fort'], 3),
    _Q('"Annihilation of Caste" was written by?', ['B.R. Ambedkar', 'Periyar', 'Jyotirao Phule', 'Ram Manohar Lohia'], 0),
    _Q('"The White Tiger" author is?', ['Amitav Ghosh', 'Aravind Adiga', 'Kiran Desai', 'Arundhati Roy'], 1),
    _Q('"Gitanjali" was written by?', ['Bankim Chandra', 'Rabindranath Tagore', 'Subramania Bharati', 'Sarojini Naidu'], 1),
  ],
  // Day 44 — Defence & Borders
  [
    _Q('Line of Actual Control (LAC) is between India and?', ['Pakistan', 'Bangladesh', 'China', 'Nepal'], 2),
    _Q('India\'s first nuclear submarine is?', ['INS Vikrant', 'INS Arihant', 'INS Chakra', 'INS Sindhushastra'], 1),
    _Q('Operation Blue Star was conducted in?', ['1982', '1984', '1986', '1988'], 1),
    _Q('Durand Line separates India (before 1947) from?', ['Iran', 'Afghanistan', 'Myanmar', 'Tibet'], 1),
    _Q('National Security Guard (NSG) is also known as?', ['Black Cats', 'White Tigers', 'Grey Wolves', 'Red Eagles'], 0),
  ],
  // Day 45 — SSC / Reasoning Related GK
  [
    _Q('Number of High Courts in India?', ['21', '24', '25', '28'], 2),
    _Q('Which state has the most Lok Sabha seats?', ['Maharashtra', 'Madhya Pradesh', 'Bihar', 'Uttar Pradesh'], 3),
    _Q('Total Lok Sabha seats?', ['525', '543', '545', '552'], 1),
    _Q('Governor is appointed by?', ['Prime Minister', 'Chief Minister', 'President', 'Rajya Sabha'], 2),
    _Q('Minimum strength of Rajya Sabha to be deemed a quorum?', ['1/10th', '1/5th', '1/3rd', '1/2'], 0),
  ],
  // Day 46 — Environment
  [
    _Q('Kyoto Protocol deals with?', ['Ozone depletion', 'Greenhouse gas emissions', 'Biodiversity', 'Marine pollution'], 1),
    _Q('COP stands for?', ['Conference of Parties', 'Committee of Pollution', 'Council of Preservation', 'Centre of Planning'], 0),
    _Q('Red Data Book lists?', ['Invasive species', 'Endangered species', 'Extinct species', 'Protected trees'], 1),
    _Q('Biosphere Reserve concept was given by?', ['UNEP', 'UNESCO', 'WWF', 'IUCN'], 1),
    _Q('India\'s first Biosphere Reserve is?', ['Nilgiri', 'Sundarbans', 'Nanda Devi', 'Gulf of Mannar'], 0),
  ],
  // Day 47 — Computer & Technology
  [
    _Q('CPU stands for?', ['Central Processing Unit', 'Computer Processing Unit', 'Central Program Unit', 'Central Peripheral Unit'], 0),
    _Q('Who is the founder of Microsoft?', ['Steve Jobs', 'Larry Page', 'Bill Gates', 'Mark Zuckerberg'], 2),
    _Q('HTTP stands for?', ['HyperText Transfer Protocol', 'High Text Transfer Protocol', 'Hyper Transfer Text Protocol', 'None'], 0),
    _Q('1 GB equals?', ['1000 MB', '1024 MB', '512 MB', '2048 MB'], 1),
    _Q('Which is NOT an input device?', ['Mouse', 'Keyboard', 'Scanner', 'Printer'], 3),
  ],
  // Day 48 — Current Affairs based GK
  [
    _Q('G20 Summit 2023 was hosted by?', ['USA', 'Saudi Arabia', 'India', 'Japan'], 2),
    _Q('India\'s National Emblem is adopted from?', ['Sarnath Lion Capital', 'Sanchi Stupa', 'Konark Sun Temple', 'Ajanta Caves'], 0),
    _Q('Digital India programme was launched in?', ['2014', '2015', '2016', '2017'], 1),
    _Q('India\'s GDP is _____ largest in the world (PPP)?', ['2nd', '3rd', '4th', '5th'], 1),
    _Q('India\'s space agency ISRO headquarters is in?', ['Mumbai', 'Hyderabad', 'Bengaluru', 'Chennai'], 2),
  ],
  // Day 49 — Ancient India
  [
    _Q('Vedas are how many in number?', ['2', '3', '4', '6'], 2),
    _Q('The concept of Zero was given by?', ['Aryabhata', 'Brahmagupta', 'Bhaskaracharya', 'Chanakya'], 1),
    _Q('Nalanda University was in?', ['Uttar Pradesh', 'Bihar', 'Madhya Pradesh', 'West Bengal'], 1),
    _Q('The Maurya Empire was founded in?', ['300 BCE', '322 BCE', '273 BCE', '185 BCE'], 1),
    _Q('Huen Tsang visited India during the reign of?', ['Chandragupta II', 'Harsha', 'Ashoka', 'Kanishka'], 1),
  ],
  // Day 50 — Miscellaneous
  [
    _Q('World\'s longest wall is?', ['Berlin Wall', 'Great Wall of China', 'Hadrian\'s Wall', 'Walls of Constantinople'], 1),
    _Q('Largest democracy in the world is?', ['USA', 'Brazil', 'India', 'UK'], 2),
    _Q('The term "BRICS" includes which country NOT bordering India?', ['Russia', 'China', 'South Africa', 'Brazil'], 3),
    _Q('First country to give women the right to vote?', ['USA', 'UK', 'New Zealand', 'France'], 2),
    _Q('United Nations Day is observed on?', ['24 October', '10 November', '1 January', '7 April'], 0),
  ],
  // Day 51 — Indian Polity
  [
    _Q('Which Article abolishes untouchability?', ['Article 15', 'Article 16', 'Article 17', 'Article 18'], 2),
    _Q('Finance Bill is presented along with?', ['Budget', 'Economic Survey', 'Annual Report', 'CAG Report'], 0),
    _Q('Rajya Sabha is a?', ['Temporary House', 'Permanent House', 'Both', 'None'], 1),
    _Q('Anti-defection law is in which Schedule?', ['8th', '9th', '10th', '11th'], 2),
    _Q('Constitutional Amendment Bill must be passed by?', ['Simple majority', '2/3 majority in both Houses', 'President\'s approval only', '3/4 majority'], 1),
  ],
  // Day 52 — Science: Health
  [
    _Q('Which vitamin is essential for clotting of blood?', ['Vitamin A', 'Vitamin C', 'Vitamin D', 'Vitamin K'], 3),
    _Q('BCG vaccine is given for?', ['Polio', 'Tuberculosis', 'Cholera', 'Tetanus'], 1),
    _Q('Normal body temperature is?', ['35°C', '36°C', '37°C', '38°C'], 2),
    _Q('Deficiency of iron causes?', ['Anaemia', 'Goitre', 'Rickets', 'Scurvy'], 0),
    _Q('Which blood group is universal donor?', ['A', 'B', 'AB', 'O'], 3),
  ],
  // Day 53 — Economy: Trade
  [
    _Q('India\'s largest export partner in 2023?', ['China', 'UAE', 'USA', 'UK'], 2),
    _Q('Which organisation governs world trade?', ['World Bank', 'IMF', 'WTO', 'ADB'], 2),
    _Q('Special Economic Zones (SEZ) in India were introduced in?', ['1999', '2000', '2005', '2010'], 1),
    _Q('Foreign Exchange Reserves of India are maintained by?', ['Government of India', 'RBI', 'SEBI', 'Finance Ministry'], 1),
    _Q('Balance of Trade means?', ['Difference between imports and exports', 'Total foreign debt', 'Value of GDP', 'Exchange rate'], 0),
  ],
  // Day 54 — Geography: Mountains & Climate
  [
    _Q('Highest peak in the world?', ['Kangchenjunga', 'K2', 'Mount Everest', 'Lhotse'], 2),
    _Q('Indian monsoon comes from?', ['Northeast', 'Northwest', 'Southwest', 'Southeast'], 2),
    _Q('Mawsynram, receiving highest rainfall, is in?', ['Assam', 'Kerala', 'Meghalaya', 'Arunachal Pradesh'], 2),
    _Q('Western Disturbances cause rainfall in?', ['South India', 'Northeast India', 'Northwest India in winter', 'Central India'], 2),
    _Q('Himalayan range extends over how many countries?', ['3', '4', '5', '6'], 2),
  ],
  // Day 55 — Modern History: Freedom Struggle
  [
    _Q('The Non-Cooperation Movement started in?', ['1919', '1920', '1921', '1922'], 1),
    _Q('Founder of the Indian National Army (INA)?', ['Subhash Bose', 'Mohan Singh', 'Bhagat Singh', 'Bal Gangadhar Tilak'], 1),
    _Q('Rowlatt Act was passed in?', ['1917', '1918', '1919', '1920'], 2),
    _Q('Jallianwala Bagh massacre was ordered by?', ['General Dyer', 'Lord Curzon', 'Lord Mountbatten', 'Lord Wavell'], 0),
    _Q('Indian Independence Act was passed by British Parliament in?', ['1946', '1947', '1948', '1945'], 1),
  ],
  // Day 56 — Awards & Culture
  [
    _Q('Sangeet Natak Akademi promotes?', ['Performing Arts', 'Literature', 'Visual Arts', 'Sports'], 0),
    _Q('India\'s highest sporting honour is?', ['Arjuna Award', 'Dronacharya Award', 'Rajiv Gandhi Khel Ratna', 'Dhyan Chand Award'], 2),
    _Q('UNESCO intangible cultural heritage: Yoga was included in?', ['2014', '2016', '2018', '2019'], 1),
    _Q('Sahitya Akademi Award is given for?', ['Outstanding contribution to Indian literature', 'Film', 'Music', 'Dance'], 0),
    _Q('Ram Nath Kovind was India\'s _____ President?', ['13th', '14th', '15th', '16th'], 1),
  ],
  // Day 57 — SSC Science
  [
    _Q('Rusting of iron is a?', ['Physical change', 'Chemical change', 'Biological change', 'Nuclear change'], 1),
    _Q('Milk is which type of mixture?', ['Solution', 'Compound', 'Colloid (Emulsion)', 'Suspension'], 2),
    _Q('Which mirror forms a virtual, erect, diminished image?', ['Concave', 'Plane', 'Convex', 'All mirrors'], 2),
    _Q('Loudness of sound depends on?', ['Frequency', 'Amplitude', 'Wavelength', 'Speed'], 1),
    _Q('Electric fuse is made of?', ['Copper', 'Aluminium', 'Tin-lead alloy', 'Tungsten'], 2),
  ],
  // Day 58 — Current Schemes & Committees
  [
    _Q('Atal Pension Yojana targets?', ['Government employees', 'Unorganised sector workers', 'Farmers', 'Students'], 1),
    _Q('PM Awas Yojana aims at?', ['Education for all', 'Housing for all', 'Food security', 'Clean drinking water'], 1),
    _Q('Jal Jeevan Mission target is?', ['Tap water to every rural household by 2024', 'Clean energy to villages', 'Rural roads', 'Digital connectivity'], 0),
    _Q('Skill India Mission was launched in?', ['2014', '2015', '2016', '2017'], 1),
    _Q('Make in India initiative focuses on?', ['Agriculture', 'Manufacturing & investment', 'IT exports', 'Tourism'], 1),
  ],
  // Day 59 — Indian Polity: Judiciary
  [
    _Q('Supreme Court of India was established in?', ['1947', '1948', '1950', '1952'], 2),
    _Q('Who appoints judges of the Supreme Court?', ['Prime Minister', 'Parliament', 'President', 'Chief Justice'], 2),
    _Q('The concept of "Basic Structure" of Constitution was given in?', ['Golaknath case', 'Minerva Mills case', 'Kesavananda Bharati case', 'Maneka Gandhi case'], 2),
    _Q('Judicial Review in India is inspired by?', ['UK', 'USA', 'France', 'Ireland'], 1),
    _Q('High Court judges retire at age?', ['60', '62', '65', '68'], 2),
  ],
];

class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  List<_Q>? _questions;
  int _qIndex = 0;
  int? _selected;
  bool _answered = false;
  int _score = 0;
  bool _done = false;
  bool _alreadyPlayed = false;
  int _streak = 0;
  int _todayScore = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    _streak = prefs.getInt('quiz_streak') ?? 0;

    if (prefs.containsKey('quiz_score_$today')) {
      _todayScore = prefs.getInt('quiz_score_$today') ?? 0;
      _alreadyPlayed = true;
    }

    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final setIndex = dayOfYear % _allSets.length;

    setState(() {
      _questions = _allSets[setIndex];
      _loading = false;
    });
  }

  String _todayKey() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _onFinish() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    final lastDate = prefs.getString('quiz_last_date') ?? '';
    final newStreak = lastDate == yesterday ? _streak + 1 : 1;

    await prefs.setString('quiz_last_date', today);
    await prefs.setInt('quiz_streak', newStreak);
    await prefs.setInt('quiz_score_$today', _score);

    setState(() { _done = true; _streak = newStreak; });
  }

  void _answer(int idx) {
    if (_answered) return;
    setState(() {
      _selected = idx;
      _answered = true;
      if (idx == _questions![_qIndex].ans) _score++;
    });
  }

  void _next() {
    if (_qIndex + 1 >= _questions!.length) {
      _onFinish();
      return;
    }
    setState(() {
      _qIndex++;
      _selected = null;
      _answered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _alreadyPlayed
          ? _buildAlreadyPlayed()
          : _done
              ? _buildResult()
              : _buildQuiz(),
    );
  }

  // ── Header (shared) ─────────────────────────────────────────
  Widget _header(String title, String subtitle) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
              const Spacer(),
              _buildStreakBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakBadge() {
    if (_streak == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text('$_streak day streak',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Quiz UI ──────────────────────────────────────────────────
  Widget _buildQuiz() {
    final qs = _questions!;
    final q = qs[_qIndex];
    final progress = (_qIndex + 1) / qs.length;

    return Column(
      children: [
        _header('Daily GK Quiz', 'Question ${_qIndex + 1} of ${qs.length}'),
        // Progress bar
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6A1B9A)),
          minHeight: 4,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Question
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Text(q.q,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.5, color: AppColors.textPrimary)),
                ),
                const SizedBox(height: 16),
                // Options
                ...List.generate(q.opts.length, (i) {
                  Color bg = Colors.white;
                  Color border = Colors.grey.withValues(alpha: 0.2);
                  Color text = AppColors.textPrimary;
                  Widget? trailing;

                  if (_answered) {
                    if (i == q.ans) {
                      bg = const Color(0xFFE8F5E9);
                      border = const Color(0xFF2E7D32);
                      text = const Color(0xFF1B5E20);
                      trailing = const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 20);
                    } else if (i == _selected) {
                      bg = const Color(0xFFFFEBEE);
                      border = const Color(0xFFD32F2F);
                      text = const Color(0xFFB71C1C);
                      trailing = const Icon(Icons.cancel_rounded, color: Color(0xFFD32F2F), size: 20);
                    }
                  } else if (_selected == i) {
                    bg = const Color(0xFFEDE7F6);
                    border = const Color(0xFF6A1B9A);
                    text = const Color(0xFF4A148C);
                  }

                  return GestureDetector(
                    onTap: () => _answer(i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: border.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: border),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(q.opts[i], style: TextStyle(fontSize: 14, color: text, fontWeight: FontWeight.w500))),
                          if (trailing != null) trailing,
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                if (_answered)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A1B9A),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        _qIndex + 1 == qs.length ? 'See Result →' : 'Next Question →',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Result Screen ────────────────────────────────────────────
  Widget _buildResult() {
    final total = _questions!.length;
    final pct = (_score / total * 100).round();
    final grade = pct >= 80 ? '🏆 Excellent!' : pct >= 60 ? '👍 Good Job!' : pct >= 40 ? '📚 Keep Practising' : '💪 Try Again Tomorrow';
    final color = pct >= 80 ? const Color(0xFF2E7D32) : pct >= 60 ? const Color(0xFF1565C0) : const Color(0xFF6A1B9A);

    return Column(
      children: [
        _header('Quiz Complete!', 'Today\'s result'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Text(grade, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),
                      Text('$_score / $total', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: color)),
                      Text('$pct% correct', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text('$_streak day streak!',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Correct answers review
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Correct Answers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 10),
                ..._questions!.map((q) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.q, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(q.opts[q.ans],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20))),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: Color(0xFF6A1B9A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Tools', style: TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Already Played ───────────────────────────────────────────
  Widget _buildAlreadyPlayed() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final hoursLeft = tomorrow.difference(DateTime.now()).inHours;

    return Column(
      children: [
        _header('Daily GK Quiz', 'Come back tomorrow!'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('✅', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text('Already Played Today!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Next quiz in ~$hoursLeft hours',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statColumn('Today\'s Score', '$_todayScore / 5', const Color(0xFF6A1B9A)),
                      _statColumn('Current Streak', '🔥 $_streak days', const Color(0xFFE65100)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Tools'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: Color(0xFF6A1B9A)),
                    foregroundColor: const Color(0xFF6A1B9A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
