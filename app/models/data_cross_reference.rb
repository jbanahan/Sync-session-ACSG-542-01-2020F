require 'csv'

class DataCrossReference < ActiveRecord::Base
  belongs_to :company

  RL_BRAND_TO_PROFIT_CENTER ||= 'profit_center'
  RL_PO_TO_BRAND ||= 'po_to_brand'
  UA_PLANT_TO_ISO ||= 'uap2i'
  UA_WINSHUTTLE ||= 'uawin'
  UA_315_MILESTONE_EVENT ||= 'ua-315'
  UA_MATERIAL_COLOR_PLANT ||= 'ua-mcp'

  def self.find_rl_profit_center_by_brand brand
    find_unique where(:cross_reference_type => RL_BRAND_TO_PROFIT_CENTER, :key => brand)
  end

  def self.find_rl_brand_by_po po_number
    find_unique where(:cross_reference_type => RL_PO_TO_BRAND, :key => po_number)
  end

  def self.find_ua_plant_to_iso plant
    find_unique where(cross_reference_type:UA_PLANT_TO_ISO, key:plant)
  end

  def self.find_ua_winshuttle_hts material_plant
    find_unique where(cross_reference_type:UA_WINSHUTTLE, key:material_plant)
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

  def self.find_unique relation
    values = relation.limit(1).order("updated_at DESC").pluck(:value)
    values.first
  end

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

  private_class_method :find_unique

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
    args.join("*~*")
  end

  def self.decode_compound_key cross_reference
    cross_reference.key.split("*~*")
  end

end
