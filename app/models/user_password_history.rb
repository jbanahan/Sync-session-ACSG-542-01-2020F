class UserPasswordHistory < ActiveRecord::Base
  belongs_to :user

  validates :password_salt, presence: true
  validates :hashed_password, presence: true
  validates :user_id, presence: true
end