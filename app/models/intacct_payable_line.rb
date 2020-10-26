# == Schema Information
#
# Table name: intacct_payable_lines
#
#  amount               :decimal(12, 2)
#  bank_cash_gl_account :string(255)
#  bank_number          :string(255)
#  broker_file          :string(255)
#  charge_code          :string(255)
#  charge_description   :string(255)
#  check_date           :date
#  check_number         :string(255)
#  customer_number      :string(255)
#  freight_file         :string(255)
#  gl_account           :string(255)
#  id                   :integer          not null, primary key
#  intacct_payable_id   :integer
#  line_of_business     :string(255)
#  location             :string(255)
#
# Indexes
#
#  index_intacct_payable_lines_on_intacct_payable_id  (intacct_payable_id)
#

class IntacctPayableLine < ActiveRecord::Base

  belongs_to :intacct_payable, inverse_of: :intacct_payable_lines
end
