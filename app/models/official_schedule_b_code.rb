# == Schema Information
#
# Table name: official_schedule_b_codes
#
#  created_at             :datetime         not null
#  end_use_classification :string(255)
#  hitech_classification  :string(255)
#  hts_code               :string(255)
#  id                     :integer          not null, primary key
#  long_description       :text
#  naics_classification   :string(255)
#  quantity_1             :text
#  quantity_2             :text
#  short_description      :text
#  sitc_code              :string(255)
#  updated_at             :datetime         not null
#  usda_code              :string(255)
#

class OfficialScheduleBCode < ActiveRecord::Base
  attr_accessible :end_use_classification, :hitech_classification, :hts_code, :long_description, :naics_classification, :quantity_1, :quantity_2, :short_description, :sitc_code, :usda_code

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

        osb = OfficialScheduleBCode.find_by(hts_code: data_hash[:hts_code])
        osb = OfficialScheduleBCode.new unless osb
        osb.update! data_hash
      }
    end
    OfficialScheduleBCode.count
  end

end
