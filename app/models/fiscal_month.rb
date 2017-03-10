class FiscalMonth < ActiveRecord::Base
  belongs_to :company
  validates_presence_of :company

  def can_view? user
    user.sys_admin?
  end

  def can_edit? user
    user.sys_admin?
  end

  def fiscal_descriptor
    "#{year}-#{month_number.to_s.rjust(2, "0")}"
  end

  def self.generate_csv company_id
    recs = run_csv_query company_id
    output = CSV.generate do |csv|
      csv << ["Fiscal Year", "Fiscal Month", "Actual Start Date", "Actual End Date"]
      recs.each { |r| csv << r }
    end
    output
  end

  private

  def self.run_csv_query company_id
    qry = <<-SQL
            SELECT year, month_number, start_date, end_date
            FROM fiscal_months
            WHERE company_id = #{company_id}
            ORDER BY year, month_number
          SQL
    ActiveRecord::Base.connection.execute qry
  end
end