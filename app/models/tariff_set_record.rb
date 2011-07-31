class TariffSetRecord < ActiveRecord::Base
  belongs_to :tariff_set
  belongs_to :country

  #create an unsaved OfficialTariff with the same data as this record
  def build_official_tariff
    OfficialTariff.new(self.attributes.select {|k,v| !["id","created_at","udpated_at","tariff_set_id"].include?(k)})
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
      my_val_c = my_val.respond_to?('downcase') ? my_val.downcase : my_val
      o_val = o_attributes[k]
      o_val_c = o_val.respond_to?('downcase') ? o_val.downcase : o_val
      if my_val_c != o_val_c
        r[0][k]= my_val
        r[1][k]= o_val
      end
    end
    r
  end

end
