require 'open_chain/custom_handler/fenix_commercial_invoice_spreadsheet_handler'
require 'open_chain/custom_handler/ecellerate_shipment_activity_parser'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_fenix_invoice_handler'
require 'open_chain/custom_handler/j_crew_parts_extract_parser'
require 'open_chain/custom_handler/kewill_isf_manual_parser'
require 'open_chain/custom_handler/lenox/lenox_shipment_status_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_epd_parser'
require 'open_chain/custom_handler/polo_csm_sync_handler'
require 'open_chain/custom_handler/polo/polo_ca_invoice_handler'
require 'open_chain/custom_handler/polo_sap_bom_handler'
require 'open_chain/custom_handler/under_armour/ua_tbd_report_parser'
require 'open_chain/custom_handler/under_armour/ua_style_color_region_parser'
require 'open_chain/custom_handler/under_armour/ua_style_color_factory_parser'
require 'open_chain/custom_handler/ci_load_handler'
require 'open_chain/custom_handler/fisher/fisher_commercial_invoice_spreadsheet_handler'
require 'open_chain/custom_handler/j_crew/j_crew_returns_parser'
require 'open_chain/custom_handler/ascena/ascena_ca_invoice_handler'
require 'open_chain/custom_handler/pvh/pvh_shipment_workflow_parser'
require 'open_chain/custom_handler/advance/advance_parts_upload_parser'
require 'open_chain/custom_handler/advance/advance_po_origin_report_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_product_upload_handler'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_7501_handler'

class CustomFile < ActiveRecord::Base
  has_many :custom_file_records
  has_many :linked_products, :through=> :custom_file_records, :source=> :linked_object, :source_type=> 'Product', :uniq=>true
  has_many :linked_objects, :through => :custom_file_records
  has_many :search_runs
  belongs_to :uploaded_by, :class_name=>'User'
  has_attached_file :attached,
    :path => ":master_setup_uuid/custom_file/:id/:filename" #conditional on MasterSetup to allow migrations to run
  before_create :sanitize
  before_post_process :no_post

  # Delay'able method for ease of backend processing
  def self.process custom_file_id, user_id, parameters = {}
    CustomFile.find(custom_file_id).process User.find(user_id), parameters
  end

  # process the attached file using the appropriate handler
  def process user, parameters = {}
    r = nil
    self.update_attributes(:start_at=>0.seconds.ago)
    begin
      # We need to support passing some parameters here, so rather than refactor every handler to have it support
      # multiple method params, just check if process has an arity greater than one, and pass parameters if so,
      # otherwise, pass just the user
      h = handler
      if h.method(:process).arity > 1
        r = h.process user, parameters
      else
        r = h.process user
      end
      self.update_attributes(:finish_at=>0.seconds.ago,:error_message=>nil)
    rescue => e
      self.update_attributes(:error_at=>0.seconds.ago,:error_message=>e.message)
      raise e
    end
    r
  end

  def can_view? user
    handler.can_view? user
  end

  # get the custom file handler that will process this file based on it's file_type
  def handler
    raise "Cannot get handler if file_type is not set." if self.file_type.blank?
    self.file_type.constantize.new(self)
  end

  # send the updated version of the file
  def email_updated_file current_user, to, cc, subject, body
    OpenMailer.send_s3_file(current_user, to, cc, subject, body, 'chain-io', handler.make_updated_file(current_user), self.attached_file_name).deliver!
  end

  def secure_url(expires_in=10.seconds)
    OpenChain::S3.url_for bucket, attached.path, expires_in, :response_content_disposition=>"attachment; filename=\"#{self.attached_file_name}\""
  end

  def bucket
    attached.options[:bucket]
  end

  def path
    attached.path
  end

  private
  def no_post
    false
  end
  def sanitize
    Attachment.sanitize_filename self, :attached
  end
end
