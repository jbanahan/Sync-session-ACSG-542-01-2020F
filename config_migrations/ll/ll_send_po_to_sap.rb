require 'open_chain/custom_handler/lumber_liquidators/lumber_sap_order_xml_generator'
class LLSendPOToSAP
  def self.send order_numbers
    counter = 0
    order_numbers.in_groups_of(300,false) do |nums|
      Order.where('order_number IN (?)',nums) do |ord|
        OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator.send_order ord
        counter += 1
        pp "#{counter} orders sent." if counter % 100 == 0
      end
    end
  end
end
