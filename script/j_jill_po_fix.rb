require 'open_chain/custom_handler/j_jill/j_jill_850_xml_parser'

class JJillPOFix
  def self.go
    imp = Company.find_by_system_code('JJILL')
    p = OpenChain::CustomHandler::JJill::JJill850XmlParser.new
    Order.where(importer_id:imp.id).find_in_batches do |orders|
      orders.each do |o|
        fp = p.generate_order_fingerprint o
        DataCrossReference.create_jjill_order_fingerprint!(o,fp)
      end
    end
  end
end
