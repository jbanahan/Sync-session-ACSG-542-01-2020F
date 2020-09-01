# == Schema Information
#
# Table name: api_sessions
#
#  class_name           :string(255)
#  created_at           :datetime         not null
#  endpoint             :string(255)
#  id                   :integer          not null, primary key
#  last_server_response :string(255)
#  request_file_name    :string(255)
#  retry_count          :integer
#  updated_at           :datetime         not null
#

class ApiSession < ActiveRecord::Base
  attr_accessible :class_name, :endpoint, :last_server_response, :response_file_name, :retry_count

  has_many :attachments, as: :attachable, dependent: :destroy, autosave: true # rubocop:disable Rails/InverseOf

  def self.find_can_view(user)
    ApiSession.where("1=1") if user.sys_admin?
  end

  def can_view? user
    user.sys_admin?
  end

  # Always set the request_file here to ensure the file names are in sync. Don't forget to save
  def request_file=(att)
    raise "Attachment is of the wrong type!" if att.attachment_type&.downcase != "request"
    self.request_file_name = att.attached_file_name
    attachments << att
  end

  def request_file
    attachments.find { |att| att.attachment_type.downcase == "request" }
  end

  def response_files
    attachments.select { |att| att.attachment_type.downcase == "response" }.sort_by(&:created_at)
  end

  def successful
    return nil unless last_server_response
    last_server_response.downcase == "ok" ? "Y" : "N"
  end

  def short_class_name
    class_name.split("::").last
  end

  def self.purge reference_date
    ApiSession.where("created_at < ?", reference_date).find_each(&:destroy)
  end
end
