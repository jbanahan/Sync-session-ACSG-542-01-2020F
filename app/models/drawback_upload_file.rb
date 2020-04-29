# == Schema Information
#
# Table name: drawback_upload_files
#
#  created_at    :datetime         not null
#  error_message :string(255)
#  finish_at     :datetime
#  id            :integer          not null, primary key
#  processor     :string(255)
#  start_at      :datetime
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_drawback_upload_files_on_processor  (processor)
#

require 'open_chain/custom_handler/under_armour/under_armour_receiving_parser'
require 'open_chain/ohl_drawback_parser'
require 'open_chain/custom_handler/under_armour/under_armour_drawback_processor'
require 'open_chain/custom_handler/under_armour/under_armour_export_parser'
require 'open_chain/custom_handler/under_armour/under_armour_sto_export_parser'
require 'open_chain/custom_handler/under_armour/under_armour_sto_export_v2_parser'
require 'open_chain/custom_handler/j_crew/j_crew_drawback_export_parser'
require 'open_chain/custom_handler/j_crew/j_crew_borderfree_drawback_export_parser'
require 'open_chain/custom_handler/j_crew/j_crew_drawback_import_processor_v2'
require 'open_chain/lands_end_export_parser'
require 'open_chain/custom_handler/lands_end/le_drawback_import_parser'
require 'open_chain/custom_handler/lands_end/le_drawback_cd_parser'
require 'open_chain/custom_handler/crocs/crocs_drawback_export_parser'
require 'open_chain/custom_handler/crocs/crocs_drawback_processor'
require 'open_chain/custom_handler/crocs/crocs_receiving_parser'

# file uploaded from web to be processed to create drawback data
class DrawbackUploadFile < ActiveRecord::Base
  attr_accessible :error_message, :finish_at, :processor, :start_at, :attachment, :attachments_attributes

  PROCESSOR_UA_WM_IMPORTS ||= 'ua_wm_imports'
  PROCESSOR_UA_DDB_EXPORTS ||= 'ua_ddb_exports'
  PROCESSOR_UA_FMI_EXPORTS ||= 'ua_fmi_exports'
  PROCESSOR_UA_STO_EXPORTS ||= 'ua_sto_exports'
  PROCESSOR_UA_STO_EXPORTS_V2 ||= 'ua_sto_exports_v2'
  PROCESSOR_OHL_ENTRY ||= 'ohl_entry'
  PROCESSOR_JCREW_BORDERFREE ||= 'j_crew_borderfree'
  PROCESSOR_JCREW_CANADA_EXPORTS ||= 'j_crew_canada'
  PROCESSOR_JCREW_IMPORT_V2 ||= 'j_crew_import_v2'
  PROCESSOR_LANDS_END_EXPORTS ||= 'lands_end_exports'
  PROCESSOR_LANDS_END_IMPORTS ||= 'lands_end_imports'
  PROCESSOR_LANDS_END_CD ||= 'lands_end_cd'
  PROCESSOR_CROCS_EXPORTS ||= 'crocs_exports'
  PROCESSOR_CROCS_RECEIVING ||= 'crocs_receiving'
  has_one :attachment, :as=>:attachable

  accepts_nested_attributes_for :attachment, :reject_if => lambda {|q|
    q[:attached].blank?
  }

  # validate the file layout vs. the specification, return array of error messages or empty array
  def validate_layout
    r = []
    case self.processor
    when PROCESSOR_UA_WM_IMPORTS
      r = OpenChain::CustomHandler::UnderArmour::UnderArmourReceivingParser.validate_s3 self.attachment.attached.path
    end
    r
  end
  # process the attached file through the appropriate processor
  def process user
    r = nil
    p_map = {
      PROCESSOR_UA_WM_IMPORTS=>lambda {OpenChain::CustomHandler::UnderArmour::UnderArmourReceivingParser.parse_s3 self.attachment.attached.path},
      PROCESSOR_OHL_ENTRY => lambda {
        OpenChain::OhlDrawbackParser.parse tempfile.path
        OpenChain::CustomHandler::UnderArmour::UnderArmourDrawbackProcessor.process_entries Entry.where("arrival_date > ?", 90.days.ago)
      },
      # This should only run on UnderArmour's instance, so the master company is what we want to link to
      PROCESSOR_UA_DDB_EXPORTS => lambda {OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser.parse_csv_file tempfile.path, Company.where(master: true).first },
      PROCESSOR_UA_FMI_EXPORTS => lambda {OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser.parse_fmi_csv_file tempfile.path},
      PROCESSOR_UA_STO_EXPORTS => lambda {OpenChain::CustomHandler::UnderArmour::UnderArmourStoExportParser.parse self.attachment.attached.path},
      PROCESSOR_UA_STO_EXPORTS_V2 => lambda {OpenChain::CustomHandler::UnderArmour::UnderArmourStoExportV2Parser.parse self.attachment.attached.path},
      PROCESSOR_JCREW_BORDERFREE => lambda {OpenChain::CustomHandler::JCrew::JCrewBorderfreeDrawbackExportParser.parse_csv_file tempfile.path, Company.with_customs_management_number("JCREW").first},
      PROCESSOR_JCREW_CANADA_EXPORTS => lambda { OpenChain::CustomHandler::JCrew::JCrewDrawbackExportParser.parse_csv_file tempfile.path, Company.with_customs_management_number("JCREW").first},
      PROCESSOR_JCREW_IMPORT_V2 => lambda { OpenChain::CustomHandler::JCrew::JCrewDrawbackImportProcessorV2.parse_csv_file(tempfile.path, user) },
      PROCESSOR_LANDS_END_EXPORTS => lambda {OpenChain::LandsEndExportParser.parse_csv_file tempfile.path, Company.with_customs_management_number("LANDS").first},
      PROCESSOR_LANDS_END_IMPORTS => lambda {OpenChain::CustomHandler::LandsEnd::LeDrawbackImportParser.new(Company.with_customs_management_number("LANDS").first).parse IO.read tempfile.path},
      PROCESSOR_LANDS_END_CD => lambda {OpenChain::CustomHandler::LandsEnd::LeDrawbackCdParser.new(Company.with_customs_management_number("LANDS").first).parse IO.read tempfile.path},
      PROCESSOR_CROCS_RECEIVING=>lambda {
        start_date, end_date = OpenChain::CustomHandler::Crocs::CrocsReceivingParser.parse_s3 self.attachment.attached.path
        OpenChain::CustomHandler::Crocs::CrocsDrawbackProcessor.process_entries_by_arrival_date start_date, end_date
      },
      PROCESSOR_CROCS_EXPORTS => lambda { OpenChain::CustomHandler::Crocs::CrocsDrawbackExportParser.parse_csv_file tempfile.path, Company.with_customs_management_number("CROCS").first}
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
