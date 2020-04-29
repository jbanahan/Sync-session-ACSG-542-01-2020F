Dir[__dir__ + '/*'].each {|file| require file } # Require all files in this directory
module OpenChain; module OfficialTariffProcessor; class TariffProcessorRegistry
  REGISTERED ||= {
    'IT'=>OpenChain::OfficialTariffProcessor::GenericProcessor,
    'GB'=>OpenChain::OfficialTariffProcessor::GenericProcessor,
    'FR'=>OpenChain::OfficialTariffProcessor::GenericProcessor,
    'US'=>OpenChain::OfficialTariffProcessor::GenericProcessor,
    'CA'=>OpenChain::OfficialTariffProcessor::GenericProcessor,
    "CL"=>OpenChain::OfficialTariffProcessor::GenericProcessor,
    "CN"=>OpenChain::OfficialTariffProcessor::GenericProcessor,
    "MX"=>OpenChain::OfficialTariffProcessor::GenericProcessor,
    "SG"=>OpenChain::OfficialTariffProcessor::GenericProcessor
  }
  def self.get iso_code_or_country
    iso = iso_code_or_country.respond_to?(:iso_code) ? iso_code_or_country.iso_code : iso_code_or_country
    return nil if iso.blank?
    iso.upcase!
    REGISTERED[iso]
  end
end; end; end
