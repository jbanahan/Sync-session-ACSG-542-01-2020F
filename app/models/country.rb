class Country < ActiveRecord::Base
  
  ALL_COUNTRIES ||= [["AFGHANISTAN","AF"],["ALAND ISLANDS","AX"],["ALBANIA","AL"],["ALGERIA","DZ"],
    ["AMERICAN SAMOA","AS"],["ANDORRA","AD"],["ANGOLA","AO"],["ANGUILLA","AI"],["ANTARCTICA","AQ"],
    ["ANTIGUA AND BARBUDA","AG"],["ARGENTINA","AR"],["ARMENIA","AM"],["ARUBA","AW"],["AUSTRALIA","AU"],
    ["AUSTRIA","AT"],["AZERBAIJAN","AZ"],["BAHAMAS","BS"],["BAHRAIN","BH"],["BANGLADESH","BD"],
    ["BARBADOS","BB"],["BELARUS","BY"],["BELGIUM","BE"],["BELIZE","BZ"],["BENIN","BJ"],["BERMUDA","BM"],
    ["BHUTAN","BT"],["BOLIVIA, PLURINATIONAL STATE OF","BO"],["BONAIRE, SAINT EUSTATIUS AND SABA","BQ"],
    ["BOSNIA AND HERZEGOVINA","BA"],["BOTSWANA","BW"],["BOUVET ISLAND","BV"],["BRAZIL","BR"],
    ["BRITISH INDIAN OCEAN TERRITORY","IO"],["BRUNEI DARUSSALAM","BN"],["BULGARIA","BG"],
    ["BURKINA FASO","BF"],["BURUNDI","BI"],["CAMBODIA","KH"],["CAMEROON","CM"],["CANADA","CA"],
    ["CAPE VERDE","CV"],["CAYMAN ISLANDS","KY"],["CENTRAL AFRICAN REPUBLIC","CF"],["CHAD","TD"],
    ["CHILE","CL"],["CHINA","CN"],["CHRISTMAS ISLAND","CX"],["COCOS (KEELING) ISLANDS","CC"],
    ["COLOMBIA","CO"],["COMOROS","KM"],["CONGO","CG"],["CONGO, THE DEMOCRATIC REPUBLIC OF THE","CD"],
    ["COOK ISLANDS","CK"],["COSTA RICA","CR"],["COTE D'IVOIRE","CI"],["CROATIA","HR"],["CUBA","CU"],
    ["CURACAO","CW"],["CYPRUS","CY"],["CZECH REPUBLIC","CZ"],["DENMARK","DK"],["DJIBOUTI","DJ"],
    ["DOMINICA","DM"],["DOMINICAN REPUBLIC","DO"],["ECUADOR","EC"],["EGYPT","EG"],["EL SALVADOR","SV"],
    ["EQUATORIAL GUINEA","GQ"],["ERITREA","ER"],["ESTONIA","EE"],["ETHIOPIA","ET"],
    ["FALKLAND ISLANDS (MALVINAS)","FK"],["FAROE ISLANDS","FO"],["FIJI","FJ"],["FINLAND","FI"],
    ["FRANCE","FR"],["FRENCH GUIANA","GF"],["FRENCH POLYNESIA","PF"],["FRENCH SOUTHERN TERRITORIES","TF"],
    ["GABON","GA"],["GAMBIA","GM"],["GEORGIA","GE"],["GERMANY","DE"],["GHANA","GH"],["GIBRALTAR","GI"],
    ["GREECE","GR"],["GREENLAND","GL"],["GRENADA","GD"],["GUADELOUPE","GP"],["GUAM","GU"],
    ["GUATEMALA","GT"],["GUERNSEY","GG"],["GUINEA","GN"],["GUINEA-BISSAU","GW"],["GUYANA","GY"],
    ["HAITI","HT"],["HEARD ISLAND AND MCDONALD ISLANDS","HM"],["HONDURAS","HN"],["HONG KONG","HK"],
    ["HUNGARY","HU"],["ICELAND","IS"],["INDIA","IN"],["INDONESIA","ID"],["IRAN, ISLAMIC REPUBLIC OF","IR"],
    ["IRAQ","IQ"],["IRELAND","IE"],["ISLE OF MAN","IM"],["ISRAEL","IL"],["ITALY","IT"],["JAMAICA","JM"],
    ["JAPAN","JP"],["JERSEY","JE"],["JORDAN","JO"],["KAZAKHSTAN","KZ"],["KENYA","KE"],["KIRIBATI","KI"],
    ["KOREA, DEMOCRATIC PEOPLE'S REPUBLIC OF","KP"],["KOREA, REPUBLIC OF","KR"],["KUWAIT","KW"],
    ["KYRGYZSTAN","KG"],["LAO PEOPLE'S DEMOCRATIC REPUBLIC","LA"],["LATVIA","LV"],["LEBANON","LB"],
    ["LESOTHO","LS"],["LIBERIA","LR"],["LIBYAN ARAB JAMAHIRIYA","LY"],["LIECHTENSTEIN","LI"],
    ["LITHUANIA","LT"],["LUXEMBOURG","LU"],["MACAO","MO"],
    ["MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF","MK"],["MADAGASCAR","MG"],["MALAWI","MW"],
    ["MALAYSIA","MY"],["MALDIVES","MV"],["MALI","ML"],["MALTA","MT"],["MARSHALL ISLANDS","MH"],
    ["MARTINIQUE","MQ"],["MAURITANIA","MR"],["MAURITIUS","MU"],["MAYOTTE","YT"],["MEXICO","MX"],
    ["MICRONESIA, FEDERATED STATES OF","FM"],["MOLDOVA, REPUBLIC OF","MD"],["MONACO","MC"],
    ["MONGOLIA","MN"],["MONTENEGRO","ME"],["MONTSERRAT","MS"],["MOROCCO","MA"],["MOZAMBIQUE","MZ"],
    ["MYANMAR","MM"],["NAMIBIA","NA"],["NAURU","NR"],["NEPAL","NP"],["NETHERLANDS","NL"],
    ["NEW CALEDONIA","NC"],["NEW ZEALAND","NZ"],["NICARAGUA","NI"],["NIGER","NE"],["NIGERIA","NG"],
    ["NIUE","NU"],["NORFOLK ISLAND","NF"],["NORTHERN MARIANA ISLANDS","MP"],["NORWAY","NO"],
    ["OMAN","OM"],["PAKISTAN","PK"],["PALAU","PW"],["PALESTINIAN TERRITORY, OCCUPIED","PS"],
    ["PANAMA","PA"],["PAPUA NEW GUINEA","PG"],["PARAGUAY","PY"],["PERU","PE"],["PHILIPPINES","PH"],
    ["PITCAIRN","PN"],["POLAND","PL"],["PORTUGAL","PT"],["PUERTO RICO","PR"],["QATAR","QA"],
    ["REUNION","RE"],["ROMANIA","RO"],["RUSSIAN FEDERATION","RU"],["RWANDA","RW"],
    ["SAINT BARTHELEMY","BL"],["SAINT HELENA, ASCENSION AND TRISTAN DA CUNHA","SH"],
    ["SAINT KITTS AND NEVIS","KN"],["SAINT LUCIA","LC"],["SAINT MARTIN (FRENCH PART)","MF"],
    ["SAINT PIERRE AND MIQUELON","PM"],["SAINT VINCENT AND THE GRENADINES","VC"],["SAMOA","WS"],
    ["SAN MARINO","SM"],["SAO TOME AND PRINCIPE","ST"],["SAUDI ARABIA","SA"],["SENEGAL","SN"],
    ["SERBIA","RS"],["SEYCHELLES","SC"],["SIERRA LEONE","SL"],["SINGAPORE","SG"],
    ["SINT MAARTEN (DUTCH PART)","SX"],["SLOVAKIA","SK"],["SLOVENIA","SI"],["SOLOMON ISLANDS","SB"],
    ["SOMALIA","SO"],["SOUTH AFRICA","ZA"],["SOUTH GEORGIA AND THE SOUTH SANDWICH ISLANDS","GS"],
    ["SPAIN","ES"],["SRI LANKA","LK"],["SUDAN","SD"],["SURINAME","SR"],["SVALBARD AND JAN MAYEN","SJ"],
    ["SWAZILAND","SZ"],["SWEDEN","SE"],["SWITZERLAND","CH"],["SYRIAN ARAB REPUBLIC","SY"],
    ["TAIWAN, PROVINCE OF CHINA","TW"],["TAJIKISTAN","TJ"],["TANZANIA, UNITED REPUBLIC OF","TZ"],
    ["THAILAND","TH"],["TIMOR-LESTE","TL"],["TOGO","TG"],["TOKELAU","TK"],["TONGA","TO"],
    ["TRINIDAD AND TOBAGO","TT"],["TUNISIA","TN"],["TURKEY","TR"],["TURKMENISTAN","TM"],
    ["TURKS AND CAICOS ISLANDS","TC"],["TUVALU","TV"],["UGANDA","UG"],["UKRAINE","UA"],
    ["UNITED ARAB EMIRATES","AE"],["UNITED KINGDOM","GB"],["UNITED STATES","US"],
    ["UNITED STATES MINOR OUTLYING ISLANDS","UM"],["URUGUAY","UY"],["UZBEKISTAN","UZ"],
    ["VANUATU","VU"],["VATICAN CITY STATE","VA"],["VENEZUELA, BOLIVARIAN REPUBLIC OF","VE"],
    ["VIET NAM","VN"],["VIRGIN ISLANDS, BRITISH","VG"],["VIRGIN ISLANDS, U.S.","VI"],
    ["WALLIS AND FUTUNA","WF"],["WESTERN SAHARA","EH"],["YEMEN","YE"],["ZAMBIA","ZM"],["ZIMBABWE","ZW"]]

  EU_ISO_CODES = ['AT','BE','BG','CY','CZ','DK','EE','FI','FR','DE','GR','HU','IE','IT','LV',
    'LT','LU','MT','NL','PL','PT','RO','SK','SI','ES','SE','GB']

  @@skip_reload = false

  attr_accessible :import_location, :classification_rank, :quicksearch_show
  after_save :update_model_fields
  after_commit :update_cache
  
  scope :import_locations, where(:import_location=>true)
  scope :show_quicksearch, where(:quicksearch_show=>true)
  scope :sort_name, order("name ASC") 
  
	has_many :addresses
  has_many :tariff_sets
	has_many :official_tariffs
  has_and_belongs_to_many :regions
	
  scope :sort_classification_rank, order("ifnull(countries.classification_rank,9999) ASC, countries.name ASC")

	validates_uniqueness_of :iso_code
  validate :quicksearch_only_for_import_locations

  def self.find_cached_by_id country_id
    c = CACHE.get("Country:id:#{country_id}")
    c = Country.find country_id if c.nil?
    CACHE.set("Country:id:#{country_id}", c) unless c.nil?
    c
  end
	
	def self.load_default_countries force_load = false
    begin
      @@skip_reload = true
      return if Country.count == ALL_COUNTRIES.size && !force_load
      ALL_COUNTRIES.each do |c_array|
        raise "Country array should have been 2 elements, was #{c_array.length}.  #{c_array.length>0 ? "First element: "+c_array[0] : ""}" unless c_array.length == 2
        c = Country.where(:iso_code => c_array[1]).first_or_initialize
        c.name = c_array[0]
        c.european_union = EU_ISO_CODES.include?(c.iso_code)
        c.save!
      end
    ensure
      @@skip_reload = false
      ModelField.reload true
    end
    return nil
	end

  def quicksearch_only_for_import_locations
    if quicksearch_show && !import_location
      errors.add(:quicksearch_show, "can only be set on an import location!")
    end
  end

  private
  def update_model_fields
    ModelField.reload(true) unless @@skip_reload
  end
  def update_cache
    CACHE.set "Country:id:#{self.id}", self
  end
end
