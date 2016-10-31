require 'csv'

class DataCrossReference < ActiveRecord::Base
  belongs_to :company
  validates_presence_of :key, :cross_reference_type

  JJILL_ORDER_FINGERPRINT ||= 'jjill_order'
  LENOX_ITEM_MASTER_HASH ||= 'lenox_itm'
  LENOX_HTS_FINGERPRINT ||= 'lenox_hts_fingerprint'
  RL_BRAND_TO_PROFIT_CENTER ||= 'profit_center'
  RL_PO_TO_BRAND ||= 'po_to_brand'
  UA_PLANT_TO_ISO ||= 'uap2i'
  UA_WINSHUTTLE_FINGERPRINT ||= 'uawin-fingerprint'
  UA_315_MILESTONE_EVENT ||= 'ua-315'
  UA_MATERIAL_COLOR_PLANT ||= 'ua-mcp'
  ALLIANCE_CHARGE_TO_GL_ACCOUNT ||= 'al_gl_code'
  ALLIANCE_BANK_ACCOUNT_TO_INTACCT ||= 'al_bank_no'
  INTACCT_CUSTOMER_XREF ||= 'in_cust'
  INTACCT_VENDOR_XREF ||= 'in_vend'
  INTACCT_BANK_CASH_GL_ACCOUNT ||= 'in_cash_gl'
  ALLIANCE_FREIGHT_CHARGE_CODE ||= 'al_freight_code'
  FENIX_ALS_CUSTOMER_NUMBER ||= 'fx_als_cust'
  LANDS_END_MID ||= 'le_mid'
  RL_FABRIC_XREF ||= 'rl_fabric'
  RL_VALIDATED_FABRIC ||= 'rl_valid_fabric'
  RL_FABRIC_FINGERPRINT ||= 'rl_fabric_fingerprint'
  UA_DUTY_RATE ||= 'ua_duty_rate'
  ALLIANCE_CHECK_REPORT_CHECKSUM ||= 'al_check_checksum'
  ALLIANCE_INVOICE_REPORT_CHECKSUM ||= 'al_inv_checksum'
  OUTBOUND_315_EVENT ||= '315'
  PO_FINGERPRINT ||= 'po_id'
  EXPORT_CARRIER ||= 'export_carriers'
  US_HTS_TO_CA ||= 'us_hts_to_ca'

  def self.xref_edit_hash user
    all_editable_xrefs = [
      xref_attributes(RL_FABRIC_XREF, "MSL+ Fabric Cross References", "Enter the starting fabric value in the Failure Fiber field and the final value to send to MSL+ in the Approved Fiber field.", key_label: "Failure Fiber", value_label: "Approved Fiber"),
      xref_attributes(RL_VALIDATED_FABRIC, "MSL+ Valid Fabric List", "Only values included in this list are allowed to be sent to to MSL+.", key_label: "Approved Fiber", show_value_column: false),
      xref_attributes(US_HTS_TO_CA, "System Classification Cross References", "Products with a US HTS number and no Canadian tariff are assigned the corresponding Canadian HTS.", key_label: "United States HTS", value_label: "Canada HTS", require_company: true)
    ]

    user_xrefs = all_editable_xrefs.select {|x| can_view? x[:identifier], user}

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

    options
  end
  private_class_method :xref_attributes

  def can_view? user
    self.class.can_view? cross_reference_type, user
  end

  def self.can_view? cross_reference_type, user
    # At this point, anyone that can view, can also edit
    case cross_reference_type
    when RL_FABRIC_XREF, RL_VALIDATED_FABRIC
      (Rails.env.development? || MasterSetup.get.system_code == "polo")
    when US_HTS_TO_CA
      (Rails.env.development?) || (MasterSetup.get.system_code == "www-vfitrack-net" && user.sys_admin?)
    else
      false
    end
  end

  #return a hash of all key value pairs
  def self.get_all_pairs cross_reference_type
    r = {}
    self.where(cross_reference_type:cross_reference_type).each do |d|
      r[d.key] = d.value
    end
    r
  end

  def self.find_rl_profit_center_by_brand importer_id, brand
    find_unique where(:cross_reference_type => RL_BRAND_TO_PROFIT_CENTER, :key => brand, company_id: importer_id)
  end

  def self.find_rl_brand_by_po po_number
    find_unique where(:cross_reference_type => RL_PO_TO_BRAND, :key => po_number)
  end

  def self.find_ua_plant_to_iso plant
    find_unique where(cross_reference_type:UA_PLANT_TO_ISO, key:plant)
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
    find_unique where(cross_reference_type:LENOX_ITEM_MASTER_HASH, key:part_number)
  end

  def self.create_lenox_item_master_hash! part_number, hash
    add_xref! LENOX_ITEM_MASTER_HASH, part_number, hash
  end

  #id_iso is the concatentation of a product id and a classification country's ISO
  def self.find_lenox_hts_fingerprint prod_id, country_iso
    find_unique where(cross_reference_type: LENOX_HTS_FINGERPRINT, key: make_compound_key(prod_id, country_iso))
  end

  #fingerprint is a hash of the HTS numbers for all tariff records under a product/classification
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

  def self.find_lands_end_mid factory_code, hts
    find_unique where(cross_reference_type: LANDS_END_MID, key: make_compound_key(factory_code, hts))
  end

  def self.create_lands_end_mid! factory_code, hts, mid
    add_xref! LANDS_END_MID, make_compound_key(factory_code, hts), mid
  end

  def self.find_rl_fabric fabric
    find_unique where(cross_reference_type: RL_FABRIC_XREF, key: fabric)
  end

  def self.find_rl_fabric_fingerprint product_unique_identifier
    find_unique where(cross_reference_type: RL_FABRIC_FINGERPRINT, key: product_unique_identifier)
  end

  def self.create_rl_fabric_fingerprint! product_unique_identifier, fingerprint
    add_xref! RL_FABRIC_FINGERPRINT, product_unique_identifier, fingerprint
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

  def self.create_us_hts_to_ca! us_hts, ca_hts, importer_id
    add_xref! US_HTS_TO_CA, TariffRecord.clean_hts(us_hts), TariffRecord.clean_hts(ca_hts), importer_id
  end

  def self.find_us_hts_to_ca us_hts, importer_id
    find_unique(where(cross_reference_type: US_HTS_TO_CA, key: us_hts, company_id: importer_id))
  end

  private_class_method :milestone_key

  def self.find_po_fingerprint order
    find_unique_obj scoped, key: order.order_number, xref_type: PO_FINGERPRINT
  end

  def self.create_po_fingerprint order, fingerprint
    add_xref! PO_FINGERPRINT, order.order_number, fingerprint
  end

  def self.has_key? key, cross_reference_type
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
    if key
      relation = relation.where(key: key)
    end

    if xref_type
      relation = relation.where(cross_reference_type: xref_type)
    end

    relation.limit(1).order("updated_at DESC")
  end
  private_class_method :find_unique_relation

  def self.hash_for_type cross_reference_type
    h = Hash.new
    self.where(cross_reference_type:cross_reference_type).select("`key`, `value`").collect {|d| h[d.key] = d.value}
    h
  end
  
  #create the record in the database
  def self.add_xref! cross_reference_type, key, value, company_id = nil
    xref = self.where(:cross_reference_type => cross_reference_type, :key => key, :company_id => company_id).first
    xref = self.new(cross_reference_type:cross_reference_type,key:key,company_id:company_id) unless xref
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
