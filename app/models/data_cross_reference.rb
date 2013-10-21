require 'csv'

class DataCrossReference < ActiveRecord::Base
  belongs_to :company

  RL_BRAND_TO_PROFIT_CENTER ||= 'profit_center'
  RL_PO_TO_BRAND ||= 'po_to_brand'
  UA_PLANT_TO_ISO ||= 'uap2i'
  UA_WINSHUTTLE ||= 'uawin'

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

end
