class PortIataLoad2013 < ActiveRecord::Migration
  def up
    Port.load_iata_data iata_data
  end

  def iata_data
    <<~HEREDOC
      AAL|Aalborg Airport|DK|Aalborg
      AAP|Aji Pangeran Tumenggung Pranoto International Airport|ID|Samarinda
      ABQ|Albuquerque International Sunport|US|Albuquerque
      ABV|Nnamdi Azikiwe International Airport|NG|Abuja
      ABZ|Aberdeen Dyce Airport|GB|Aberdeen
      ACA|General Juan N Alvarez International Airport|MX|Acapulco
      ACC|Kotoka International Airport|GH|Accra
      ADA|Adana Airport|TR|Adana
      ADB|Adnan Menderes International Airport|TR|İzmir
      ADD|Addis Ababa Bole International Airport|ET|Addis Ababa
      ADL|Adelaide International Airport|AU|Adelaide
      ADW|Joint Base Andrews|US|Camp Springs
      AER|Sochi International Airport|RU|Sochi
      AFW|Fort Worth Alliance Airport|US|Fort Worth
      AGP|Málaga Airport|ES|Málaga
      AGS|Augusta Regional At Bush Field|US|Augusta
      AKL|Auckland International Airport|NZ|Auckland
      AKT|RAF Akrotiri|GB|Akrotiri
      ALA|Almaty Airport|KZ|Almaty
      ALC|Alicante International Airport|ES|Alicante
      ALG|Houari Boumediene Airport|DZ|Algiers
      ALP|Aleppo International Airport|SY|Aleppo
      AMA|Rick Husband Amarillo International Airport|US|Amarillo
      AMM|Queen Alia International Airport|JO|Amman
      AMS|Amsterdam Airport Schiphol|NL|Amsterdam
      ANC|Ted Stevens Anchorage International Airport|US|Anchorage
      ARN|Stockholm-Arlanda Airport|SE|Stockholm
      ASB|Ashgabat International Airport|TM|Ashgabat
      ATH|Eleftherios Venizelos International Airport|GR|Athens
      ATL|Hartsfield Jackson Atlanta International Airport|US|Atlanta
      ATQ|Sri Guru Ram Dass Jee International Airport|IN|Amritsar
      AUH|Abu Dhabi International Airport|AE|Abu Dhabi
      AUS|Austin Bergstrom International Airport|US|Austin
      AVL|Asheville Regional Airport|US|Asheville
      AYT|Antalya International Airport|TR|Antalya
      BAB|Beale Air Force Base|US|Marysville
      BAD|Barksdale Air Force Base|US|Bossier City
      BAH|Bahrain International Airport|BH|Manama
      BCN|Barcelona International Airport|ES|Barcelona
      BDL|Bradley International Airport|US|Hartford
      BEG|Belgrade Nikola Tesla Airport|RS|Belgrade
      BEL|Val de Cans/Júlio Cezar Ribeiro International Airport|BR|Belém
      BEY|Beirut Rafic Hariri International Airport|LB|Beirut
      BFI|Boeing Field King County International Airport|US|Seattle
      BFS|Belfast International Airport|GB|Belfast
      BGO|Bergen Airport Flesland|NO|Bergen
      BGR|Bangor International Airport|US|Bangor
      BGW|Baghdad International Airport|IQ|Baghdad
      BGY|Milan Bergamo Airport|IT|Bergamo
      BHD|George Best Belfast City Airport|GB|Belfast
      BHM|Birmingham-Shuttlesworth International Airport|US|Birmingham
      BHX|Birmingham International Airport|GB|Birmingham
      BIL|Billings Logan International Airport|US|Billings
      BJV|Milas Bodrum International Airport|TR|Bodrum
      BKK|Suvarnabhumi Airport|TH|Bangkok
      BKO|Modibo Keita International Airport|ML|Bamako
      BLA|General José Antonio Anzoategui International Airport|VE|Barcelona
      BLL|Billund Airport|DK|Billund
      BLQ|Bologna Guglielmo Marconi Airport|IT|Bologna
      BLR|Kempegowda International Airport|IN|Bangalore
      BLV|Scott AFB/Midamerica Airport|US|Belleville
      BMI|Central Illinois Regional Airport at Bloomington-Normal|US|Bloomington/Normal
      BNA|Nashville International Airport|US|Nashville
      BNE|Brisbane International Airport|AU|Brisbane
      BOD|Bordeaux-Mérignac Airport|FR|Bordeaux/Mérignac
      BOG|El Dorado International Airport|CO|Bogota
      BOH|Bournemouth Airport|GB|Bournemouth
      BOI|Boise Air Terminal/Gowen Field|US|Boise
      BOJ|Burgas Airport|BG|Burgas
      BOM|Chhatrapati Shivaji International Airport|IN|Mumbai
      BOO|Bodø Airport|NO|Bodø
      BOS|General Edward Lawrence Logan International Airport|US|Boston
      BRE|Bremen Airport|DE|Bremen
      BRI|Bari Karol Wojtyła Airport|IT|Bari
      BRS|Bristol Airport|GB|Bristol
      BRU|Brussels Airport|BE|Brussels
      BSB|Presidente Juscelino Kubitschek International Airport|BR|Brasília
      BSL|EuroAirport Basel-Mulhouse-Freiburg Airport|FR|Bâle/Mulhouse
      BSR|Basrah International Airport|IQ|Basrah
      BTS|M. R. Štefánik Airport|SK|Bratislava
      BUD|Budapest Liszt Ferenc International Airport|HU|Budapest
      BUF|Buffalo Niagara International Airport|US|Buffalo
      BWI|Baltimore/Washington International Thurgood Marshall Airport|US|Baltimore
      BWN|Brunei International Airport|BN|Bandar Seri Begawan
      BZE|Philip S. W. Goldson International Airport|BZ|Belize City
      BZZ|RAF Brize Norton|GB|Brize Norton
      CAE|Columbia Metropolitan Airport|US|Columbia
      CAG|Cagliari Elmas Airport|IT|Cagliari
      CAI|Cairo International Airport|EG|Cairo
      CAN|Guangzhou Baiyun International Airport|CN|Guangzhou
      CBM|Columbus Air Force Base|US|Columbus
      CBR|Canberra International Airport|AU|Canberra
      CCJ|Calicut International Airport|IN|Calicut
      CCS|Simón Bolívar International Airport|VE|Caracas
      CCU|Netaji Subhash Chandra Bose International Airport|IN|Kolkata
      CDG|Charles de Gaulle International Airport|FR|Paris
      CEB|Mactan Cebu International Airport|PH|Lapu-Lapu City
      CGH|Congonhas Airport|BR|São Paulo
      CGK|Soekarno-Hatta International Airport|ID|Jakarta
      CGN|Cologne Bonn Airport|DE|Cologne
      CGO|Zhengzhou Xinzheng International Airport|CN|Zhengzhou
      CGY|Laguindingan Airport|PH|Cagayan de Oro City
      CHA|Lovell Field|US|Chattanooga
      CHC|Christchurch International Airport|NZ|Christchurch
      CHS|Charleston Air Force Base-International Airport|US|Charleston
      CIA|Ciampino–G. B. Pastine International Airport|IT|Rome
      CID|The Eastern Iowa Airport|US|Cedar Rapids
      CJJ|Cheongju International Airport/Cheongju Air Base (K-59/G-513)|KR|Cheongju
      CJU|Jeju International Airport|KR|Jeju City
      CKG|Chongqing Jiangbei International Airport|CN|Chongqing
      CLE|Cleveland Hopkins International Airport|US|Cleveland
      CLT|Charlotte Douglas International Airport|US|Charlotte
      CMB|Bandaranaike International Colombo Airport|LK|Colombo
      CMH|John Glenn Columbus International Airport|US|Columbus
      CMN|Mohammed V International Airport|MA|Casablanca
      CNF|Tancredo Neves International Airport|BR|Belo Horizonte
      CNX|Chiang Mai International Airport|TH|Chiang Mai
      COK|Cochin International Airport|IN|Kochi
      COS|City of Colorado Springs Municipal Airport|US|Colorado Springs
      CPH|Copenhagen Kastrup Airport|DK|Copenhagen
      CPT|Cape Town International Airport|ZA|Cape Town
      CRK|Diosdado Macapagal International Airport|PH|Angeles/Mabalacat
      CRL|Brussels South Charleroi Airport|BE|Brussels
      CRP|Corpus Christi International Airport|US|Corpus Christi
      CRW|Yeager Airport|US|Charleston
      CSX|Changsha Huanghua International Airport|CN|Changsha
      CTA|Catania-Fontanarossa Airport|IT|Catania
      CTS|New Chitose Airport|JP|Chitose / Tomakomai
      CTU|Chengdu Shuangliu International Airport|CN|Chengdu
      CUN|Cancún International Airport|MX|Cancún
      CUZ|Alejandro Velasco Astete International Airport|PE|Cusco
      CVG|Cincinnati Northern Kentucky International Airport|US|Cincinnati / Covington
      CVS|Cannon Air Force Base|US|Clovis
      CWB|Afonso Pena Airport|BR|Curitiba
      CWL|Cardiff International Airport|GB|Cardiff
      DAB|Daytona Beach International Airport|US|Daytona Beach
      DAC|Hazrat Shahjalal International Airport|BD|Dhaka
      DAD|Da Nang International Airport|VN|Da Nang
      DAL|Dallas Love Field|US|Dallas
      DAM|Damascus International Airport|SY|Damascus
      DAR|Julius Nyerere International Airport|TZ|Dar es Salaam
      DAY|James M Cox Dayton International Airport|US|Dayton
      DBQ|Dubuque Regional Airport|US|Dubuque
      DCA|Ronald Reagan Washington National Airport|US|Washington
      DEL|Indira Gandhi International Airport|IN|New Delhi
      DEN|Denver International Airport|US|Denver
      DFW|Dallas Fort Worth International Airport|US|Dallas-Fort Worth
      DHA|King Abdulaziz Air Base|SA|
      DJJ|Sentani International Airport|ID|Jayapura-Papua Island
      DKR|Léopold Sédar Senghor International Airport|SN|Dakar
      DLC|Zhoushuizi Airport|CN|Dalian
      DLF|DLF Airport|US|Del Rio
      DLH|Duluth International Airport|US|Duluth
      DLM|Dalaman International Airport|TR|Dalaman
      DME|Domodedovo International Airport|RU|Moscow
      DMK|Don Mueang International Airport|TH|Bangkok
      DMM|King Fahd International Airport|SA|Ad Dammam
      DNA|Kadena Air Base|JP|
      DOH|Hamad International Airport|QA|Doha
      DOV|Dover Air Force Base|US|Dover
      DPS|Ngurah Rai (Bali) International Airport|ID|Denpasar-Bali Island
      DQM|Duqm International Airport|OM|Duqm
      DRS|Dresden Airport|DE|Dresden
      DSA|Robin Hood Doncaster Sheffield Airport|GB|Doncaster
      DSM|Des Moines International Airport|US|Des Moines
      DSS|Blaise Diagne International Airport|SN|Dakar
      DTM|Dortmund Airport|DE|Dortmund
      DTW|Detroit Metropolitan Wayne County Airport|US|Detroit
      DUB|Dublin Airport|IE|Dublin
      DUR|King Shaka International Airport|ZA|Durban
      DUS|Düsseldorf Airport|DE|Düsseldorf
      DVO|Francisco Bangoy International Airport|PH|Davao City
      DWC|Al Maktoum International Airport|AE|Jebel Ali
      DXB|Dubai International Airport|AE|Dubai
      DYS|Dyess Air Force Base|US|Abilene
      EBB|Entebbe International Airport|UG|Kampala
      EDI|Edinburgh Airport|GB|Edinburgh
      EDW|Edwards Air Force Base|US|Edwards
      EIN|Eindhoven Airport|NL|Eindhoven
      EMA|East Midlands Airport|GB|Nottingham
      END|Vance Air Force Base|US|Enid
      ERI|Erie International Tom Ridge Field|US|Erie
      ERZ|Erzurum International Airport|TR|Erzurum
      ESB|Esenboğa International Airport|TR|Ankara
      ETM|Ramon Airport|IL|Eilat
      EVN|Zvartnots International Airport|AM|Yerevan
      EWR|Newark Liberty International Airport|US|Newark
      EXT|Exeter International Airport|GB|Exeter
      EZE|Ministro Pistarini International Airport|AR|Buenos Aires
      FAI|Fairbanks International Airport|US|Fairbanks
      FAO|Faro Airport|PT|Faro
      FCO|Leonardo da Vinci–Fiumicino Airport|IT|Rome
      FFD|RAF Fairford|GB|Fairford
      FFO|Wright-Patterson Air Force Base|US|Dayton
      FIH|Ndjili International Airport|CD|Kinshasa
      FKB|Karlsruhe Baden-Baden Airport|DE|Baden-Baden
      FLL|Fort Lauderdale Hollywood International Airport|US|Fort Lauderdale
      FLN|Hercílio Luz International Airport|BR|Florianópolis
      FMO|Münster Osnabrück Airport|DE|Münster
      FNA|Lungi International Airport|SL|Freetown
      FOC|Fuzhou Changle International Airport|CN|Fuzhou
      FRA|Frankfurt am Main Airport|DE|Frankfurt am Main
      FRU|Manas International Airport|KG|Bishkek
      FSM|Fort Smith Regional Airport|US|Fort Smith
      FSZ|Mt. Fuji Shizuoka Airport|JP|Makinohara / Shimada
      FTW|Fort Worth Meacham International Airport|US|Fort Worth
      FUK|Fukuoka Airport|JP|Fukuoka
      FWA|Fort Wayne International Airport|US|Fort Wayne
      GBE|Sir Seretse Khama International Airport|BW|Gaborone
      GCM|Owen Roberts International Airport|KY|Georgetown
      GDL|Don Miguel Hidalgo Y Costilla International Airport|MX|Guadalajara
      GDN|Gdańsk Lech Wałęsa Airport|PL|Gdańsk
      GEG|Spokane International Airport|US|Spokane
      GIG|Rio Galeão – Tom Jobim International Airport|BR|Rio De Janeiro
      GLA|Glasgow International Airport|GB|Glasgow
      GMP|Gimpo International Airport|KR|Seoul
      GOA|Genoa Cristoforo Colombo Airport|IT|Genova
      GOI|Dabolim Airport|IN|Vasco da Gama
      GOT|Gothenburg-Landvetter Airport|SE|Gothenburg
      GPT|Gulfport Biloxi International Airport|US|Gulfport
      GRB|Austin Straubel International Airport|US|Green Bay
      GRJ|George Airport|ZA|George
      GRU|Guarulhos - Governador André Franco Montoro International Airport|BR|São Paulo
      GRV|Grozny North Airport|RU|Grozny
      GSB|Seymour Johnson Air Force Base|US|Goldsboro
      GSO|Piedmont Triad International Airport|US|Greensboro
      GSP|Greenville Spartanburg International Airport|US|Greenville
      GUA|La Aurora Airport|GT|Guatemala City
      GUM|Antonio B. Won Pat International Airport|GU|Hagåtña, Guam International Airport
      GUS|Grissom Air Reserve Base|US|Peru
      GVA|Geneva Cointrin International Airport|CH|Geneva
      GYD|Heydar Aliyev International Airport|AZ|Baku
      GZT|Gaziantep International Airport|TR|Gaziantep
      HAJ|Hannover Airport|DE|Hannover
      HAK|Haikou Meilan International Airport|CN|Haikou
      HAM|Hamburg Airport|DE|Hamburg
      HAN|Noi Bai International Airport|VN|Hanoi
      HAV|José Martí International Airport|CU|Havana
      HEL|Helsinki Vantaa Airport|FI|Helsinki
      HER|Heraklion International Nikos Kazantzakis Airport|GR|Heraklion
      HET|Baita International Airport|CN|Hohhot
      HGA|Egal International Airport|SO|Hargeisa
      HGH|Hangzhou Xiaoshan International Airport|CN|Hangzhou
      HIB|Range Regional Airport|US|Hibbing
      HKG|Hong Kong International Airport|HK|Hong Kong
      HKT|Phuket International Airport|TH|Phuket
      HMN|Holloman Air Force Base|US|Alamogordo
      HMO|General Ignacio P. Garcia International Airport|MX|Hermosillo
      HND|Tokyo Haneda International Airport|JP|Ota, Tokyo
      HNL|Daniel K Inouye International Airport|US|Honolulu
      HOU|William P Hobby Airport|US|Houston
      HRB|Taiping Airport|CN|Harbin
      HRE|Robert Gabriel Mugabe International Airport|ZW|Harare
      HRG|Hurghada International Airport|EG|Hurghada
      HRI|Mattala Rajapaksa International Airport|LK|
      HRK|Kharkiv International Airport|UA|Kharkiv
      HSV|Huntsville International Carl T Jones Field|US|Huntsville
      HTS|Tri-State/Milton J. Ferguson Field|US|Huntington
      HYD|Rajiv Gandhi International Airport|IN|Hyderabad
      IAD|Washington Dulles International Airport|US|Washington
      IAH|George Bush Intercontinental Houston Airport|US|Houston
      ICN|Incheon International Airport|KR|Seoul
      ICT|Wichita Eisenhower National Airport|US|Wichita
      IKA|Imam Khomeini International Airport|IR|Tehran
      IND|Indianapolis International Airport|US|Indianapolis
      ISB|Islamabad International Airport|PK|Islamabad
      ISE|Süleyman Demirel International Airport|TR|Isparta
      IST|Istanbul Airport|TR|Istanbul
      ITM|Osaka International Airport|JP|Osaka
      JAN|Jackson-Medgar Wiley Evers International Airport|US|Jackson
      JAX|Jacksonville International Airport|US|Jacksonville
      JED|King Abdulaziz International Airport|SA|Jeddah
      JFK|John F Kennedy International Airport|US|New York
      JLN|Joplin Regional Airport|US|Joplin
      JNB|OR Tambo International Airport|ZA|Johannesburg
      JUB|Juba International Airport|SS|Juba
      KAN|Mallam Aminu International Airport|NG|Kano
      KBP|Boryspil International Airport|UA|Kiev
      KEF|Keflavik International Airport|IS|Reykjavík
      KGF|Sary-Arka Airport|KZ|Karaganda
      KGL|Kigali International Airport|RW|Kigali
      KHH|Kaohsiung International Airport|TW|Kaohsiung City
      KHV|Khabarovsk-Novy Airport|RU|Khabarovsk
      KIN|Norman Manley International Airport|JM|Kingston
      KIX|Kansai International Airport|JP|Osaka
      KJA|Yemelyanovo Airport|RU|Krasnoyarsk
      KMG|Kunming Changshui International Airport|CN|Kunming
      KNH|Kinmen Airport|TW|Shang-I
      KNO|Kualanamu International Airport|ID|
      KOJ|Kagoshima Airport|JP|Kagoshima
      KRK|Kraków John Paul II International Airport|PL|Kraków
      KRT|Khartoum International Airport|SD|Khartoum
      KTM|Tribhuvan International Airport|NP|Kathmandu
      KTW|Katowice International Airport|PL|Katowice
      KUF|Kurumoch International Airport|RU|Samara
      KUL|Kuala Lumpur International Airport|MY|Kuala Lumpur
      KUV|Kunsan Air Base|KR|Kunsan
      KWE|Longdongbao Airport|CN|Guiyang
      KWI|Kuwait International Airport|KW|Kuwait City
      KWL|Guilin Liangjiang International Airport|CN|Guilin City
      KZN|Kazan International Airport|RU|Kazan
      LAD|Quatro de Fevereiro Airport|AO|Luanda
      LAS|McCarran International Airport|US|Las Vegas
      LAX|Los Angeles International Airport|US|Los Angeles
      LBA|Leeds Bradford Airport|GB|Leeds
      LBB|Lubbock Preston Smith International Airport|US|Lubbock
      LCA|Larnaca International Airport|CY|Larnarca
      LCK|Rickenbacker International Airport|US|Columbus
      LED|Pulkovo Airport|RU|St. Petersburg
      LEJ|Leipzig/Halle Airport|DE|Leipzig
      LEX|Blue Grass Airport|US|Lexington
      LFI|Langley Air Force Base|US|Hampton
      LFT|Lafayette Regional Airport|US|Lafayette
      LGA|La Guardia Airport|US|New York
      LGG|Liège Airport|BE|Liège
      LGW|London Gatwick Airport|GB|London
      LHR|London Heathrow Airport|GB|London
      LIM|Jorge Chávez International Airport|PE|Lima
      LIN|Milano Linate Airport|IT|Milan
      LIR|Daniel Oduber Quiros International Airport|CR|Liberia
      LIS|Humberto Delgado Airport (Lisbon Portela Airport)|PT|Lisbon
      LIT|Bill & Hillary Clinton National Airport/Adams Field|US|Little Rock
      LJU|Ljubljana Jože Pučnik Airport|SI|Ljubljana
      LKZ|RAF Lakenheath|GB|Lakenheath
      LLA|Luleå Airport|SE|Luleå
      LOS|Murtala Muhammed International Airport|NG|Lagos
      LPA|Gran Canaria Airport|ES|Gran Canaria Island
      LPL|Liverpool John Lennon Airport|GB|Liverpool
      LTK|Bassel Al-Assad International Airport|SY|Latakia
      LTN|London Luton Airport|GB|London
      LTS|Altus Air Force Base|US|Altus
      LTX|Cotopaxi International Airport|EC|Latacunga
      LUF|Luke Air Force Base|US|Glendale
      LUN|Kenneth Kaunda International Airport|ZM|Lusaka
      LUX|Luxembourg-Findel International Airport|LU|Luxembourg
      LXR|Luxor International Airport|EG|Luxor
      LYS|Lyon Saint-Exupéry Airport|FR|Lyon
      MAA|Chennai International Airport|IN|Chennai
      MAD|Adolfo Suárez Madrid–Barajas Airport|ES|Madrid
      MAN|Manchester Airport|GB|Manchester
      MAO|Eduardo Gomes International Airport|BR|Manaus
      MBA|Mombasa Moi International Airport|KE|Mombasa
      MBS|MBS International Airport|US|Saginaw
      MCF|Mac Dill Air Force Base|US|Tampa
      MCI|Kansas City International Airport|US|Kansas City
      MCO|Orlando International Airport|US|Orlando
      MCT|Muscat International Airport|OM|Muscat
      MDL|Mandalay International Airport|MM|Mandalay
      MDW|Chicago Midway International Airport|US|Chicago
      MED|Prince Mohammad Bin Abdulaziz Airport|SA|Medina
      MEL|Melbourne International Airport|AU|Melbourne
      MEM|Memphis International Airport|US|Memphis
      MEX|Licenciado Benito Juarez International Airport|MX|Mexico City
      MFM|Macau International Airport|MO|Macau
      MGE|Dobbins Air Reserve Base|US|Marietta
      MGM|Montgomery Regional (Dannelly Field) Airport|US|Montgomery
      MHD|Mashhad International Airport|IR|Mashhad
      MHT|Manchester-Boston Regional Airport|US|Manchester
      MHZ|RAF Mildenhall|GB|Mildenhall
      MIA|Miami International Airport|US|Miami
      MKE|General Mitchell International Airport|US|Milwaukee
      MLA|Malta International Airport|MT|Valletta
      MLE|Malé International Airport|MV|Malé
      MLI|Quad City International Airport|US|Moline
      MLU|Monroe Regional Airport|US|Monroe
      MMX|Malmö Sturup Airport|SE|Malmö
      MNH|Mussanah Airport|OM|Al Masna'ah
      MNL|Ninoy Aquino International Airport|PH|Pasay / Parañaque, Metro Manila
      MOB|Mobile Regional Airport|US|Mobile
      MPM|Maputo Airport|MZ|Maputo
      MRS|Marseille Provence Airport|FR|Marseille
      MRU|Sir Seewoosagur Ramgoolam International Airport|MU|Port Louis
      MSN|Dane County Regional Truax Field|US|Madison
      MSP|Minneapolis-St Paul International/Wold-Chamberlain Airport|US|Minneapolis
      MSQ|Minsk National Airport|BY|Minsk
      MSY|Louis Armstrong New Orleans International Airport|US|New Orleans
      MTY|General Mariano Escobedo International Airport|MX|Monterrey
      MUC|Munich Airport|DE|Munich
      MUO|Mountain Home Air Force Base|US|Mountain Home
      MVD|Carrasco International /General C L Berisso Airport|UY|Montevideo
      MWX|Muan International Airport|KR|Piseo-ri (Muan)
      MXP|Malpensa International Airport|IT|Milan
      NAP|Naples International Airport|IT|Nápoli
      NAS|Lynden Pindling International Airport|BS|Nassau
      NAT|Governador Aluízio Alves International Airport|BR|Natal
      NAY|Beijing Nanyuan Airport|CN|Beijing
      NBE|Enfidha - Hammamet International Airport|TN|Enfidha
      NBO|Jomo Kenyatta International Airport|KE|Nairobi
      NCE|Nice-Côte d'Azur Airport|FR|Nice
      NCL|Newcastle Airport|GB|Newcastle
      NDJ|N'Djamena International Airport|TD|N'Djamena
      NGB|Ningbo Lishe International Airport|CN|Ningbo
      NGO|Chubu Centrair International Airport|JP|Tokoname
      NIM|Diori Hamani International Airport|NE|Niamey
      NKC|Nouakchott–Oumtounsy International Airport|MR|Nouakchott
      NKG|Nanjing Lukou Airport|CN|Nanjing
      NNG|Nanning Wuxu Airport|CN|Nanning
      NRT|Narita International Airport|JP|Tokyo / Narita
      NUE|Nuremberg Airport|DE|Nuremberg
      NWI|Norwich International Airport|GB|Norwich
      OAK|Metropolitan Oakland International Airport|US|Oakland
      ODS|Odessa International Airport|UA|Odessa
      OKA|Naha Airport|JP|Naha
      OKC|Will Rogers World Airport|US|Oklahoma City
      OKO|Yokota Air Base|JP|Fussa
      OMA|Eppley Airfield|US|Omaha
      ONT|Ontario International Airport|US|Ontario
      OPO|Francisco de Sá Carneiro Airport|PT|Porto
      ORD|Chicago O'Hare International Airport|US|Chicago
      ORF|Norfolk International Airport|US|Norfolk
      ORK|Cork Airport|IE|Cork
      ORY|Paris-Orly Airport|FR|Paris
      OSL|Oslo Gardermoen Airport|NO|Oslo
      OSN|Osan Air Base|KR|
      OTP|Henri Coandă International Airport|RO|Bucharest
      OUA|Ouagadougou Airport|BF|Ouagadougou
      OVB|Tolmachevo Airport|RU|Novosibirsk
      PAM|Tyndall Air Force Base|US|Panama City
      PBI|Palm Beach International Airport|US|West Palm Beach
      PDL|João Paulo II Airport|PT|Ponta Delgada
      PDX|Portland International Airport|US|Portland
      PEK|Beijing Capital International Airport|CN|Beijing
      PER|Perth International Airport|AU|Perth
      PFO|Paphos International Airport|CY|Paphos
      PHF|Newport News Williamsburg International Airport|US|Newport News
      PHL|Philadelphia International Airport|US|Philadelphia
      PHX|Phoenix Sky Harbor International Airport|US|Phoenix
      PIA|General Wayne A. Downing Peoria International Airport|US|Peoria
      PIT|Pittsburgh International Airport|US|Pittsburgh
      PKX|Beijing Daxing International Airport|CN|Beijing / Langfang
      PMI|Palma De Mallorca Airport|ES|Palma De Mallorca
      PMO|Falcone–Borsellino Airport|IT|Palermo
      PNH|Phnom Penh International Airport|KH|Phnom Penh
      POM|Port Moresby Jacksons International Airport|PG|Port Moresby
      POZ|Poznań-Ławica Airport|PL|Poznań
      PPT|Faa'a International Airport|PF|Papeete
      PRG|Václav Havel Airport Prague|CZ|Prague
      PRN|Priština International Airport|XK|Prishtina
      PSA|Pisa International Airport|IT|Pisa
      PTP|Pointe-à-Pitre Le Raizet|GP|Pointe-à-Pitre
      PTY|Tocumen International Airport|PA|Tocumen
      PUJ|Punta Cana International Airport|DO|Punta Cana
      PUS|Gimhae International Airport|KR|Busan
      PVD|Theodore Francis Green State Airport|US|Providence
      PVG|Shanghai Pudong International Airport|CN|Shanghai
      PVR|Licenciado Gustavo Díaz Ordaz International Airport|MX|Puerto Vallarta
      PWM|Portland International Jetport|US|Portland
      QUO|Akwa Ibom International Airport|NG|Uyo
      RAR|Rarotonga International Airport|CK|Avarua
      RDU|Raleigh Durham International Airport|US|Raleigh/Durham
      REP|Siem Reap International Airport|KH|Siem Reap
      RFD|Chicago Rockford International Airport|US|Chicago/Rockford
      RGN|Yangon International Airport|MM|Yangon
      RIC|Richmond International Airport|US|Richmond
      RIX|Riga International Airport|LV|Riga
      RMS|Ramstein Air Base|DE|Ramstein
      RND|Randolph Air Force Base|US|Universal City
      RNO|Reno Tahoe International Airport|US|Reno
      ROA|Roanoke–Blacksburg Regional Airport|US|Roanoke
      ROB|Roberts International Airport|LR|Monrovia
      ROC|Greater Rochester International Airport|US|Rochester
      ROV|Platov International Airport|RU|Rostov-on-Don
      RST|Rochester International Airport|US|Rochester
      RSW|Southwest Florida International Airport|US|Fort Myers
      RUH|King Khaled International Airport|SA|Riyadh
      SAL|Monseñor Óscar Arnulfo Romero International Airport|SV|San Salvador (San Luis Talpa)
      SAN|San Diego International Airport|US|San Diego
      SAT|San Antonio International Airport|US|San Antonio
      SAV|Savannah Hilton Head International Airport|US|Savannah
      SAW|Istanbul Sabiha Gökçen International Airport|TR|Istanbul
      SBN|South Bend Regional Airport|US|South Bend
      SCL|Comodoro Arturo Merino Benítez International Airport|CL|Santiago
      SCQ|Santiago de Compostela Airport|ES|Santiago de Compostela
      SDF|Louisville Muhammad Ali International Airport|US|Louisville
      SDQ|Las Américas International Airport|DO|Santo Domingo
      SEA|Seattle Tacoma International Airport|US|Seattle
      SEZ|Seychelles International Airport|SC|Mahe Island
      SFB|Orlando Sanford International Airport|US|Orlando
      SFO|San Francisco International Airport|US|San Francisco
      SGF|Springfield Branson National Airport|US|Springfield
      SGN|Tan Son Nhat International Airport|VN|Ho Chi Minh City
      SHA|Shanghai Hongqiao International Airport|CN|Shanghai
      SHE|Taoxian Airport|CN|Shenyang
      SHJ|Sharjah International Airport|AE|Sharjah
      SHO|King Mswati III International Airport|SZ|
      SID|Amílcar Cabral International Airport|CV|Espargos
      SIN|Singapore Changi Airport|SG|Singapore
      SIP|Simferopol International Airport|UA|Simferopol
      SJC|Norman Y. Mineta San Jose International Airport|US|San Jose
      SJD|Los Cabos International Airport|MX|San José del Cabo
      SJJ|Sarajevo International Airport|BA|Sarajevo
      SJU|Luis Munoz Marin International Airport|PR|San Juan
      SKA|Fairchild Air Force Base|US|Spokane
      SKG|Thessaloniki Macedonia International Airport|GR|Thessaloniki
      SKP|Skopje International Airport|MK|Skopje
      SKT|Sialkot Airport|PK|Sialkot
      SLC|Salt Lake City International Airport|US|Salt Lake City
      SMF|Sacramento International Airport|US|Sacramento
      SNA|John Wayne Airport-Orange County Airport|US|Santa Ana
      SNN|Shannon Airport|IE|Shannon
      SOF|Sofia Airport|BG|Sofia
      SOQ|Dominique Edward Osok Airport|ID|Sorong-Papua Island
      SOU|Southampton Airport|GB|Southampton
      SPC|La Palma Airport|ES|Sta Cruz de la Palma, La Palma Island
      SPI|Abraham Lincoln Capital Airport|US|Springfield
      SPS|Sheppard Air Force Base-Wichita Falls Municipal Airport|US|Wichita Falls
      SRQ|Sarasota Bradenton International Airport|US|Sarasota/Bradenton
      SSA|Deputado Luiz Eduardo Magalhães International Airport|BR|Salvador
      SSC|Shaw Air Force Base|US|Sumter
      STL|St Louis Lambert International Airport|US|St Louis
      STN|London Stansted Airport|GB|London
      STR|Stuttgart Airport|DE|Stuttgart
      SUB|Juanda International Airport|ID|Surabaya
      SUS|Spirit of St Louis Airport|US|St Louis
      SUU|Travis Air Force Base|US|Fairfield
      SUX|Sioux Gateway Airport/Brigadier General Bud Day Field|US|Sioux City
      SVG|Stavanger Airport Sola|NO|Stavanger
      SVO|Sheremetyevo International Airport|RU|Moscow
      SVX|Koltsovo Airport|RU|Yekaterinburg
      SXF|Berlin-Schönefeld Airport|DE|Berlin
      SXM|Princess Juliana International Airport|SX|Saint Martin
      SYD|Sydney Kingsford Smith International Airport|AU|Sydney
      SYR|Syracuse Hancock International Airport|US|Syracuse
      SYX|Sanya Phoenix International Airport|CN|Sanya
      SYZ|Shiraz Shahid Dastghaib International Airport|IR|Shiraz
      SZL|Whiteman Air Force Base|US|Knob Noster
      SZX|Shenzhen Bao'an International Airport|CN|Shenzhen
      TAS|Tashkent International Airport|UZ|Tashkent
      TBS|Tbilisi International Airport|GE|Tbilisi
      TBZ|Tabriz International Airport|IR|Tabriz
      TCM|McChord Air Force Base|US|Tacoma
      TER|Lajes Airport|PT|Praia da Vitória
      TFN|Tenerife Norte Airport|ES|Tenerife Island
      TFS|Tenerife South Airport|ES|Tenerife Island
      TGD|Podgorica Airport|ME|Podgorica
      THR|Mehrabad International Airport|IR|Tehran
      TIA|Tirana International Airport Mother Teresa|AL|Tirana
      TIJ|General Abelardo L. Rodríguez International Airport|MX|Tijuana
      TIK|Tinker Air Force Base|US|Oklahoma City
      TIP|Tripoli International Airport|LY|Tripoli
      TLH|Tallahassee Regional Airport|US|Tallahassee
      TLL|Lennart Meri Tallinn Airport|EE|Tallinn
      TLS|Toulouse-Blagnac Airport|FR|Toulouse/Blagnac
      TLV|Ben Gurion International Airport|IL|Tel Aviv
      TNA|Yaoqiang Airport|CN|Jinan
      TNR|Ivato Airport|MG|Antananarivo
      TOL|Toledo Express Airport|US|Toledo
      TOS|Tromsø Airport|NO|Tromsø
      TPA|Tampa International Airport|US|Tampa
      TPE|Taiwan Taoyuan International Airport|TW|Taipei
      TRD|Trondheim Airport Værnes|NO|Trondheim
      TRI|Tri-Cities Regional TN/VA Airport|US|Bristol/Johnson/Kingsport
      TRN|Turin Airport|IT|Torino
      TRV|Trivandrum International Airport|IN|Thiruvananthapuram
      TSE|Astana International Airport|KZ|Astana
      TSF|Treviso-Sant'Angelo Airport|IT|Treviso
      TSN|Tianjin Binhai International Airport|CN|Tianjin
      TUL|Tulsa International Airport|US|Tulsa
      TUN|Tunis Carthage International Airport|TN|Tunis
      TUS|Tucson International Airport / Morris Air National Guard Base|US|Tucson
      TXL|Berlin-Tegel Airport|DE|Berlin
      TYN|Taiyuan Wusu Airport|CN|Taiyuan
      TYS|McGhee Tyson Airport|US|Knoxville
      TZX|Trabzon International Airport|TR|Trabzon
      UBN|Ulaanbaatar International Airport|MN|Ulaanbaatar
      UFA|Ufa International Airport|RU|Ufa
      UIO|Mariscal Sucre International Airport|EC|Quito
      ULN|Buyant-Ukhaa International Airport|MN|Ulan Bator
      UPG|Hasanuddin International Airport|ID|Ujung Pandang-Celebes Island
      URC|Ürümqi Diwopu International Airport|CN|Ürümqi
      VAR|Varna Airport|BG|Varna
      VBG|Vandenberg Air Force Base|US|Lompoc
      VCE|Venice Marco Polo Airport|IT|Venice
      VIE|Vienna International Airport|AT|Vienna
      VKO|Vnukovo International Airport|RU|Moscow
      VNO|Vilnius International Airport|LT|Vilnius
      VPS|Destin-Ft Walton Beach Airport|US|Valparaiso
      VRA|Juan Gualberto Gomez International Airport|CU|Varadero
      VRN|Verona Villafranca Airport|IT|Verona
      VVI|Viru Viru International Airport|BO|Santa Cruz
      WAW|Warsaw Chopin Airport|PL|Warsaw
      WDH|Hosea Kutako International Airport|NA|Windhoek
      WLG|Wellington International Airport|NZ|Wellington
      WMI|Modlin Airport|PL|Warsaw
      WNZ|Wenzhou Longwan International Airport|CN|Wenzhou
      WRB|Robins Air Force Base|US|Warner Robins
      WRO|Copernicus Wrocław Airport|PL|Wrocław
      WUH|Wuhan Tianhe International Airport|CN|Wuhan
      XIY|Xi'an Xianyang International Airport|CN|Xi'an
      XMN|Xiamen Gaoqi International Airport|CN|Xiamen
      YEG|Edmonton International Airport|CA|Edmonton
      YHZ|Halifax / Stanfield International Airport|CA|Halifax
      YNT|Yantai Penglai International Airport|CN|Yantai
      YOW|Ottawa Macdonald-Cartier International Airport|CA|Ottawa
      YUL|Montreal / Pierre Elliott Trudeau International Airport|CA|Montréal
      YVR|Vancouver International Airport|CA|Vancouver
      YWG|Winnipeg / James Armstrong Richardson International Airport|CA|Winnipeg
      YYC|Calgary International Airport|CA|Calgary
      YYJ|Victoria International Airport|CA|Victoria
      YYT|St. John's International Airport|CA|St. John's
      YYZ|Lester B. Pearson International Airport|CA|Toronto
      ZAG|Zagreb Airport|HR|Zagreb
      ZIA|Zhukovsky International Airport|RU|Moscow
      ZNZ|Abeid Amani Karume International Airport|TZ|Zanzibar
      ZRH|Zürich Airport|CH|Zurich
    HEREDOC
  end

  def down
    # Nothing needs to be wiped.  Ports are here to stay.
  end

end