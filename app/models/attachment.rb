class Attachment < ActiveRecord::Base
  has_attached_file :attached,
    :storage => :fog,
    :fog_credentials => FOG_S3,
    :fog_public => false,
    :fog_directory => 'chain-io',
    :path => "#{MasterSetup.get.uuid}/attachment/:id/:filename"
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

  private
  def no_post
    false
  end
end
