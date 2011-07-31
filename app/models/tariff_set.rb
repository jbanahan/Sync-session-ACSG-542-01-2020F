class TariffSet < ActiveRecord::Base
  has_many :tariff_set_records, :dependent => :destroy
  belongs_to :country

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
