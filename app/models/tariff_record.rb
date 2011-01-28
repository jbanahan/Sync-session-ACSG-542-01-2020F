class TariffRecord < ActiveRecord::Base
  #hold arrays of OfficialTariffs for potential matches to be used for this record
  attr_accessor :hts_1_matches, :hts_2_matches, :hts_3_matches 
  
  def hts_1=(str)
    write_attribute(:hts_1, clean_hts(str))
  end

  def hts_2=(str)
    write_attribute(:hts_2, clean_hts(str))
  end

  def hts_3=(str)
    write_attribute(:hts_3, clean_hts(str))
  end

  private
  def clean_hts(str)
    str.gsub(/[^0-9]/,'')
  end
  
end
