# == Schema Information
#
# Table name: countries
#
#  active_origin       :boolean
#  classification_rank :integer
#  created_at          :datetime         not null
#  european_union      :boolean
#  id                  :integer          not null, primary key
#  import_location     :boolean
#  iso_3_code          :string(255)
#  iso_code            :string(2)
#  name                :string(255)
#  quicksearch_show    :boolean
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_countries_on_iso_3_code  (iso_3_code)
#

class Country < ActiveRecord::Base

  ALL_COUNTRIES ||= [
    ['AFGHANISTAN', 'AF', 'AFG'],
    ['ALAND ISLANDS', 'AX', 'ALA'],
    ['ALBANIA', 'AL', 'ALB'],
    ['ALGERIA', 'DZ', 'DZA'],
    ['AMERICAN SAMOA', 'AS', 'ASM'],
    ['ANDORRA', 'AD', 'AND'],
    ['ANGOLA', 'AO', 'AGO'],
    ['ANGUILLA', 'AI', 'AIA'],
    ['ANTARCTICA', 'AQ', 'ATA'],
    ['ANTIGUA AND BARBUDA', 'AG', 'ATG'],
    ['ARGENTINA', 'AR', 'ARG'],
    ['ARMENIA', 'AM', 'ARM'],
    ['ARUBA', 'AW', 'ABW'],
    ['AUSTRALIA', 'AU', 'AUS'],
    ['AUSTRIA', 'AT', 'AUT'],
    ['AZERBAIJAN', 'AZ', 'AZE'],
    ['BAHAMAS', 'BS', 'BHS'],
    ['BAHRAIN', 'BH', 'BHR'],
    ['BANGLADESH', 'BD', 'BGD'],
    ['BARBADOS', 'BB', 'BRB'],
    ['BELARUS', 'BY', 'BLR'],
    ['BELGIUM', 'BE', 'BEL'],
    ['BELIZE', 'BZ', 'BLZ'],
    ['BENIN', 'BJ', 'BEN'],
    ['BERMUDA', 'BM', 'BMU'],
    ['BHUTAN', 'BT', 'BTN'],
    ['BOLIVIA, PLURINATIONAL STATE OF', 'BO', 'BOL'],
    ['BONAIRE, SAINT EUSTATIUS AND SABA', 'BQ', ''],
    ['BOSNIA AND HERZEGOVINA', 'BA', 'BIH'],
    ['BOTSWANA', 'BW', 'BWA'],
    ['BOUVET ISLAND', 'BV', 'BVT'],
    ['BRAZIL', 'BR', 'BRA'],
    ['BRITISH INDIAN OCEAN TERRITORY', 'IO', 'IOT'],
    ['BRUNEI DARUSSALAM', 'BN', 'BRN'],
    ['BULGARIA', 'BG', 'BGR'],
    ['BURKINA FASO', 'BF', 'BFA'],
    ['BURUNDI', 'BI', 'BDI'],
    ['BURMA', 'BU', 'BUR'],
    ['CAMBODIA', 'KH', 'KHM'],
    ['CAMEROON', 'CM', 'CMR'],
    ['CANADA', 'CA', 'CAN'],
    ['CAPE VERDE', 'CV', 'CPV'],
    ['CAYMAN ISLANDS', 'KY', 'CYM'],
    ['CENTRAL AFRICAN REPUBLIC', 'CF', 'CAF'],
    ['CHAD', 'TD', 'TCD'],
    ['CHILE', 'CL', 'CHL'],
    ['CHINA', 'CN', 'CHN'],
    ['CHRISTMAS ISLAND', 'CX', 'CXR'],
    ['COCOS (KEELING) ISLANDS', 'CC', 'CCK'],
    ['COLOMBIA', 'CO', 'COL'],
    ['COMOROS', 'KM', 'COM'],
    ['CONGO', 'CG', 'COG'],
    ['CONGO, THE DEMOCRATIC REPUBLIC OF THE', 'CD', 'COD'],
    ['COOK ISLANDS', 'CK', 'COK'],
    ['COSTA RICA', 'CR', 'CRI'],
    ['COTE D''IVOIRE', 'CI', 'CIV'],
    ['CROATIA', 'HR', 'HRV'],
    ['CUBA', 'CU', 'CUB'],
    ['CURACAO', 'CW', ''],
    ['CYPRUS', 'CY', 'CYP'],
    ['CZECH REPUBLIC', 'CZ', 'CZE'],
    ['DENMARK', 'DK', 'DNK'],
    ['DJIBOUTI', 'DJ', 'DJI'],
    ['DOMINICA', 'DM', 'DMA'],
    ['DOMINICAN REPUBLIC', 'DO', 'DOM'],
    ['ECUADOR', 'EC', 'ECU'],
    ['EGYPT', 'EG', 'EGY'],
    ['EL SALVADOR', 'SV', 'SLV'],
    ['EQUATORIAL GUINEA', 'GQ', 'GNQ'],
    ['ERITREA', 'ER', 'ERI'],
    ['ESTONIA', 'EE', 'EST'],
    ['ETHIOPIA', 'ET', 'ETH'],
    ['FALKLAND ISLANDS (MALVINAS)', 'FK', 'FLK'],
    ['FAROE ISLANDS', 'FO', 'FRO'],
    ['FIJI', 'FJ', 'FJI'],
    ['FINLAND', 'FI', 'FIN'],
    ['FRANCE', 'FR', 'FRA'],
    ['FRENCH GUIANA', 'GF', 'GUF'],
    ['FRENCH POLYNESIA', 'PF', 'PYF'],
    ['FRENCH SOUTHERN TERRITORIES', 'TF', 'ATF'],
    ['GABON', 'GA', 'GAB'],
    ['GAMBIA', 'GM', 'GMB'],
    ['GEORGIA', 'GE', 'GEO'],
    ['GERMANY', 'DE', 'DEU'],
    ['GHANA', 'GH', 'GHA'],
    ['GIBRALTAR', 'GI', 'GIB'],
    ['GREECE', 'GR', 'GRC'],
    ['GREENLAND', 'GL', 'GRL'],
    ['GRENADA', 'GD', 'GRD'],
    ['GUADELOUPE', 'GP', 'GLP'],
    ['GUAM', 'GU', 'GUM'],
    ['GUATEMALA', 'GT', 'GTM'],
    ['GUERNSEY', 'GG', 'GGY'],
    ['GUINEA', 'GN', 'GIN'],
    ['GUINEA-BISSAU', 'GW', 'GNB'],
    ['GUYANA', 'GY', 'GUY'],
    ['HAITI', 'HT', 'HTI'],
    ['HEARD ISLAND AND MCDONALD ISLANDS', 'HM', 'HMD'],
    ['HONDURAS', 'HN', 'HND'],
    ['HONG KONG', 'HK', 'HKG'],
    ['HUNGARY', 'HU', 'HUN'],
    ['ICELAND', 'IS', 'ISL'],
    ['INDIA', 'IN', 'IND'],
    ['INDONESIA', 'ID', 'IDN'],
    ['IRAN, ISLAMIC REPUBLIC OF', 'IR', 'IRN'],
    ['IRAQ', 'IQ', 'IRQ'],
    ['IRELAND', 'IE', 'IRL'],
    ['ISLE OF MAN', 'IM', 'IMN'],
    ['ISRAEL', 'IL', 'ISR'],
    ['ITALY', 'IT', 'ITA'],
    ['JAMAICA', 'JM', 'JAM'],
    ['JAPAN', 'JP', 'JPN'],
    ['JERSEY', 'JE', 'JEY'],
    ['JORDAN', 'JO', 'JOR'],
    ['KAZAKHSTAN', 'KZ', 'KAZ'],
    ['KENYA', 'KE', 'KEN'],
    ['KIRIBATI', 'KI', 'KIR'],
    ['KOREA, DEMOCRATIC PEOPLE''S REPUBLIC OF', 'KP', 'PRK'],
    ['KOREA, REPUBLIC OF', 'KR', 'KOR'],
    ['KUWAIT', 'KW', 'KWT'],
    ['KYRGYZSTAN', 'KG', 'KGZ'],
    ['LAO PEOPLE''S DEMOCRATIC REPUBLIC', 'LA', 'LAO'],
    ['LATVIA', 'LV', 'LVA'],
    ['LEBANON', 'LB', 'LBN'],
    ['LESOTHO', 'LS', 'LSO'],
    ['LIBERIA', 'LR', 'LBR'],
    ['LIBYAN ARAB JAMAHIRIYA', 'LY', 'LBY'],
    ['LIECHTENSTEIN', 'LI', 'LIE'],
    ['LITHUANIA', 'LT', 'LTU'],
    ['LUXEMBOURG', 'LU', 'LUX'],
    ['MACAO', 'MO', 'MAC'],
    ['MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF', 'MK', 'MKD'],
    ['MADAGASCAR', 'MG', 'MDG'],
    ['MALAWI', 'MW', 'MWI'],
    ['MALAYSIA', 'MY', 'MYS'],
    ['MALDIVES', 'MV', 'MDV'],
    ['MALI', 'ML', 'MLI'],
    ['MALTA', 'MT', 'MLT'],
    ['MARSHALL ISLANDS', 'MH', 'MHL'],
    ['MARTINIQUE', 'MQ', 'MTQ'],
    ['MAURITANIA', 'MR', 'MRT'],
    ['MAURITIUS', 'MU', 'MUS'],
    ['MAYOTTE', 'YT', 'MYT'],
    ['MEXICO', 'MX', 'MEX'],
    ['MICRONESIA, FEDERATED STATES OF', 'FM', 'FSM'],
    ['MOLDOVA, REPUBLIC OF', 'MD', 'MDA'],
    ['MONACO', 'MC', 'MCO'],
    ['MONGOLIA', 'MN', 'MNG'],
    ['MONTENEGRO', 'ME', 'MNE'],
    ['MONTSERRAT', 'MS', 'MSR'],
    ['MOROCCO', 'MA', 'MAR'],
    ['MOZAMBIQUE', 'MZ', 'MOZ'],
    ['MYANMAR', 'MM', 'MMR'],
    ['NAMIBIA', 'NA', 'NAM'],
    ['NAURU', 'NR', 'NRU'],
    ['NEPAL', 'NP', 'NPL'],
    ['NETHERLANDS', 'NL', 'NLD'],
    ['NEW CALEDONIA', 'NC', 'NCL'],
    ['NEW ZEALAND', 'NZ', 'NZL'],
    ['NICARAGUA', 'NI', 'NIC'],
    ['NIGER', 'NE', 'NER'],
    ['NIGERIA', 'NG', 'NGA'],
    ['NIUE', 'NU', 'NIU'],
    ['NORFOLK ISLAND', 'NF', 'NFK'],
    ['NORTHERN MARIANA ISLANDS', 'MP', 'MNP'],
    ['NORWAY', 'NO', 'NOR'],
    ['OMAN', 'OM', 'OMN'],
    ['PAKISTAN', 'PK', 'PAK'],
    ['PALAU', 'PW', 'PLW'],
    ['PALESTINIAN TERRITORY, OCCUPIED', 'PS', 'PSE'],
    ['PANAMA', 'PA', 'PAN'],
    ['PAPUA NEW GUINEA', 'PG', 'PNG'],
    ['PARAGUAY', 'PY', 'PRY'],
    ['PERU', 'PE', 'PER'],
    ['PHILIPPINES', 'PH', 'PHL'],
    ['PITCAIRN', 'PN', 'PCN'],
    ['POLAND', 'PL', 'POL'],
    ['PORTUGAL', 'PT', 'PRT'],
    ['PUERTO RICO', 'PR', 'PRI'],
    ['QATAR', 'QA', 'QAT'],
    ['REUNION', 'RE', 'REU'],
    ['ROMANIA', 'RO', 'ROU'],
    ['RUSSIAN FEDERATION', 'RU', 'RUS'],
    ['RWANDA', 'RW', 'RWA'],
    ['SAINT BARTHELEMY', 'BL', 'BLM'],
    ['SAINT HELENA, ASCENSION AND TRISTAN DA CUNHA', 'SH', 'SHN'],
    ['SAINT KITTS AND NEVIS', 'KN', 'KNA'],
    ['SAINT LUCIA', 'LC', 'LCA'],
    ['SAINT MARTIN (FRENCH PART)', 'MF', 'MAF'],
    ['SAINT PIERRE AND MIQUELON', 'PM', 'SPM'],
    ['SAINT VINCENT AND THE GRENADINES', 'VC', 'VCT'],
    ['SAMOA', 'WS', 'WSM'],
    ['SAN MARINO', 'SM', 'SMR'],
    ['SAO TOME AND PRINCIPE', 'ST', 'STP'],
    ['SAUDI ARABIA', 'SA', 'SAU'],
    ['SENEGAL', 'SN', 'SEN'],
    ['SERBIA', 'RS', 'SRB'],
    ['SEYCHELLES', 'SC', 'SYC'],
    ['SIERRA LEONE', 'SL', 'SLE'],
    ['SINGAPORE', 'SG', 'SGP'],
    ['SINT MAARTEN (DUTCH PART)', 'SX', ''],
    ['SLOVAKIA', 'SK', 'SVK'],
    ['SLOVENIA', 'SI', 'SVN'],
    ['SOLOMON ISLANDS', 'SB', 'SLB'],
    ['SOMALIA', 'SO', 'SOM'],
    ['SOUTH AFRICA', 'ZA', 'ZAF'],
    ['SOUTH GEORGIA AND THE SOUTH SANDWICH ISLANDS', 'GS', 'SGS'],
    ['SPAIN', 'ES', 'ESP'],
    ['SRI LANKA', 'LK', 'LKA'],
    ['SUDAN', 'SD', 'SDN'],
    ['SURINAME', 'SR', 'SUR'],
    ['SVALBARD AND JAN MAYEN', 'SJ', 'SJM'],
    ['SWAZILAND', 'SZ', 'SWZ'],
    ['SWEDEN', 'SE', 'SWE'],
    ['SWITZERLAND', 'CH', 'CHE'],
    ['SYRIAN ARAB REPUBLIC', 'SY', 'SYR'],
    ['TAIWAN, PROVINCE OF CHINA', 'TW', 'TWN'],
    ['TAJIKISTAN', 'TJ', 'TJK'],
    ['TANZANIA, UNITED REPUBLIC OF', 'TZ', 'TZA'],
    ['THAILAND', 'TH', 'THA'],
    ['TIMOR-LESTE', 'TL', 'TLS'],
    ['TOGO', 'TG', 'TGO'],
    ['TOKELAU', 'TK', 'TKL'],
    ['TONGA', 'TO', 'TON'],
    ['TRINIDAD AND TOBAGO', 'TT', 'TTO'],
    ['TUNISIA', 'TN', 'TUN'],
    ['TURKEY', 'TR', 'TUR'],
    ['TURKMENISTAN', 'TM', 'TKM'],
    ['TURKS AND CAICOS ISLANDS', 'TC', 'TCA'],
    ['TUVALU', 'TV', 'TUV'],
    ['UGANDA', 'UG', 'UGA'],
    ['UKRAINE', 'UA', 'UKR'],
    ['UNITED ARAB EMIRATES', 'AE', 'ARE'],
    ['UNITED KINGDOM', 'GB', 'GBR'],
    ['UNITED STATES', 'US', 'USA'],
    ['UNITED STATES MINOR OUTLYING ISLANDS', 'UM', 'UMI'],
    ['URUGUAY', 'UY', 'URY'],
    ['UZBEKISTAN', 'UZ', 'UZB'],
    ['VANUATU', 'VU', 'VUT'],
    ['VATICAN CITY STATE', 'VA', 'VAT'],
    ['VENEZUELA, BOLIVARIAN REPUBLIC OF', 'VE', 'VEN'],
    ['VIET NAM', 'VN', 'VNM'],
    ['VIRGIN ISLANDS, BRITISH', 'VG', 'VGB'],
    ['VIRGIN ISLANDS, U.S.', 'VI', 'VIR'],
    ['WALLIS AND FUTUNA', 'WF', 'WLF'],
    ['WESTERN SAHARA', 'EH', 'ESH'],
    ['YEMEN', 'YE', 'YEM'],
    ['ZAMBIA', 'ZM', 'ZMB'],
    ['ZIMBABWE', 'ZW', 'ZWE'],
  ]

  EU_ISO_CODES = ['AT','BE','BG','CY','CZ','DK','EE','FI','FR','DE','GR','HU','IE','IT','LV',
    'LT','LU','MT','NL','PL','PT','RO','SK','SI','ES','SE','GB']

  @@skip_reload = false

  attr_accessible :import_location, :classification_rank, :quicksearch_show, :active_origin
  after_save :update_model_fields
  after_commit :update_cache

  scope :import_locations, where(:import_location=>true)
  scope :show_quicksearch, where(:quicksearch_show=>true)
  scope :sort_name, order("name ASC")

	has_many :addresses
  has_many :tariff_sets
	has_many :official_tariffs
  has_many  :trade_lanes_as_origin, :class_name => 'TradeLane', :foreign_key=>'origin_country_id'
  has_many  :trade_lanes_as_destination, :class_name => 'TradeLane', :foreign_key=>'destination_country_id'
  has_many  :product_rate_overrides_as_origin, :class_name => 'ProductRateOverride', :foreign_key=>'origin_country_id'
  has_many  :product_rate_overrides_as_destination, :class_name => 'ProductRateOverride', :foreign_key=>'destination_country_id'
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
        raise "Country array should have been at least 2 elements, was #{c_array.length}.  #{c_array.length>0 ? "First element: "+c_array[0] : ""}" unless c_array.length >= 2
        c = Country.where(:iso_code => c_array[1]).first_or_initialize
        c.name = c_array[0]
        c.iso_3_code = c_array[2]
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
