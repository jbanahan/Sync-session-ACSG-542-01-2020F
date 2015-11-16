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

  def comment_json user
    h = {id:self.id,commentable_type:self.commentable_type,commentable_id:self.commentable_id,
        user:{id:self.user.id,full_name:self.user.full_name,email:self.user.email},
        subject:self.subject,body:self.body,created_at:self.created_at,permissions: {
          can_view:self.can_view?(user), can_edit:self.can_edit?(user), can_delete:self.can_delete?(user)
        }
      }
    h
  end
end
