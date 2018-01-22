# == Schema Information
#
# Table name: daily_statement_entries
#
#  id                          :integer          not null, primary key
#  daily_statement_id          :integer
#  broker_reference            :string(255)
#  entry_id                    :integer
#  port_code                   :string(255)
#  duty_amount                 :decimal(11, 2)
#  preliminary_duty_amount     :decimal(11, 2)
#  tax_amount                  :decimal(11, 2)
#  preliminary_tax_amount      :decimal(11, 2)
#  cvd_amount                  :decimal(11, 2)
#  preliminary_cvd_amount      :decimal(11, 2)
#  add_amount                  :decimal(11, 2)
#  preliminary_add_amount      :decimal(11, 2)
#  fee_amount                  :decimal(11, 2)
#  preliminary_fee_amount      :decimal(11, 2)
#  interest_amount             :decimal(11, 2)
#  preliminary_interest_amount :decimal(11, 2)
#  total_amount                :decimal(11, 2)
#  preliminary_total_amount    :decimal(11, 2)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  billed_amount               :decimal(11, 2)
#
# Indexes
#
#  index_daily_statement_entries_on_broker_reference    (broker_reference)
#  index_daily_statement_entries_on_daily_statement_id  (daily_statement_id)
#  index_daily_statement_entries_on_entry_id            (entry_id)
#

class DailyStatementEntry < ActiveRecord::Base

  belongs_to :daily_statement, inverse_of: :daily_statement_entries
  has_many :daily_statement_entry_fees, dependent: :destroy, autosave: true, inverse_of: :daily_statement_entry
  belongs_to :port, class_name: "Port", foreign_key: "port_code", primary_key: "schedule_d_code"
  belongs_to :entry, inverse_of: :daily_statement_entry

end
