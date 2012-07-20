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
  
  def web_preview?
    return !self.attached_content_type.nil? && self.attached_content_type.start_with?("image") && !self.attached_content_type.ends_with?('tiff')
  end
  
  def secure_url(expires_in=10.seconds)
    AWS::S3.new(AWS_CREDENTIALS).buckets[attached.options.fog_directory].objects[attached.path].url_for(:read,:expires=>expires_in,:secure=>true).to_s
  end
  
  private
  def no_post
    false
  end
end
