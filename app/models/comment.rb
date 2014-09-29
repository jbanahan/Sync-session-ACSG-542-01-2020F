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

  def can_view? u
    self.commentable.can_view? u
  end

  def can_edit? u
    self.user == u || u.sys_admin?
  end

  def can_delete? u
    self.user == u || u.sys_admin?
  end

  def publish_comment_create
    OpenChain::EventPublisher.publish :comment_create, self
  end
  private :publish_comment_create
end
