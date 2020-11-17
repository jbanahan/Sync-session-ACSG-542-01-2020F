# == Schema Information
#
# Table name: announcements
#
#  category   :string(255)
#  comments   :text(65535)
#  created_at :datetime         not null
#  end_at     :datetime
#  id         :integer          not null, primary key
#  start_at   :datetime
#  text       :text(16777215)
#  title      :string(255)
#  updated_at :datetime         not null
#

class Announcement < ActiveRecord::Base
  has_many :marked_users, through: :user_announcement_markers, source: :user
  has_many :user_announcement_markers, dependent: :destroy
  has_and_belongs_to_many :selected_users, join_table: "user_announcements", class_name: "User" # rubocop:disable Rails/HasAndBelongsToMany

  validates :title, presence: true
  validates :start_at, presence: true
  validates :end_at, presence: true
  validates :text, length: {maximum: 1_333_500} # approx. 1 MB
  validate :date_range

  def hide_from_user user_id
    uam = self.user_announcement_markers.where(user_id: user_id).first_or_initialize
    uam.update! hidden: true
  end

  private

  def date_range
    if (start_at && end_at) && (start_at >= end_at)
      errors.add(:base, "The end date must be after the start date.")
    end
  end

end
