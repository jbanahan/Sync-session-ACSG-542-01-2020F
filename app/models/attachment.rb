class Attachment < ActiveRecord::Base
  has_attached_file :attached,
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
    OpenChain::S3.url_for attached.options[:bucket], attached.path, expires_in
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
