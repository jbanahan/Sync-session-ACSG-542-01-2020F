# == Schema Information
#
# Table name: official_schedule_b_codes
#
#  id                     :integer          not null, primary key
#  hts_code               :string(255)
#  short_description      :text
#  long_description       :text
#  quantity_1             :text
#  quantity_2             :text
#  sitc_code              :string(255)
#  end_use_classification :string(255)
#  usda_code              :string(255)
#  naics_classification   :string(255)
#  hitech_classification  :string(255)
#  created_at             :datetime
#  updated_at             :datetime
#

class OfficialScheduleBCode < ActiveRecord::Base

  #clears current schedule b list and reloads it from census file
  def self.load_from_census_file file_path
    OfficialScheduleBCode.transaction do 
      OfficialScheduleBCode.delete_all
      CSV.foreach(file_path) {|row|
        data_hash = {
          :hts_code => row[0].to_s.strip,
          :short_description => row[1].to_s.strip,
          :long_description => row[1].to_s.strip,
          :quantity_1 => row[2].to_s.strip,
          :quantity_2 => row[3].to_s.strip
        }
        next if data_hash[:hts_code].to_s.blank? || data_hash[:hts_code].to_i <= 0

        osb = OfficialScheduleBCode.find_by_hts_code(data_hash[:hts_code])
        osb = OfficialScheduleBCode.new unless osb
        osb.update_attributes data_hash
      }
    end
    OfficialScheduleBCode.count
  end

end
