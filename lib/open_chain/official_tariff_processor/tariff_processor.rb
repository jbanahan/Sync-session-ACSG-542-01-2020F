require 'open_chain/official_tariff_processor/tariff_processor_registry'
module OpenChain; module OfficialTariffProcessor; class TariffProcessor
  def self.process_country country
    # this transaction is not just for integrity, it also helps with performance
    #  because it means there's only one commit run instead of a commit on every row
    ActiveRecord::Base.transaction do
      processor = OpenChain::OfficialTariffProcessor::TariffProcessorRegistry.get country
      return nil unless processor
      find_required_tariffs_to_process(country).each {|t| processor.process(t)}
    end
    return nil
  end

  def self.find_required_tariffs_to_process country
    sql_where = <<sql
    official_tariffs.id in (
    select id from (select official_tariffs.special_rate_key, min(official_tariffs.id) as 'id' from official_tariffs
    left outer join spi_rates on official_tariffs.special_rate_key = spi_rates.special_rate_key and official_tariffs.country_id = spi_rates.country_id
    where official_tariffs.country_id = #{country.id} and official_tariffs.special_rate_key is not null and spi_rates.id is null
    group by official_tariffs.special_rate_key) x)
sql
    OfficialTariff.where(sql_where)
  end
  private_class_method :find_required_tariffs_to_process
end; end; end
