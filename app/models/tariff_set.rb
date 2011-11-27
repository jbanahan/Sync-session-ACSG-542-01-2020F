class TariffSet < ActiveRecord::Base
  has_many :tariff_set_records, :dependent => :destroy
  belongs_to :country

  # Replaces the OfficialTariffs for this country with the values from this set
  # If a user is provided, the user will receive a system message when the process is complete
  def activate user=nil
    OfficialTariff.transaction do
      OfficialTariff.where(:country_id=>self.country_id).destroy_all
      self.tariff_set_records.each do |tsr|
        tsr.build_official_tariff.save!
      end
      TariffSet.where(:country_id=>self.country_id).where("tariff_sets.id = #{self.id} OR tariff_sets.active = ?",true).each do |ts|
        ts.update_attributes(:active=>ts.id==self.id)
      end
      if user
        user.messages.create(:subject=>"Tariff Set #{self.label} activated.",:body=>"Tariff Set #{self.label} has been successfully activated.")
      end
    end
  end

  #returns an array where the first element is a collection of TariffSetRecords that have been added
  #the second element is a collection of TariffSetRecords that have been removed
  #and the third element is a hash where the key is the hts_code and the values are the output of TariffSetRecord#compare for records that have changed
  def compare old_tariff_set

    added = self.tariff_set_records.where("hts_code NOT IN (SELECT hts_code FROM tariff_set_records WHERE tariff_set_id = ?)",old_tariff_set.id)
    removed = old_tariff_set.tariff_set_records.where("hts_code NOT IN (SELECT hts_code FROM tariff_set_records WHERE tariff_set_id = ?)",self.id)

    changed = {}
    new_records = self.tariff_set_records.to_a
    old_record_hash = {}
    old_tariff_set.tariff_set_records.each {|tr| old_record_hash[tr.hts_code] = tr}

    new_records.each do |nr|
      o = old_record_hash[nr.hts_code]
      if o
        comparison = nr.compare o
        changed[nr.hts_code] = comparison unless comparison.first.blank?
      end
    end
    [added,removed,changed]
  end

end
