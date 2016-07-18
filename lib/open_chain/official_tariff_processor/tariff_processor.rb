require 'open_chain/official_tariff_processor/tariff_processor_registry'
module OpenChain; module OfficialTariffProcessor; class TariffProcessor
  def self.process_country country
    processor = OpenChain::OfficialTariffProcessor::TariffProcessorRegistry.get country
    return nil unless processor
    find_required_tariffs_to_process(country).find_in_batches(batch_size: 500) do |group|
      # this transaction is not for integrity, it helps with performance
      #  because it means there's only one commit run instead of a commit on every row
      ActiveRecord::Base.transaction do
        group.each {|t| processor.process(t)}
      end
    end
    return nil
  end

  def self.find_required_tariffs_to_process country
    sql_where = <<sql
    official_tariffs.id in (
    select id from (select official_tariffs.special_rate_key, min(official_tariffs.id) as 'id' from official_tariffs
    left outer join spi_rates on official_tariffs.special_rate_key = spi_rates.special_rate_key and official_tariffs.country_id = spi_rates.country_id
    where official_tariffs.special_rate_key is not null and spi_rates.id is null and official_tariffs.country_id = #{country.id}
    group by official_tariffs.special_rate_key) x)
sql
    country.official_tariffs.where(sql_where)
  end
end; end; end
