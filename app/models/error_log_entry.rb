# == Schema Information
#
# Table name: error_log_entries
#
#  additional_messages_json :text
#  backtrace_json           :text
#  created_at               :datetime         not null
#  error_message            :text
#  exception_class          :string(255)
#  id                       :integer          not null, primary key
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_error_log_entries_on_created_at  (created_at)
#

class ErrorLogEntry < ActiveRecord::Base

  def self.create_from_exception exception, additional_messages=[]
    bj = exception.backtrace.to_json
    am = additional_messages.nil? ? [].to_json : additional_messages.to_json
    ErrorLogEntry.create(:exception_class=>exception.class.to_s,:error_message=>exception.message,:backtrace_json=>bj,:additional_messages_json=>am) 
  end

  def backtrace
    self.backtrace_json.blank? ? nil : ActiveSupport::JSON.decode(self.backtrace_json)
  end

  def additional_messages
    self.additional_messages_json.blank? ? nil : ActiveSupport::JSON.decode(self.additional_messages_json)
  end

  def email_me?
    ErrorLogEntry.where(:exception_class=>self.exception_class,:error_message=>self.error_message).where("created_at > ?",1.minute.ago).where(self.id ? "NOT id = #{self.id}" : "1=1").first.blank?
  end

  def self.purge reference_date
    ErrorLogEntry.where("created_at < ?", reference_date).delete_all
  end
end
