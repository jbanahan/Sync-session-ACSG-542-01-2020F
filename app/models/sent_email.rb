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
