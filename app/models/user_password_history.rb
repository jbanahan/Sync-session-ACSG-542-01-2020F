# == Schema Information
#
# Table name: user_password_histories
#
#  created_at      :datetime         not null
#  hashed_password :string(255)
#  id              :integer          not null, primary key
#  password_salt   :string(255)
#  updated_at      :datetime         not null
#  user_id         :integer
#
# Indexes
#
#  index_user_password_histories_on_user_id_and_created_at  (user_id,created_at)
#

class UserPasswordHistory < ActiveRecord::Base
  belongs_to :user

  validates :password_salt, presence: true
  validates :hashed_password, presence: true
  validates :user_id, presence: true
end
