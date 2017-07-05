require 'open_chain/custom_handler/under_armour/ua_sites_product_generator'
require 'open_chain/custom_handler/under_armour/ua_subs_product_generator'
require 'open_chain/custom_handler/under_armour/under_armour_missing_classifications_upload_parser'

module OpenChain; module CustomHandler; module UnderArmour; class UaSitesSubsProductGenerator
  def self.can_view? user
    OpenChain::CustomHandler::UnderArmour::UnderArmourMissingClassificationsUploadParser.new("").can_view? user
  end

  def self.run_and_email user, addresses
    sites_report = assign_filename user, "sites", OpenChain::CustomHandler::UnderArmour::UaSitesProductGenerator.process
    subs_report = assign_filename user, "subs", OpenChain::CustomHandler::UnderArmour::UaSubsProductGenerator.process
    OpenMailer.send_simple_html(addresses, "Sites and Subs reports", "Sites and Subs reports attached (unless empty).", [sites_report, subs_report].compact).deliver!
  end

  def self.assign_filename user, type, tempfile
    unless tempfile.nil?
      Attachment.add_original_filename_method tempfile
      tempfile.original_filename = "#{type}_report_#{Time.zone.now.in_time_zone(user.time_zone).strftime('%Y-%m-%d')}.csv"
      tempfile
    end
  end
end; end; end; end;