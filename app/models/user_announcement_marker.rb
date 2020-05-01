# == Schema Information
#
# Table name: user_announcement_markers
#
#  announcement_id :integer
#  confirmed_at    :datetime
#  created_at      :datetime
#  hidden          :boolean
#  id              :integer          not null, primary key
#  updated_at      :datetime
#  user_id         :integer
#
# Indexes
#
#  index_user_announcement_markers_on_user_id_and_announcement_id  (user_id,announcement_id)
#

class UserAnnouncementMarker < ActiveRecord::Base
  belongs_to :user
  belongs_to :announcement
  attr_accessible :confirmed_at, :hidden, :user_id, :announcement_id
end
