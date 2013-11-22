require 'open_chain/google_drive'

class Attachment < ActiveRecord::Base
  has_attached_file :attached,
    :path => "#{MasterSetup.get.uuid}/attachment/:id/:filename"
  before_create :sanitize
  before_post_process :no_post
  
  belongs_to :uploaded_by, :class_name => "User"
  belongs_to :attachable, :polymorphic => true

  has_many :attachment_archives_attachments, :dependent=>:destroy
  has_many :attachment_archives, :through=>:attachment_archives_attachments
  
  def web_preview?
    return !self.attached_content_type.nil? && self.attached_content_type.start_with?("image") && !self.attached_content_type.ends_with?('tiff')
  end
  
  def secure_url(expires_in=10.seconds)
    OpenChain::S3.url_for attached.options[:bucket], attached.path, expires_in
  end
  
  #unique name suitable for putting on archive disks
  def unique_file_name
    # Prepend the Document Type (if it exists)
    name = "#{self.id}-#{self.attached_file_name}"
    unless self.attachment_type.blank?
      name = Attachment.get_sanitized_filename "#{self.attachment_type}-#{name}"
    end
    name
  end

  def self.add_original_filename_method attached_object
    def attached_object.original_filename=(fn); @fn = fn; end
    def attached_object.original_filename; @fn; end
    nil
  end

  def self.sanitize_filename model, paperclip_name
    instance = paperclip_instance model, paperclip_name
    filename = instance.instance_read(:file_name)

    if filename
      instance.instance_write(:file_name, get_sanitized_filename(filename))
    end
  end

  def self.get_sanitized_filename filename
    # This encodes to latin1 converting unknown chars along the way to _, then back to UTF-8.
    # The encoding translation is necessitated only because our charsets in the database for the filename are latin1
    # instead of utf8, and converting them to utf8 is a process we don't want to deal with at the moment.
    filename = filename.encode("ISO-8859-1", :replace=>"_", :invalid=>:replace, :undef=>:replace).encode("UTF-8")

    # We also want to underscore'ize invalid windows chars from the filename (in cases where you upload a file from
    # a mac and then try to download on windows - browser can't be relied upon do do this for us at this point).
    character_filter_regex = /[\x00-\x1F\/\\:\*\?\"<>\|]/u
    filename.gsub(character_filter_regex, "_")
  end

  # Downloads attachment data from S3 and pushes it to the google drive account, path given.
  # drive_folder - if nil, file is placed in root of drive account
  # attachmend_id - the attachment id to push
  # drive_account - if nil, default account is used
  # upload_options - any applicable drive upload options
  def self.push_to_google_drive drive_folder, attachment_id, drive_account = nil, upload_options = {}
    a = Attachment.find attachment_id
    drive_path = File.join((drive_folder ? drive_folder : ""), a.attached_file_name)
    OpenChain::S3.download_to_tempfile(a.attached.options[:bucket], a.attached.path) do |temp|
      OpenChain::GoogleDrive.upload_file drive_account, drive_path, temp, upload_options
    end
  end

  def download_to_tempfile
    if attached
      # Attachments are always in chain-io bucket regardless of environment
      OpenChain::S3.download_to_tempfile('chain-io', attached.path) do |f|
        yield f
      end
    end
  end

  private
    def no_post
      false
    end

    def sanitize
      Attachment.sanitize_filename self, :attached
    end

    def self.paperclip_instance model, paperclip_name
      model.send(paperclip_name)
    end
    private_class_method :paperclip_instance
end
