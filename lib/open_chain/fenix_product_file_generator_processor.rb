require 'open_chain/custom_handler/fenix_product_file_generator'

class OpenChain::FenixProductFileGeneratorProcessor

  def run_schedulable opts_hash={}
    ["true",true].include?(opts_hash["use_part_number"]) ? use_part_number = true : use_part_number = false
    fpfg = OpenChain::CustomHandler::FenixProductFileGenerator.new(
      opts_hash["fenix_customer_code"], opts_hash["importer_id"], 
      use_part_number, opts_hash["additional_where"]
      ).generate
  end

end