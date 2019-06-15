# == Schema Information
#
# Table name: sent_emails
#
#  created_at     :datetime         not null
#  delivery_error :text
#  email_bcc      :string(255)
#  email_body     :text
#  email_cc       :string(255)
#  email_date     :datetime
#  email_from     :string(255)
#  email_reply_to :string(255)
#  email_subject  :string(255)
#  email_to       :string(255)
#  id             :integer          not null, primary key
#  suppressed     :boolean          default(FALSE)
#  updated_at     :datetime         not null
#

class SentEmail < ActiveRecord::Base
  attr_accessible :delivery_error, :email_bcc, :email_body, :email_cc, 
    :email_date, :email_from, :email_reply_to, :email_subject, :email_to, 
    :suppressed, :attachments
  
  has_many :attachments, :as=>:attachable, :dependent=>:destroy

  def can_view? user
    user.admin?
  end

  def self.find_can_view user
    if user.admin?
      SentEmail.all
    end
  end

  def self.purge reference_date
    SentEmail.where("created_at < ?", reference_date).find_each do |email|
      email.destroy
    end
  end
end
