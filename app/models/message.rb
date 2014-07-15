class Message < ActiveRecord::Base
  belongs_to  :user
  
  validates   :user, :presence => true

  after_create :email_to_user
  
  #purge messages older than the give date (defaults to 30 days ago)
  def self.purge_messages older_than=30.days.ago
    Message.where("created_at < ?",older_than).destroy_all
  end

  # Emails message to user is user has checked corresponding option
  # on the messages index page
  def email_to_user
    if user.email_new_messages
      OpenMailer.delay.send_message(self)
    end
  end

  # efficent method to get unread message count with just a user_id
  def self.unread_message_count user_id
    Message.where(:user_id=>user_id).where("viewed is null OR viewed = ?",false).count
  end

  def self.run_schedulable
    purge_messages
  end
end
