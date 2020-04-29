# == Schema Information
#
# Table name: comments
#
#  body             :text(65535)
#  commentable_id   :integer
#  commentable_type :string(255)
#  created_at       :datetime         not null
#  id               :integer          not null, primary key
#  subject          :string(255)
#  updated_at       :datetime         not null
#  user_id          :integer
#
# Indexes
#
#  index_comments_on_commentable_id_and_commentable_type  (commentable_id,commentable_type)
#

require 'open_chain/event_publisher'
class Comment < ActiveRecord::Base
  attr_accessible :body, :commentable_id, :commentable_type, :subject,
    :user_id, :user, :commentable

  belongs_to :commentable, :polymorphic => true
  belongs_to :user
  validates :commentable, :presence => true
  validates :user, :presence => true

  scope :by_created_at, -> { order(created_at: :desc) }

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

  def comment_json user
    comment = self
    {
      id:self.id, commentable_type:self.commentable_type, commentable_id:self.commentable_id,
        user:{id:self.user.id, full_name:self.user.full_name, email:self.user.email},
        subject:self.subject, body:self.body, created_at:self.created_at,
        permissions: Comment.comment_json_permissions(comment, user)
    }
  end

  def self.comment_json_permissions comment, user
    {can_view: comment.can_view?(user), can_edit: comment.can_edit?(user), can_delete: comment.can_delete?(user)}
  end

  def self.gather obj, since=nil, limit=nil
    gathered = Comment.where(commentable_id: obj).order(updated_at: :desc)
    gathered = gathered.where("updated_at >= ?", since.utc.to_s(:db)) if since
    gathered = gathered.limit(limit) if limit
    gathered.map { |com| "#{com.updated_at.in_time_zone(Time.zone.name).strftime('%m-%d %H:%M')} #{com.subject}: #{com.body}" }.join("\n \n")
  end

  private

    def publish_comment_create
      OpenChain::EventPublisher.publish :comment_create, self
    end

end
