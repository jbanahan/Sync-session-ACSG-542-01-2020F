class Comment < ActiveRecord::Base
  belongs_to :commentable, :polymorphic => true
  belongs_to :user
  validates :commentable, :presence => true
  validates :user, :presence => true

  default_scope :order => 'created_at DESC'

  # translates markdown body to HTML
  def html_body
    RedCloth.new(self.body).to_html.html_safe
  end
end
