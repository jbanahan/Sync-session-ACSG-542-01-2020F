class Message < ActiveRecord::Base
  belongs_to  :user
  
  validates   :user, :presence => true

  #purge messages older than the give date (defaults to 30 days ago)
  def self.purge_messages older_than=30.days.ago
    Message.where("created_at < ?",older_than).destroy_all
  end
end
