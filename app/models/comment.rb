require 'open_chain/event_publisher'
class Comment < ActiveRecord::Base
  belongs_to :commentable, :polymorphic => true
  belongs_to :user
  validates :commentable, :presence => true
  validates :user, :presence => true

  default_scope :order => 'created_at DESC'

  after_create :publish_comment_create

  # translates markdown body to HTML
  def html_body
    RedCloth.new(self.body).to_html.html_safe
  end

  def publish_comment_create
    OpenChain::EventPublisher.publish "#{self.commentable_type.upcase}_COMMENT_CREATE", {comment_id:self.id,commentable_type:self.commentable_type,commentable_id:self.commentable_id,user_id:self.user_id,created_at:self.created_at,body:self.body,subject:self.subject}
  end
  private :publish_comment_create
end
