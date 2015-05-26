require 'open_chain/s3'

class PowerOfAttorney < ActiveRecord::Base
  belongs_to :company
  belongs_to :user, :foreign_key => :uploaded_by, :class_name => "User"

  has_attached_file :attachment, :path => ":master_setup_uuid/power_of_attorney/:id/:filename"

  validates_attachment_presence :attachment
  validates :user, :presence => true
  validates :company, :presence => true
  validates :start_date, :presence => true
  validates :expiration_date, :presence => true

  def attachment_data
    OpenChain::S3.get_data attachment.options[:bucket], attachment.path
  end
end
