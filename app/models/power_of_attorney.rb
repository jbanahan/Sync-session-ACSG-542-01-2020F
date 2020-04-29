# == Schema Information
#
# Table name: power_of_attorneys
#
#  attachment_content_type :string(255)
#  attachment_file_name    :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  company_id              :integer
#  created_at              :datetime         not null
#  expiration_date         :date
#  id                      :integer          not null, primary key
#  start_date              :date
#  updated_at              :datetime         not null
#  uploaded_by             :integer
#

require 'open_chain/s3'

class PowerOfAttorney < ActiveRecord::Base
  attr_accessible :attachment, :attachment_content_type, :attachment_file_name, :attachment_file_size, :attachment_updated_at, :company_id, :expiration_date, :start_date, :uploaded_by

  belongs_to :company
  belongs_to :user, :foreign_key => :uploaded_by, :class_name => "User"

  has_attached_file :attachment, :path => ":master_setup_uuid/power_of_attorney/:id/:filename"
  # Paperclip, as of v4, forces you to list all the attachment types you allow to be uploaded.  We don't restrict these
  # at all, so this disables that validation.
  do_not_validate_attachment_file_type :attachment

  validates_attachment_presence :attachment
  validates :user, :presence => true
  validates :company, :presence => true
  validates :start_date, :presence => true
  validates :expiration_date, :presence => true

  def attachment_data
    OpenChain::S3.get_data attachment.options[:bucket], attachment.path
  end
end
