require 'open_chain/custom_handler/hm/hm_shipment_parser'
module OpenChain; class EmailProcessor
  def initialize email
    @email = email
  end

  def process
    # each method called here should return true if it handled the email and wants the 
    # processing to stop.
    # return false if the email was ignored
    return if process_hm_shipment
  end

  private
  def process_hm_shipment
    found_to_address = @email.to.find {|t| t[:token].downcase=='hm_edi'}
    return false unless found_to_address
    attachment_to_process = @email.attachments.find {|a| a.original_filename.downcase=='vdi_info.lis'}
    return false unless attachment_to_process
    OpenChain::CustomHandler::Hm::HmShipmentParser.parse attachment_to_process.read, User.integration
    true
  end
end; end;