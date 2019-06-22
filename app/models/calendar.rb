# == Schema Information
#
# Table name: calendars
#
#  calendar_type :string(255)
#  company_id    :integer
#  created_at    :datetime         not null
#  id            :integer          not null, primary key
#  updated_at    :datetime         not null
#  year          :integer
#

class Calendar < ActiveRecord::Base
  attr_accessible :calendar_type, :year, :company_id

  validates_presence_of :calendar_type, :year
  has_many :calendar_events, dependent: :destroy, autosave: true, inverse_of: :calendar

  belongs_to :company, inverse_of: :calendars

  def self.find_all_events_in_calendar_month year, month, calendar_type, company_id: nil
    query = CalendarEvent.where('extract(month from event_date) = ?', month).where('extract(year from event_date) = ?', year)
      .joins(:calendar).where('year = ?', year).where('calendar_type = ?', calendar_type)

    if company_id.present?
      query = query.where(calendars: {company_id: company_id})
    else
      query = query.where("calendars.company_id IS NULL")
    end

    query
  end

end
