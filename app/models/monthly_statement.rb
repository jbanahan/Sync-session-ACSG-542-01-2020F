# == Schema Information
#
# Table name: monthly_statements
#
#  id                          :integer          not null, primary key
#  statement_number            :string(255)
#  status                      :string(255)
#  received_date               :date
#  final_received_date         :date
#  due_date                    :date
#  paid_date                   :date
#  port_code                   :string(255)
#  pay_type                    :string(255)
#  customer_number             :string(255)
#  importer_id                 :integer
#  total_amount                :decimal(11, 2)
#  preliminary_total_amount    :decimal(11, 2)
#  duty_amount                 :decimal(11, 2)
#  preliminary_duty_amount     :decimal(11, 2)
#  tax_amount                  :decimal(11, 2)
#  preliminary_tax_amount      :decimal(11, 2)
#  cvd_amount                  :decimal(11, 2)
#  preliminary_cvd_amount      :decimal(11, 2)
#  add_amount                  :decimal(11, 2)
#  preliminary_add_amount      :decimal(11, 2)
#  interest_amount             :decimal(11, 2)
#  preliminary_interest_amount :decimal(11, 2)
#  fee_amount                  :decimal(11, 2)
#  preliminary_fee_amount      :decimal(11, 2)
#  last_file_bucket            :string(255)
#  last_file_path              :string(255)
#  last_exported_from_source   :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
# Indexes
#
#  index_monthly_statements_on_importer_id       (importer_id)
#  index_monthly_statements_on_statement_number  (statement_number) UNIQUE
#

class MonthlyStatement < ActiveRecord::Base
  include CoreObjectSupport

  has_many :daily_statements, autosave: true, inverse_of: :monthly_statement
  belongs_to :importer, class_name: "Company"
  belongs_to :port, class_name: "Port", foreign_key: "port_code", primary_key: 'schedule_d_code'

  def self.search_secure user, base_object
    base_object.where(DailyStatement.search_where(user))
  end

  def self.search_where user
    return "1=0" unless user.view_statements?

    if user.master_company?
      return "1=1"
    else
      company = user.company
      return "(monthly_statements.importer_id = #{company.id} OR monthly_statements.importer_id IN (select child_id from linked_companies where parent_id = #{company.id}))"
    end
  end

  def can_view? user
    return false unless user.view_statements?

    if self.importer_id.nil?
      return user.master_company?
    else 
      return user.master_company? || user.company.id == self.importer_id || user.company.linked_company?(self.importer)
    end
  end

  def can_edit? user
    false
  end

  def final_statement?
    self.status.to_s.upcase == "F"
  end

  def pay_type_description
    case self.pay_type.to_i
    when 1
      "Direct Payment"
    when 2
      "Broker Daily Statement"
    when 3
      "Importer Daily Statement"
    when 6
      "Broker Monthly Statement"
    when 7
      "Importer Monthly Statement"
    else
      ""
    end
  end

  def status_description
    case self.status.to_s.upcase
    when 'F'
      "Final"
    when "P"
      "Preliminary"
    else
      ""
    end
  end
end
