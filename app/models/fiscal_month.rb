# == Schema Information
#
# Table name: fiscal_months
#
#  id           :integer          not null, primary key
#  year         :integer
#  month_number :integer
#  start_date   :date
#  end_date     :date
#  company_id   :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_fiscal_months_on_start_date_and_end_date  (start_date,end_date)
#

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

  def self.get company_or_id, date
    co_id = company_or_id.kind_of?(Integer) ? company_or_id : company_or_id.id
    where("company_id = #{co_id} AND start_date <= '#{date}' AND end_date >= '#{date}'").first
  end

  def self.generate_csv company_id
    recs = run_csv_query company_id
    CSV.generate do |csv|
      csv << ["Fiscal Year", "Fiscal Month", "Actual Start Date", "Actual End Date"]
      recs.each { |r| csv << r }
    end
  end

  def forward n_months
    year_adj, mod = ((month_number - 1) + n_months).divmod 12
    new_month_num = mod + 1
    FiscalMonth.where(company_id: company.id, month_number: new_month_num, year: year + year_adj).first
  end

  def back n_months
    forward(n_months * -1)
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
