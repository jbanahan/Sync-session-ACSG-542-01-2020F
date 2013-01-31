class Mailbox < ActiveRecord::Base
  attr_accessible :email_aliases, :name
  has_and_belongs_to_many :users
  has_many :emails
  
  #get hash of each user with an email assigned and the number of emails
  #the key is the user object and the value is the assignment count
  def assignment_breakdown archived
    h = (archived ? self.emails.archived : self.emails.not_archived).count(:group=>:assigned_to_id)
    r = {}
    users = User.where("id IN (?)",h.keys.compact)
    uh = {}
    users.each {|u| uh[u.id]=u}
    h.each do |k,v|
      if k.nil?
        r[nil] = v
      else
        r[uh[k]] = v
      end
    end
    r
  end

  def can_view? user
    user.sys_admin? || !self.users.find_by_id(user.id).nil?
  end

  def can_edit? user
    can_view? user
  end
end
