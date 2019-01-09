class AddIndexesToSpecialTariffCrossReferences < ActiveRecord::Migration
  def self.up
    if !index_exists?(:special_tariff_cross_references, :special_hts_number,  name: "hts_date_index")
      add_index :special_tariff_cross_references, [:special_hts_number, :effective_date_start, :effective_date_end], name: "hts_date_index"
    end
  end

  def self.down
    if index_exists?(:special_tariff_cross_references, :special_hts_number,  name: "hts_date_index")
      remove_index :special_tariff_cross_references, name: "hts_date_index"
    end
  end
end

