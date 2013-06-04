require 'csv'

class DataCrossReference < ActiveRecord::Base
  belongs_to :company

  RL_BRAND_TO_PROFIT_CENTER ||= 'profit_center'
  RL_PO_TO_BRAND ||= 'po_to_brand'

  def self.find_rl_profit_center_by_brand brand
    find_unique where(:cross_reference_type => RL_BRAND_TO_PROFIT_CENTER, :key => brand)
  end

  def self.find_rl_brand_by_po po_number
    find_unique where(:cross_reference_type => RL_PO_TO_BRAND, :key => po_number)
  end

  def self.find_unique relation
    values = relation.limit(1).order("updated_at DESC").pluck(:value)
    values.first
  end
  private_class_method :find_unique

  def self.load_cross_references io, cross_reference_type, company_id = nil
    csv = CSV.new io
    csv.each do |row|
      xref = DataCrossReference.where(:cross_reference_type => cross_reference_type, :key => row[0], :company_id => company_id).first_or_create!
      xref.value = row[1]
      xref.save!
    end
  end

end