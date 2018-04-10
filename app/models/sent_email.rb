# == Schema Information
#
# Table name: sent_emails
#
#  created_at     :datetime         not null
#  email_bcc      :string(255)
#  email_body     :text
#  email_cc       :string(255)
#  email_date     :datetime
#  email_from     :string(255)
#  email_reply_to :string(255)
#  email_subject  :string(255)
#  email_to       :string(255)
#  id             :integer          not null, primary key
#  updated_at     :datetime         not null
#

class SentEmail < ActiveRecord::Base
  has_many :attachments, :as=>:attachable, :dependent=>:destroy

  def can_view? user
    user.admin?
  end

  def self.find_can_view user
    if user.admin?
      SentEmail.scoped
    end
  end

  def self.purge reference_date
    SentEmail.where("created_at < ?", reference_date).find_each do |email|
      email.destroy
    end
  end
end
