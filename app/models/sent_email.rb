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

end
