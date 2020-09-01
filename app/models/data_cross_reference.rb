# == Schema Information
#
# Table name: data_cross_references
#
#  company_id           :integer
#  created_at           :datetime         not null
#  cross_reference_type :string(255)
#  id                   :integer          not null, primary key
#  key                  :string(255)
#  updated_at           :datetime         not null
#  value                :string(255)
#
# Indexes
#
#  index_data_cross_references_on_cross_reference_type_and_value  (cross_reference_type,value)
#  index_data_xref_on_key_and_xref_type_and_company_id            (key,cross_reference_type,company_id) UNIQUE
#

require 'open_chain/data_cross_reference_upload_preprocessor'
require 'open_chain/milestone_notification_config_support'
require 'csv'

class DataCrossReference < ActiveRecord::Base
  attr_accessible :company_id, :company, :cross_reference_type, :key, :value,
                  :created_at

  belongs_to :company
  validates :key, :cross_reference_type, presence: true

  JJILL_ORDER_FINGERPRINT ||= 'jjill_order'.freeze
  LENOX_ITEM_MASTER_HASH ||= 'lenox_itm'.freeze
  LENOX_HTS_FINGERPRINT ||= 'lenox_hts_fingerprint'.freeze
  RL_BRAND_TO_PROFIT_CENTER ||= 'profit_center'.freeze
  RL_PO_TO_BRAND ||= 'po_to_brand'.freeze
  UA_PLANT_TO_ISO ||= 'uap2i'.freeze
  UA_SITE_TO_COUNTRY ||= 'ua_site'.freeze
  UA_WINSHUTTLE_FINGERPRINT ||= 'uawin-fingerprint'.freeze
  UA_315_MILESTONE_EVENT ||= 'ua-315'.freeze
  UA_MATERIAL_COLOR_PLANT ||= 'ua-mcp'.freeze
  ALLIANCE_CHARGE_TO_GL_ACCOUNT ||= 'al_gl_code'.freeze
  ALLIANCE_BANK_ACCOUNT_TO_INTACCT ||= 'al_bank_no'.freeze
  INTACCT_CUSTOMER_XREF ||= 'in_cust'.freeze
  INTACCT_VENDOR_XREF ||= 'in_vend'.freeze
  INTACCT_BANK_CASH_GL_ACCOUNT ||= 'in_cash_gl'.freeze
  ALLIANCE_FREIGHT_CHARGE_CODE ||= 'al_freight_code'.freeze
  FENIX_ALS_CUSTOMER_NUMBER ||= 'fx_als_cust'.freeze
  RL_FABRIC_XREF ||= 'rl_fabric'.freeze
  RL_VALIDATED_FABRIC ||= 'rl_valid_fabric'.freeze
  UA_DUTY_RATE ||= 'ua_duty_rate'.freeze
  ALLIANCE_CHECK_REPORT_CHECKSUM ||= 'al_check_checksum'.freeze
  ALLIANCE_INVOICE_REPORT_CHECKSUM ||= 'al_inv_checksum'.freeze
  OUTBOUND_315_EVENT ||= '315'.freeze
  PO_FINGERPRINT ||= 'po_id'.freeze
  EXPORT_CARRIER ||= 'export_carriers'.freeze
  US_HTS_TO_CA ||= 'us_hts_to_ca'.freeze
  HM_PARS_NUMBER ||= 'hm_pars'.freeze
  UN_LOCODE_TO_US_CODE ||= "locode_to_us".freeze
  ASCE_MID ||= 'asce_mid'.freeze
  CA_HTS_TO_DESCR ||= 'ca_hts_to_descr'.freeze
  PVH_INVOICES ||= 'pvh_invoices'.freeze
  # This is a generic MID cross reference, the key value can be anything, the value should be the MID and the importer id field should
  # be filled in
  MID_XREF ||= 'mid_xref'.freeze
  ENTRY_MID_VALIDATIONS ||= 'entry_mids'.freeze
  SHIPMENT_CI_LOAD_CUSTOMERS ||= 'shp_ci_load_cust'.freeze
  SHIPMENT_ENTRY_LOAD_CUSTOMERS ||= "shp_entry_load_cust".freeze
  INVOICE_CI_LOAD_CUSTOMERS ||= 'inv_ci_load_cust'.freeze
  ISF_CI_LOAD_CUSTOMERS ||= "isf_ci_load_cust".freeze
  LL_GTN_QUANTITY_UOM ||= "ll_gtn_quantity_uom".freeze
  LL_GTN_EQUIPMENT_TYPE ||= "ll_gtn_equipment_type".freeze
  CI_LOAD_DEFAULT_GOODS_DESCRIPTION ||= "shp_ci_load_goods".freeze
  VFI_DIVISION ||= "vfi_division".freeze
  OTA_REFERENCE_FIELDS ||= "ota_reference_fields".freeze
  ASCE_BRAND ||= "asce_brand_xref".freeze
  HM_I2_SHIPMENT_EXPORT_INVOICE_NUMBER = "hm_i2_shipment_export_invoice_number".freeze
  HM_I2_SHIPMENT_RETURNS_INVOICE_NUMBER = "hm_i2_shipment_returns_invoice_number".freeze
  HM_I2_DRAWBACK_EXPORT_INVOICE_NUMBER = "hm_i2_drawback_export_invoice_number".freeze
  HM_I2_DRAWBACK_RETURNS_INVOICE_NUMBER = "hm_i2_drawback_returns_invoice_number".freeze
  LL_CARB_STATEMENTS ||= "ll_carb_statement".freeze
  LL_PATENT_STATEMENTS ||= "ll_patent_statement".freeze
  CARGOWISE_TRANSPORT_MODE_US ||= "cargowise_transport_mode_us".freeze
  CARGOWISE_TRANSPORT_MODE_CA ||= "cargowise_transport_mode_ca".freeze
  # This list determines which documents should only retain a single version of the document
  CARGOWISE_SINGLE_DOCUMENT_CODE ||= "cargowise_single_document_code".freeze
  VFI_CALENDAR ||= "vfi_calendar".freeze
  UNIT_OF_MEASURE ||= "unit_of_measure".freeze
  ACE_RADIATION_DECLARATION ||= 'ace_rad_dec'.freeze
  # Combination of entry export and origin country codes that have SPI available.
  TRADELENS_ENTRY_MILESTONE_FIELDS ||= 'tradelens_entry_milestone_fields'.freeze
  SPI_AVAILABLE_COUNTRY_COMBINATION ||= 'spi_available_country_combination'.freeze
  SIEMENS_BILLING_STANDARD ||= 'siemens_billing_standard'.freeze
  SIEMENS_BILLING_ENERGY ||= 'siemens_billing_energy'.freeze
  PART_XREF ||= 'part_xref'.freeze

  scope :for_type, ->(xref_type) { where(cross_reference_type: xref_type) }

  PREPROCESSORS = OpenChain::DataCrossReferenceUploadPreprocessor.preprocessors

  def self.xref_edit_hash user
    # rubocop:disable Layout/LineLength
    all_editable_xrefs = [
      xref_attributes(ENTRY_MID_VALIDATIONS, "Manufacturer ID", "Manufacturer IDs used to validate entries", key_label: "MID", show_value_column: false, require_company: true, allow_blank_value: false, upload_instructions: "Spreadsheet should contain a header row, with MID Code in column A"),
      xref_attributes(RL_FABRIC_XREF, "MSL+ Fabric Cross References", "Enter the starting fabric value in the Failure Fiber field and the final value to send to MSL+ in the Approved Fiber field.", key_label: "Failure Fiber", value_label: "Approved Fiber"),
      xref_attributes(RL_VALIDATED_FABRIC, "MSL+ Valid Fabric List", "Only values included in this list are allowed to be sent to to MSL+.", key_label: "Approved Fiber", show_value_column: false),
      xref_attributes(US_HTS_TO_CA, "System Classification Cross References", "Products with a US HTS number and no Canadian tariff are assigned the corresponding Canadian HTS.", key_label: "United States HTS", value_label: "Canada HTS", require_company: true, company: {system_code: "HENNE"}),
      xref_attributes(ASCE_MID, "Ascena MID-Vendor List", "MID-Vendors on this list are used to generate the Daily First Sale Exception report", key_label: "MID-Vendor ID", value_label: "FS Start Date", preprocessor: PREPROCESSORS[ASCE_MID]),
      xref_attributes(CA_HTS_TO_DESCR, "Canada Customs Description Cross References", "Products automatically assigned a CA HTS are given the corresponding customs description.", key_label: "Canada HTS", value_label: "Customs Description", require_company: true, company: {system_code: "HENNE"}),
      xref_attributes(UA_SITE_TO_COUNTRY, "FSM Site Cross References", "Enter the site code and corresponding country code.", key_label: "Site Code", value_label: "Country Code"),
      xref_attributes(CI_LOAD_DEFAULT_GOODS_DESCRIPTION, "Shipment Entry Load Goods Descriptions", "Enter the customer number and corresponding default Goods Description.", key_label: "Customer Number", value_label: "Goods Description"),
      xref_attributes(SHIPMENT_ENTRY_LOAD_CUSTOMERS, "Shipment Entry Load Customers", "Enter the customer number to enable sending Shipment data to Kewill.", key_label: "Customer Number", show_value_column: true, value_label: "Document Type", allowed_values: ["Standard", "Rollup"]),
      xref_attributes(SHIPMENT_CI_LOAD_CUSTOMERS, "Shipment CI Load Customers", "Enter the customer number to enable sending Shipment CI Load data to Kewill.", key_label: "Customer Number", show_value_column: false),
      xref_attributes(HM_PARS_NUMBER, "H&M PARS Numbers", "Enter the PARS numbers to use for the H&M export shipments to Canada. To mark a PARS Number as used, edit it and key a '1' into the 'PARS Used?' field.", key_label: "PARS Number", value_label: "PARS Used?", show_value_column: true, upload_instructions: 'Spreadsheet should contain a Header row labeled "PARS Numbers" in column A.  List all PARS numbers thereafter in column A.', allow_blank_value: true),
      xref_attributes(INVOICE_CI_LOAD_CUSTOMERS, "Invoice CI Load Customers", "Enter the customer number to enable sending Invoice CI Load data to Kewill.", key_label: "Customer Number", show_value_column: false),
      xref_attributes(ASCE_BRAND, "Ascena Brands", "Enter the full brand name in the Brand Name field and enter the brand abbreviation in the Brand Abbrev field.", key_label: "Brand Name", value_label: "Brand Abbrev", upload_instructions: 'Spreadsheet should contain a header row labels "Brand Name" in column A and "Brand Abbrev" in column B. List full brand names in column A and brand abbreviations in column b', allow_blank_value: false),
      xref_attributes(TRADELENS_ENTRY_MILESTONE_FIELDS, "TradeLens Entry Milestone Fields", "Assign entry fields to TradeLens API endpoint.", key_label: "Field", allowed_keys: OpenChain::MilestoneNotificationConfigSupport::DataCrossReferenceKeySelector.new("Entry"), value_label: "Endpoint", allowed_values: OpenChain::MilestoneNotificationConfigSupport::DataCrossReferenceValueSelector.new("Entry"), allow_blank_value: false, show_value_column: true),
      xref_attributes(LL_CARB_STATEMENTS, "CARB Statements", "Enter the CARB Statement code in the Code field and the Code Description in the Description field.", key_label: "Code", value_label: "Description", show_value_column: true),
      xref_attributes(LL_PATENT_STATEMENTS, "Patent Statements", "Enter the Patent Statement code in the Code field and the Code Description in the Description field.", key_label: "Code", value_label: "Description", show_value_column: true),
      xref_attributes(MID_XREF, "MID Cross Reference", "Enter the Factory Identifier in the Code field and the actual MID in the MID field.", key_label: "Code", value_label: "MID", require_company: true, allow_blank_value: false, show_value_column: true, upload_instructions: "Spreadsheet should contain a header row, with Factory Code in column A and MID in column B."),
      xref_attributes(SPI_AVAILABLE_COUNTRY_COMBINATION, "SPI-Available Country Combinations", "Combinations of entry country of export and origin ISO codes that have SPI available.", key_label: make_compound_key("Export Country ISO", "Origin Country ISO"), value_label: "N/A - unused", key_upload_label: "Export Country ISO", value_upload_label: "Origin Country ISO", preprocessor: PREPROCESSORS[SPI_AVAILABLE_COUNTRY_COMBINATION]),
      xref_attributes(SIEMENS_BILLING_STANDARD, "Siemens Billing Standard Group", "Tax IDs for the standard Siemens billing report", key_label: "Tax ID", allow_blank_values: false, require_company: false, show_value_column: false, value_label: "Value"),
      xref_attributes(SIEMENS_BILLING_ENERGY, "Siemens Billing Energy Group", "Tax IDs for the energy Siemens billing report", key_label: "Tax ID", allow_blank_values: false, require_company: false, show_value_column: false, value_label: "Value"),
      xref_attributes(PART_XREF, "Part Cross Reference", "Enter the Part Number in the Part field and true or false in the active field", key_label: "Part", value_label: "Active", require_company: true, allow_blank_value: false, show_value_column: true, upload_instructions: "Spreadsheet should contain a header row, with Part Number in column A and true or false in column B.")
    ]
    # rubocop:enable Layout/LineLength

    user_xrefs = user ? all_editable_xrefs.select {|x| can_view? x[:identifier], user} : all_editable_xrefs

    h = {}
    user_xrefs.each {|x| h[x[:identifier]] = x}
    h
  end

  def self.xref_attributes identifier, title, description, options = {}
    options = {key_label: "Key", value_label: "Value", show_value_column: true, allow_duplicate_keys: false, require_company: false}.merge options

    # Title is what is displayed as the link/button to access the page
    # Description is text/instructions included at the top of the list/edit screen.
    options[:title] = title
    options[:description] = description
    options[:identifier] = identifier
    options[:preprocessor] ||= PREPROCESSORS['none']

    options
  end
  private_class_method :xref_attributes

  def self.company_for_xref xref_hsh
    return if xref_hsh[:company].try(:keys).blank?
    Company.find_by(xref_hsh[:company])
  end

  def can_view? user
    self.class.can_view? cross_reference_type, user
  end

  def self.preprocess_and_add_xref! xref_type, new_key, new_value, company_id = nil
    xref_hsh = xref_edit_hash(nil)[xref_type]
    k, v = xref_hsh[:preprocessor].call(new_key, new_value).values_at(:key, :value)

    if k.blank?
      # There's never a time where the key can be blank
      return false
    elsif xref_hsh[:show_value_column] && v.blank?
      # If the value is blank, check to see if the setup allows blanks..if not, reject
      return false unless xref_hsh[:allow_blank_value] == true
    end

    add_xref! xref_type, k, v, company_id
    true
  end

  def self.can_view? cross_reference_type, user
    # At this point, anyone that can view, can also edit
    case cross_reference_type
    when RL_FABRIC_XREF, RL_VALIDATED_FABRIC
      MasterSetup.get.custom_feature? "Polo"
    when US_HTS_TO_CA, ASCE_MID, CI_LOAD_DEFAULT_GOODS_DESCRIPTION, SHIPMENT_ENTRY_LOAD_CUSTOMERS,
        SHIPMENT_CI_LOAD_CUSTOMERS, ENTRY_MID_VALIDATIONS, INVOICE_CI_LOAD_CUSTOMERS, ASCE_BRAND, MID_XREF,
        CA_HTS_TO_DESCR
      MasterSetup.get.custom_feature?("WWW VFI Track Reports") && (user.sys_admin? || user.in_group?('xref-maintenance'))
    when UA_SITE_TO_COUNTRY
      MasterSetup.get.custom_feature?("UnderArmour")
    when HM_PARS_NUMBER
      MasterSetup.get.custom_feature?("WWW VFI Track Reports") && (user.sys_admin? || user.in_group?("pars-maintenance"))
    when OTA_REFERENCE_FIELDS
      user.admin?
    when PART_XREF
      user.admin?
    when LL_CARB_STATEMENTS, LL_PATENT_STATEMENTS
      MasterSetup.get.custom_feature?("Lumber Liquidators") && user.admin?
    when SPI_AVAILABLE_COUNTRY_COMBINATION
      MasterSetup.get.custom_feature?("WWW") && (user.sys_admin? || user.in_group?('xref-maintenance'))
    when TRADELENS_ENTRY_MILESTONE_FIELDS
      MasterSetup.get.custom_feature?("WWW VFI Track Reports") && user.sys_admin?
    when SIEMENS_BILLING_STANDARD, SIEMENS_BILLING_ENERGY
      user.admin?
    else
      false
    end
  end

  # return a hash of all key value pairs
  def self.get_all_pairs cross_reference_type
    r = {}
    self.where(cross_reference_type: cross_reference_type).each do |d|
      r[d.key] = d.value
    end
    r
  end

  def self.keys cross_reference_type
    Set.new(self.where(cross_reference_type: cross_reference_type).pluck(:key))
  end

  def self.find_ascena_brand department
    find_unique where(cross_reference_type: ASCE_BRAND, key: department)
  end

  def self.find_rl_profit_center_by_brand importer_id, brand
    find_unique where(cross_reference_type: RL_BRAND_TO_PROFIT_CENTER, key: brand, company_id: importer_id)
  end

  def self.find_rl_brand_by_po po_number
    find_unique where(cross_reference_type: RL_PO_TO_BRAND, key: po_number)
  end

  def self.find_ua_plant_to_iso plant
    find_unique where(cross_reference_type: UA_PLANT_TO_ISO, key: plant)
  end

  def self.find_ua_country_by_site site_number
    find_unique where(cross_reference_type: UA_SITE_TO_COUNTRY, key: site_number)
  end

  def self.find_ua_315_milestone ua_shipment_identifier, event_code
    find_unique where(cross_reference_type: UA_315_MILESTONE_EVENT, key: make_compound_key(ua_shipment_identifier, event_code))
  end

  # Value should always be a "1" since we use this just to see if the key exists
  # the create method below will take care of this for you
  def self.find_ua_material_color_plant material, color, plant
    find_unique where(cross_reference_type: UA_MATERIAL_COLOR_PLANT, key: "#{material}-#{color}-#{plant}")
  end

  # Write the Under Armour Material-Color-Plant XREF with a value of "1"
  # we use this xref to test that the key exists, so the consistent value
  # never needs to change. Arrr!
  def self.create_ua_material_color_plant! material, color, plant
    add_xref! UA_MATERIAL_COLOR_PLANT, "#{material}-#{color}-#{plant}", '1'
  end

  def self.find_ua_winshuttle_fingerprint material, color, plant
     find_unique where(cross_reference_type: UA_WINSHUTTLE_FINGERPRINT, key: make_compound_key(material, color, plant))
  end

  def self.create_ua_winshuttle_fingerprint! material, color, plant, fingerprint
    add_xref! UA_WINSHUTTLE_FINGERPRINT, make_compound_key(material, color, plant), fingerprint
  end

  # Value will be MD5 hash of full line from Lenox Item Master Feed keyed by the lenox part number
  def self.find_lenox_item_master_hash part_number
    find_unique where(cross_reference_type: LENOX_ITEM_MASTER_HASH, key: part_number)
  end

  def self.create_lenox_item_master_hash! part_number, hash
    add_xref! LENOX_ITEM_MASTER_HASH, part_number, hash
  end

  # id_iso is the concatentation of a product id and a classification country's ISO
  def self.find_lenox_hts_fingerprint prod_id, country_iso
    find_unique where(cross_reference_type: LENOX_HTS_FINGERPRINT, key: make_compound_key(prod_id, country_iso))
  end

  # fingerprint is a hash of the HTS numbers for all tariff records under a product/classification
  def self.create_lenox_hts_fingerprint!(prod_id, country_iso, fingerprint)
    add_xref! LENOX_HTS_FINGERPRINT, make_compound_key(prod_id, country_iso), fingerprint
  end

  def self.find_jjill_order_fingerprint order
    find_unique where(cross_reference_type: JJILL_ORDER_FINGERPRINT, key: order.id.to_s)
  end

  def self.create_jjill_order_fingerprint! order, fingerprint
    add_xref! JJILL_ORDER_FINGERPRINT, order.id.to_s, fingerprint
  end

  def self.find_alliance_gl_code charge_code
    find_unique where(cross_reference_type: ALLIANCE_CHARGE_TO_GL_ACCOUNT, key: charge_code)
  end

  def self.find_alliance_bank_number bank_no
    find_unique where(cross_reference_type: ALLIANCE_BANK_ACCOUNT_TO_INTACCT, key: bank_no)
  end

  def self.find_intacct_bank_gl_cash_account intacct_bank_number
    find_unique where(cross_reference_type: INTACCT_BANK_CASH_GL_ACCOUNT, key: intacct_bank_number)
  end

  def self.find_intacct_customer_number data_source, customer_number
    raise "Unkown customer number data source #{data_source}" unless ["Alliance", "Fenix"].include? data_source

    find_unique where(cross_reference_type: INTACCT_CUSTOMER_XREF, key: make_compound_key(data_source, customer_number))
  end

  def self.find_intacct_vendor_number data_source, vendor_number
    raise "Unkown vendor number data source #{data_source}" unless ["Alliance", "Fenix"].include? data_source

    find_unique where(cross_reference_type: INTACCT_VENDOR_XREF, key: make_compound_key(data_source, vendor_number))
  end

  def self.find_rl_fabric fabric
    find_unique where(cross_reference_type: RL_FABRIC_XREF, key: fabric)
  end

  def self.find_315_milestone entry, event_code
    find_unique(where(cross_reference_type: OUTBOUND_315_EVENT, key: milestone_key(entry, event_code)))
  end

  def self.create_315_milestone! entry, event_code, date
    add_xref! OUTBOUND_315_EVENT, milestone_key(entry, event_code), date
  end

  def self.milestone_key obj, event_code
    if obj.is_a?(Entry)
      make_compound_key(obj.source_system, obj.broker_reference, event_code)
    elsif obj.is_a?(SecurityFiling)
      make_compound_key(obj.host_system, obj.host_system_file_number, event_code)
    else
      raise "Unknown Model type encountered: #{obj.class}.  Unable to generate 315 cross reference key."
    end
  end

  private_class_method :milestone_key

  def self.create_us_hts_to_ca! us_hts, ca_hts, importer_id
    add_xref! US_HTS_TO_CA, TariffRecord.clean_hts(us_hts), TariffRecord.clean_hts(ca_hts), importer_id
  end

  def self.find_us_hts_to_ca us_hts, importer_id
    find_unique(where(cross_reference_type: US_HTS_TO_CA, key: us_hts, company_id: importer_id))
  end

  def self.create_ca_hts_to_descr! ca_hts, descr, importer_id
    add_xref! CA_HTS_TO_DESCR, TariffRecord.clean_hts(ca_hts), descr, importer_id
  end

  def self.find_ca_hts_to_descr ca_hts, importer_id
    find_unique(where(cross_reference_type: CA_HTS_TO_DESCR, key: ca_hts, company_id: importer_id))
  end

  def self.create_pvh_invoice! vend_name, inv_number
    add_xref! PVH_INVOICES, make_compound_key(vend_name, inv_number), nil
  end

  def self.find_pvh_invoice vend_name, inv_number
    !where(cross_reference_type: PVH_INVOICES, key: make_compound_key(vend_name, inv_number)).empty?
  end

  def self.find_and_mark_next_unused_hm_pars_number
    xref = nil
    while xref.nil?
      # Find the next available pars number from the list...
      pars = add_pars_clause(DataCrossReference.where(cross_reference_type: HM_PARS_NUMBER)).order("`key`, id").first
      return nil if pars.nil?

      # Lock it (this will actually reload the data) and will lock the database row
      Lock.db_lock(pars) do
        # It's possible that this record (while waiting for the lock) has actually been used..in which case, try again
        next if pars.value.present?

        # if the value is blank, then we can use this record...mark it as used and then return the number
        pars.update! value: "1"
        xref = pars
      end
    end

    xref
  end

  def self.unused_pars_count
    add_pars_clause(DataCrossReference.where(cross_reference_type: HM_PARS_NUMBER)).count
  end

  def self.add_pars_clause scoped
    scoped.where("`value` IS NULL OR `value` = ''")
  end

  def self.add_hm_pars_number pars_number
    add_xref! HM_PARS_NUMBER, pars_number, nil
  end

  def self.hash_ota_reference_fields
    fields = list_ota_reference_fields
    out = Hash.new { |h, k| h[k] = [] }
    fields.each do |f|
      type, f_uid = f.split("~")
      out[type] << f_uid.to_sym
    end
    out
  end

  def self.update_ota_reference_fields! hsh
    new_fields = []
    hsh.each_key do |cm_name|
      hsh[cm_name]&.each { |uid| new_fields << "#{cm_name}~#{uid}" }
    end
    existing_fields = list_ota_reference_fields
    fields_to_add = new_fields - existing_fields
    fields_to_remove = existing_fields - new_fields
    transaction do
      insert_ota_reference_fields!(fields_to_add)
      where(cross_reference_type: OTA_REFERENCE_FIELDS, key: fields_to_remove).destroy_all
    end
  end

  def self.insert_ota_reference_fields! fields_to_add
    to_add = fields_to_add.map do |f|
      xref = DataCrossReference.new(cross_reference_type: OTA_REFERENCE_FIELDS, key: f)
      raise "Can't save invalid DataCrossReference: #{xref.errors.messages}" unless xref.valid?
      # see https://github.com/zdennis/activerecord-import
      xref.run_callbacks(:save) { false }
      xref.run_callbacks(:create) { false }
      xref
    end
    import to_add, validate: false
  end

  private_class_method :insert_ota_reference_fields!

  def self.list_ota_reference_fields
    DataCrossReference.where(cross_reference_type: OTA_REFERENCE_FIELDS).pluck(:key)
  end

  private_class_method :list_ota_reference_fields

  def self.find_po_fingerprint order
    find_unique_obj nil, key: order.order_number, xref_type: PO_FINGERPRINT
  end

  def self.create_po_fingerprint order, fingerprint
    add_xref! PO_FINGERPRINT, order.order_number, fingerprint
  end

  def self.find_us_port_code locode, company: nil
    val = nil
    if company
      val = find_unique(DataCrossReference.where("company_id = ?", company), key: locode, xref_type: UN_LOCODE_TO_US_CODE)
    end

    val = find_unique(DataCrossReference.where("company_id IS NULL"), key: locode, xref_type: UN_LOCODE_TO_US_CODE) if val.nil?

    val
  end

  def self.find_mid key, company
    relation = DataCrossReference.where("company_id = ? ", (company.is_a?(Numeric) ? company : company.id))
    find_unique(relation, key: key, xref_type: MID_XREF)
  end

  def self.key? key, cross_reference_type
    DataCrossReference.where(key: key, cross_reference_type: cross_reference_type).exists?
  end

  def self.find_unique relation, key: nil, xref_type: nil
    find_unique_relation(relation, key: key, xref_type: xref_type).pluck(:value).first
  end
  private_class_method :find_unique

  def self.find_unique_obj relation, key: nil, xref_type: nil
    find_unique_relation(relation, key: key, xref_type: xref_type).first
  end
  private_class_method :find_unique_obj

  def self.find_unique_relation relation, key: nil, xref_type: nil
    relation = DataCrossReference.all if relation.nil?

    if key
      relation = relation.where(key: key)
    end

    if xref_type
      relation = relation.where(cross_reference_type: xref_type)
    end

    relation.limit(1).order("updated_at DESC")
  end
  private_class_method :find_unique_relation

  def self.hash_for_type cross_reference_type, company_id: nil
    h = {}
    query = self.where(cross_reference_type: cross_reference_type)
    query = query.where(company_id: company_id) if company_id

    query.select("`key`, `value`").collect {|d| h[d.key] = d.value}
    h
  end

  # create the record in the database
  def self.add_xref! cross_reference_type, key, value, company_id = nil
    xref = self.find_by(cross_reference_type: cross_reference_type, key: key, company_id: company_id)
    xref ||= self.new(cross_reference_type: cross_reference_type, key: key, company_id: company_id)
    xref.value = value
    xref.save!
    xref
  end

  def self.load_cross_references io, cross_reference_type, company_id = nil
    csv = CSV.new io
    csv.each do |row|
      add_xref! cross_reference_type, row[0], row[1], company_id
    end
  end

  def self.make_compound_key *args
    # Join the values on a character sequence which should never be found in the actual key values.
    # Ideally, we could use some non-printing char but there seems to be issues with that somewhere between activerecord
    # and mysql.
    args.join(compound_key_token)
  end

  def self.decode_compound_key cross_reference
    cross_reference.key.split(compound_key_token)
  end

  def self.compound_key_token
    "*~*"
  end

  def self.generate_csv xref_type, user
    output = nil
    if can_view? xref_type, user
      cfg = xref_edit_hash(user)[xref_type]
      recs = run_csv_query xref_type
      output = CSV.generate do |csv|
        csv << create_csv_header(cfg)
        recs.each { |r| csv << create_csv_row(r, cfg) }
      end
    end
    output
  end

  def self.run_csv_query xref_type
    qry =
      <<-SQL
        SELECT dcr.key, value, dcr.updated_at, CONCAT(c.name, IF(c.system_code IS NOT NULL && RTRIM(c.system_code) <> '',
                                                                CONCAT(" (",c.system_code,")"),
                                                                '')) AS company
        FROM data_cross_references dcr
          LEFT OUTER JOIN companies c ON c.id = dcr.company_id
        WHERE cross_reference_type = #{ActiveRecord::Base.sanitize xref_type} ORDER BY dcr.key
        LIMIT 25000
      SQL
    ActiveRecord::Base.connection.exec_query qry
  end

  def self.create_csv_header xref_edit_hsh
    h = [xref_edit_hsh[:key_label]]
    h << xref_edit_hsh[:value_label] if xref_edit_hsh[:show_value_column]
    h << "Company" if xref_edit_hsh[:require_company]
    h << "Last Updated"
  end

  def self.create_csv_row row, xref_edit_hsh
    r = [row["key"]]
    r << row["value"] if xref_edit_hsh[:show_value_column]
    r << row["company"] if xref_edit_hsh[:require_company]
    r << row["updated_at"]
  end

  private_class_method :run_csv_query
  private_class_method :create_csv_header
  private_class_method :create_csv_row

end
