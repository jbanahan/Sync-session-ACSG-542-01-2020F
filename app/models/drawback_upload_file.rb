require 'open_chain/under_armour_receiving_parser'
require 'open_chain/ohl_drawback_parser'
require 'open_chain/under_armour_drawback_processor'
require 'open_chain/under_armour_export_parser'
require 'open_chain/custom_handler/j_crew_shipment_parser'

#file uploaded from web to be processed to create drawback data
class DrawbackUploadFile < ActiveRecord::Base
  PROCESSOR_UA_WM_IMPORTS = 'ua_wm_imports'
  PROCESSOR_UA_DDB_EXPORTS = 'ua_ddb_exports'
  PROCESSOR_UA_FMI_EXPORTS = 'ua_fmi_exports'
  PROCESSOR_OHL_ENTRY = 'ohl_entry'
  PROCESSOR_JCREW_SHIPMENTS = 'j_crew_shipments'
  PROCESSOR_LANDS_END_EXPORTS = 'lands_end_exports'
  has_one :attachment, :as=>:attachable

  accepts_nested_attributes_for :attachment, :reject_if => lambda {|q|
    q[:attached].blank?
  }

  #validate the file layout vs. the specification, return array of error messages or empty array
  def validate_layout 
    r = []
    case self.processor
    when PROCESSOR_UA_WM_IMPORTS
      r = OpenChain::UnderArmourReceivingParser.validate_s3 self.attachment.attached.path 
    end
    r
  end
  #process the attached file through the appropriate processor
  def process user
    r = nil
    p_map = {
      PROCESSOR_UA_WM_IMPORTS=>lambda {OpenChain::UnderArmourReceivingParser.parse_s3 self.attachment.attached.path},
      PROCESSOR_OHL_ENTRY => lambda {OpenChain::UnderArmourDrawbackProcessor.process_entries OpenChain::OhlDrawbackParser.parse tempfile.path},
      PROCESSOR_UA_DDB_EXPORTS => lambda {OpenChain::UnderArmourExportParser.parse_csv_file tempfile.path, Company.find_by_importer(true)},
      PROCESSOR_UA_FMI_EXPORTS => lambda {OpenChain::UnderArmourExportParser.parse_fmi_csv_file tempfile.path},
      PROCESSOR_JCREW_SHIPMENTS => lambda {OpenChain::CustomHandler::JCrewShipmentParser.parse_merged_entry_file tempfile.path},
      PROCESSOR_LANDS_END_EXPORTS => lambda {OpenChain::LandsEndExportParser.parse_csv_file tempfile.path, Company.find_by_alliance_customer_number("LANDS")}
    }
    to_run = p_map[self.processor]
    raise "Processor #{self.processor} not found." if to_run.nil?
    begin
      r = to_run.call
      user.messages.create(:subject=>"Drawback File Complete - #{self.attachment.attached_file_name}", :body=>"Your drawback processing job for file #{self.attachment.attached_file_name} is complete.")
    rescue
      self.update_attributes(:error_message=>$!.message)
      $!.log_me ["Drawback Upload File ID: #{self.id}"]
      user.messages.create(:subject=>"Drawback File Complete WITH ERRORS - #{self.attachment.attached_file_name}", :body=>"Your drawback processing job for file #{self.attachment.attached_file_name} is complete.")
    end
    self.update_attributes(:finish_at=>0.seconds.ago)
    r
  end

  private
  def tempfile
    OpenChain::S3.download_to_tempfile OpenChain::S3::BUCKETS[:production], self.attachment.attached.path
  end
end
