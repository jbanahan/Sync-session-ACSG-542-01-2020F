# == Schema Information
#
# Table name: tariff_set_records
#
#  add_valorem_rate                 :string(255)
#  calculation_method               :string(255)
#  chapter                          :text(65535)
#  column_2_rate                    :text(65535)
#  country_id                       :integer
#  created_at                       :datetime         not null
#  erga_omnes_rate                  :string(255)
#  export_regulations               :string(255)
#  fda_indicator                    :string(255)
#  full_description                 :text(65535)
#  general_preferential_tariff_rate :string(255)
#  general_rate                     :string(255)
#  heading                          :text(65535)
#  hts_code                         :string(255)
#  id                               :integer          not null, primary key
#  import_regulations               :string(255)
#  most_favored_nation_rate         :string(255)
#  per_unit_rate                    :string(255)
#  remaining_description            :text(65535)
#  special_rates                    :text(65535)
#  sub_heading                      :text(65535)
#  tariff_set_id                    :integer
#  unit_of_measure                  :string(255)
#  updated_at                       :datetime         not null
#
# Indexes
#
#  index_tariff_set_records_on_hts_code       (hts_code)
#  index_tariff_set_records_on_tariff_set_id  (tariff_set_id)
#

class TariffSetRecord < ActiveRecord::Base
  attr_accessible :add_valorem_rate, :calculation_method, :chapter, 
    :column_2_rate, :country_id, :erga_omnes_rate, 
    :export_regulations, :fda_indicator, :full_description, 
    :general_preferential_tariff_rate, :general_rate, :heading, 
    :hts_code, :import_regulations, :most_favored_nation_rate, 
    :per_unit_rate, :remaining_description, :special_rates, 
    :sub_heading, :tariff_set_id, :unit_of_measure, :country
  
  belongs_to :tariff_set
  belongs_to :country

  #create an unsaved OfficialTariff with the same data as this record
  def build_official_tariff
    OfficialTariff.new(self.attributes.select {|k,v| !["id","created_at","updated_at","tariff_set_id"].include?(k)})
  end

  #returns an array of hashes where the first element is this object's attributes that are different
  #and the second element is the other object's elements that are different
  def compare other_tariff_set_record
    o = other_tariff_set_record
    comparison_attributes = self.attributes.select {|k,v| !["id","created_at","updated_at","tariff_set_id"].include?(k)}
    o_attributes = o.attributes
    r = [{},{}]
    comparison_attributes.keys.each do |k|
      my_val = comparison_attributes[k]
      my_val_c = prep_tariff_attribute_for_comparison(k, my_val)
      o_val = o_attributes[k]
      o_val_c = prep_tariff_attribute_for_comparison(k, o_val)
      if my_val_c != o_val_c
        r[0][k]= my_val
        r[1][k]= o_val
      end
    end
    r
  end

  def prep_tariff_attribute_for_comparison attribute, value
    val = value.to_s.downcase.strip

    # Don't compare against punctuation, whitespace for comparison sake for a couple attributes.  These values tend to get mixed around between versions.
    # Basically, this is all the non-rate columns we're comparing against.
    if ['full_description', 'chapter', 'heading', 'sub_heading', 'remaining_description', 'unit_of_measure']
      val = val.gsub(/[[[:punct:]]\s]/, "")
    end
    val
  end

end
