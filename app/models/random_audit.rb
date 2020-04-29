# == Schema Information
#
# Table name: random_audits
#
#  attached_content_type :string(255)
#  attached_file_name    :string(255)
#  attached_file_size    :integer
#  attached_updated_at   :datetime
#  created_at            :datetime         not null
#  id                    :integer          not null, primary key
#  module_type           :string(255)
#  report_date           :datetime
#  report_name           :string(255)
#  search_setup_id       :integer
#  updated_at            :datetime         not null
#  user_id               :integer
#

class RandomAudit < ActiveRecord::Base
  attr_accessible :attached_content_type, :attached_file_name, :attached,
    :attached_file_size, :attached_updated_at, :module_type, :report_date,
    :report_name, :search_setup_id, :search_setup, :user_id, :user

  has_attached_file :attached, :path => ":master_setup_uuid/random_audit/:id/:filename"
  # Paperclip, as of v4, forces you to list all the attachment types you allow to be uploaded.  We don't restrict these
  # at all, so this disables that validation.
  do_not_validate_attachment_file_type :attached
  before_post_process :no_post

  belongs_to :user
  belongs_to :search_setup

  def can_view? u
    u == self.user
  end

  def secure_url(expires_in=10.seconds)
    OpenChain::S3.url_for bucket, attached.path, expires_in, :response_content_disposition=>"attachment; filename=\"#{self.attached_file_name}\""
  end

  def bucket
    attached.options[:bucket]
  end

  def path
    attached.path
  end

  private

  def no_post
    false
  end

end
