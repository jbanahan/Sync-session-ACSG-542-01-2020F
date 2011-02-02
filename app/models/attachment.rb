class Attachment < ActiveRecord::Base
  has_attached_file :attached,
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :path => "#{MasterSetup.first.uuid}/attachment/:id/:filename",
    :bucket => 'chain-io'
  before_post_process :no_post
  
  belongs_to :uploaded_by, :class_name => "User"
  belongs_to :attachable, :polymorphic => true
  validates :attachable, :presence => true
  
  def web_preview?
    return !self.attached_content_type.nil? && self.attached_content_type.start_with?("image")
  end
  
  private
  def no_post
    false
  end
end
