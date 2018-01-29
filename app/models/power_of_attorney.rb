# == Schema Information
#
# Table name: power_of_attorneys
#
#  id                      :integer          not null, primary key
#  company_id              :integer
#  start_date              :date
#  expiration_date         :date
#  uploaded_by             :integer
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#

require 'open_chain/s3'

class PowerOfAttorney < ActiveRecord::Base
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
