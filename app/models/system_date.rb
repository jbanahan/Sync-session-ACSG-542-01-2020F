# == Schema Information
#
# Table name: system_dates
#
#  company_id :integer
#  created_at :datetime
#  date_type  :string(255)      not null
#  end_date   :datetime
#  id         :integer          not null, primary key
#  start_date :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_system_dates_on_date_type_and_company_id  (date_type,company_id) UNIQUE
#

class SystemDate < ActiveRecord::Base
  attr_accessible :date_type, :company_id, :start_date, :end_date

  belongs_to :company, inverse_of: :system_dates

  validates :date_type, presence: true

  def self.find_start_date date_type, company = nil, default_date: nil
    find_boundary_date date_type, company, :start_date, default_date
  end

  def self.find_end_date date_type, company = nil, default_date: nil
    find_boundary_date date_type, company, :end_date, default_date
  end

  class << self
    private

      def find_boundary_date date_type, company, date_field, default_date
        # Allow passing an integer value or the actual Company object.
        company_id = nil
        if company
          company_id = company.respond_to?(:id) ? company.id : company
        end

        d = SystemDate.where(date_type: date_type, company_id: company_id).pluck(date_field).first
        if d.nil? && default_date
          d = default_date
        end
        d
      end
  end

end
