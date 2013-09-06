class Attachment < ActiveRecord::Base
  has_attached_file :attached,
    :storage => :fog,
    :fog_credentials => FOG_S3,
    :fog_public => false,
    :fog_directory => 'chain-io',
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
    AWS::S3.new(AWS_CREDENTIALS).buckets[attached.options.fog_directory].objects[attached.path].url_for(:read,:expires=>expires_in,:secure=>true).to_s
  end
  
  #unique name suitable for putting on archive disks
  def unique_file_name
    # Prepend the Document Type (if it exists)
    name = "#{self.id}-#{self.attached_file_name}"
    unless self.attachment_type.blank?
      name = "#{self.attachment_type}-#{name}"
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
      # This encodes to latin1 converting unknown chars along the way to _, then back to UTF-8.
      # The encoding translation is necessitated only because our charsets in the database for the filename are latin1
      # instead of utf8, and converting them to utf8 is a process we don't want to deal with at the moment.
      filename = filename.encode("ISO-8859-1", :replace=>"_", :invalid=>:replace, :undef=>:replace).encode("UTF-8")

      # We also want to underscore'ize invalid windows chars from the filename (in cases where you upload a file from
      # a mac and then try to download on windows - browser can't be relied upon do do this for us at this point).
      character_filter_regex = /[\x00-\x1F\/\\:\*\?\"<>\|]/u
      instance.instance_write(:file_name, filename.gsub(character_filter_regex, "_"))
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
