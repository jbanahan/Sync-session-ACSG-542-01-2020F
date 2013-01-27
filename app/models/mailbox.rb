class Mailbox < ActiveRecord::Base
  attr_accessible :email_aliases, :name
  has_and_belongs_to_many :users
  has_many :emails

  def can_view? user
    user.sys_admin? || !self.users.find_by_id(user.id).nil?
  end

  def can_edit? user
    can_view? user
  end
end
