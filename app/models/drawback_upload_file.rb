require 'open_chain/under_armour_receiving_parser'
require 'open_chain/ohl_drawback_parser'
require 'open_chain/under_armour_drawback_processor'
require 'open_chain/under_armour_export_parser'

#file uploaded from web to be processed to create drawback data
class DrawbackUploadFile < ActiveRecord::Base
  PROCESSOR_UA_WM_IMPORTS = 'ua_wm_imports'
  PROCESSOR_UA_DDB_EXPORTS = 'ua_ddb_exports'
  PROCESSOR_UA_FMI_EXPORTS = 'ua_fmi_exports'
  PROCESSOR_OHL_ENTRY = 'ohl_entry'
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
    case self.processor
    when PROCESSOR_UA_WM_IMPORTS
      r = OpenChain::UnderArmourReceivingParser.parse_s3 self.attachment.attached.path 
    when PROCESSOR_OHL_ENTRY
      r = OpenChain::UnderArmourDrawbackProcessor.process_entries OpenChain::OhlDrawbackParser.parse tempfile.path
    when PROCESSOR_UA_DDB_EXPORTS
      r = OpenChain::UnderArmourExportParser.parse_csv_file tempfile.path
    when PROCESSOR_UA_FMI_EXPORTS
      r = OpenChain::UnderArmourExportParser.parse_fmi_csv_file tempfile.path
    else
      raise "Processor #{self.processor} not found."
    end
    self.update_attributes(:finish_at=>0.seconds.ago)
    user.messages.create(:subject=>"Drawback File Complete - #{self.attachment.attached_file_name}", :body=>"Your drawback processing job for file #{self.attachment.attached_file_name} is complete.")
    r
  end

  private
  def tempfile
    OpenChain::S3.download_to_tempfile OpenChain::S3::BUCKETS[:production], self.attachment.attached.path
  end
end
