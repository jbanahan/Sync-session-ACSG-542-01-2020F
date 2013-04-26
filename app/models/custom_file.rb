require 'open_chain/custom_handler/polo_msl_plus_handler'
require 'open_chain/custom_handler/polo_csm_sync_handler'
require 'open_chain/custom_handler/polo_ca_entry_parser'
require 'open_chain/custom_handler/j_crew_parts_extract_parser'

class CustomFile < ActiveRecord::Base
  has_many :custom_file_records
  has_many :linked_products, :through=> :custom_file_records, :source=> :linked_object, :source_type=> 'Product', :uniq=>true
  has_many :linked_objects, :through => :custom_file_records
  has_many :search_runs
  belongs_to :uploaded_by, :class_name=>'User'
  has_attached_file :attached,
    :storage => :fog,
    :fog_credentials => FOG_S3,
    :fog_public => false,
    :fog_directory => 'chain-io',
    :path => "#{MasterSetup.get.nil? ? "UNKNOWN" : MasterSetup.get.uuid}/custom_file/:id/:filename" #conditional on MasterSetup to allow migrations to run
  before_post_process :no_post

  # process the attached file using the appropriate handler
  def process user
    r = nil
    self.update_attributes(:start_at=>0.seconds.ago)
    begin
      r = handler.process user
      self.update_attributes(:finish_at=>0.seconds.ago,:error_message=>nil)
    rescue
      self.update_attributes(:error_at=>0.seconds.ago,:error_message=>$!.message)
      raise $!
    end
    r
  end

  def can_view? user
    handler.can_view? user
  end

  # get the custom file handler that will process this file based on it's file_type
  def handler
    raise "Cannot get handler if file_type is not set." if self.file_type.blank?
    if self.file_type.include?(':')
      h = self.file_type.split('::').inject(Kernel) {|scope, const_name| scope.const_get(const_name)} 
      h.new(self)
    else
      Kernel.const_get(self.file_type).new(self)
    end
  end

  # send the updated version of the file
  def email_updated_file current_user, to, cc, subject, body
    OpenMailer.send_s3_file(current_user, to, cc, subject, body, 'chain-io', handler.make_updated_file(current_user), self.attached_file_name).deliver!
  end

  def secure_url(expires_in=10.seconds)
    AWS::S3.new(AWS_CREDENTIALS).buckets[attached.options.fog_directory].objects[attached.path].url_for(:read,:expires=>expires_in,:secure=>true,:response_content_disposition=>"attachment; filename=\"#{self.attached_file_name}\"").to_s
  end
  private
  def no_post
    false
  end
end
