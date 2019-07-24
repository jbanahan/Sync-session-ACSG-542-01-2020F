# == Schema Information
#
# Table name: calendar_events
#
#  calendar_id :integer
#  created_at  :datetime
#  event_date  :date
#  id          :integer          not null, primary key
#  label       :string(255)
#  updated_at  :datetime
#

class CalendarEvent < ActiveRecord::Base
  attr_accessible :calendar_id, :event_date, :label

  validates_presence_of :event_date, :calendar_id
  belongs_to :calendar, :inverse_of => :calendar_events
end
