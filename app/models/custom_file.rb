#
# Table name: custom_files
#
#  attached_content_type :string(255)
#  attached_file_name    :string(255)
#  attached_file_size    :integer
#  attached_updated_at   :datetime
#  created_at            :datetime         not null
#  error_at              :datetime
#  error_message         :string(255)
#  file_type             :string(255)
#  finish_at             :datetime
#  id                    :integer          not null, primary key
#  module_type           :string(255)
#  start_at              :datetime
#  updated_at            :datetime         not null
#  uploaded_by_id        :integer
#
# Indexes
#
#  ftype  (file_type)
#

require 'open_chain/custom_handler/fenix_commercial_invoice_spreadsheet_handler'
require 'open_chain/custom_handler/ecellerate_shipment_activity_parser'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_fenix_invoice_handler'
require 'open_chain/custom_handler/j_crew_parts_extract_parser'
require 'open_chain/custom_handler/lenox/lenox_shipment_status_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_epd_parser'
require 'open_chain/custom_handler/polo_csm_sync_handler'
require 'open_chain/custom_handler/polo/polo_ca_invoice_handler'
require 'open_chain/custom_handler/polo_sap_bom_handler'
require 'open_chain/custom_handler/under_armour/under_armour_missing_classifications_upload_parser'
require 'open_chain/custom_handler/under_armour/ua_tbd_report_parser'
require 'open_chain/custom_handler/under_armour/ua_style_color_region_parser'
require 'open_chain/custom_handler/under_armour/ua_style_color_factory_parser'
require 'open_chain/custom_handler/ci_load_handler'
require 'open_chain/custom_handler/lands_end/le_chapter_98_parser'
require 'open_chain/custom_handler/fisher/fisher_commercial_invoice_spreadsheet_handler'
require 'open_chain/custom_handler/j_crew/j_crew_returns_parser'
require 'open_chain/custom_handler/ascena/ascena_ca_invoice_handler'
require 'open_chain/custom_handler/pvh/pvh_shipment_workflow_parser'
require 'open_chain/custom_handler/advance/advance_parts_upload_parser'
require 'open_chain/custom_handler/advance/advance_po_origin_report_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_product_upload_handler'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_7501_handler'
require 'open_chain/custom_handler/hm/hm_po_line_parser'
require 'open_chain/custom_handler/kirklands/kirklands_product_upload_parser'
require 'open_chain/data_cross_reference_uploader'
require 'open_chain/special_tariff_cross_reference_handler'
require 'open_chain/business_rules_copier'
require 'open_chain/custom_handler/lands_end/le_product_parser'
require 'open_chain/custom_handler/burlington/burlington_product_parser'

class CustomFile < ActiveRecord::Base
  has_many :custom_file_records
  has_many :linked_products, -> { uniq }, through: :custom_file_records, source: :linked_object, source_type: 'Product'
  has_many :linked_objects, through: :custom_file_records
  has_many :search_runs
  belongs_to :uploaded_by, class_name: 'User'
  has_attached_file :attached, path: ":master_setup_uuid/custom_file/:id/:filename"
  # Paperclip, as of v4, forces you to list all the attachment types you allow to be uploaded.  We don't restrict these
  # at all, so this disables that validation.
  do_not_validate_attachment_file_type :attached
  before_create :sanitize
  before_post_process :no_post

  # Delay'able method for ease of backend processing
  def self.process custom_file_id, user_id, parameters = {}
    CustomFile.find(custom_file_id).process User.find(user_id), parameters
  end

  # process the attached file using the appropriate handler
  def process user, parameters = {}
    result = nil
    self.update!(start_at: Time.zone.now)
    parser = nil
    begin
      # We need to support passing some parameters here, so rather than refactor every handler to have it support
      # multiple method params, just check if process has an arity greater than one, and pass parameters if so,
      # otherwise, pass just the user
      parser = handler
      if parser.method(:process).arity > 1
        result = parser.process user, parameters
      else
        result = parser.process user
      end
      self.update!(finish_at: Time.zone.now, error_message: nil, error_at: nil)
    rescue StandardError => e
      handle_errors(parser, user, e)
    end
    result
  end

  def handle_errors handler, user, e
    if handler&.respond_to?(:handle_uncaught_error)
      handler.handle_uncaught_error(user, e)
    else
      # The default means of handling an uncaught error is to log it and re-raise and let
      # the job queue potentially work out the error later (assuming it's a transient error
      # that caused the problem)
      self.update!(error_at: Time.zone.now, error_message: e.message)
      raise e
    end
  end

  delegate :can_view?, to: :handler

  # get the custom file handler that will process this file based on it's file_type
  def handler
    raise "Cannot get handler if file_type is not set." if self.file_type.blank?
    self.file_type.constantize.new(self)
  end

  # send the updated version of the file
  def email_updated_file current_user, to, cc, subject, body
    OpenMailer.send_s3_file(current_user, to, cc, subject, body, 'chain-io', handler.make_updated_file(current_user), self.attached_file_name).deliver_now
  end

  def secure_url(expires_in = 10.seconds)
    OpenChain::S3.url_for bucket, attached.path, expires_in, response_content_disposition: "attachment; filename=\"#{self.attached_file_name}\""
  end

  def bucket
    attached.options[:bucket]
  end

  delegate :path, to: :attached

  def self.purge reference_date
    CustomFile.where("created_at < ?", reference_date).find_each(&:destroy)
  end

  private

  def no_post
    false
  end

  def sanitize
    Attachment.sanitize_filename self, :attached
  end

end
