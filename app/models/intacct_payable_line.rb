# == Schema Information
#
# Table name: intacct_payable_lines
#
#  id                   :integer          not null, primary key
#  intacct_payable_id   :integer
#  gl_account           :string(255)
#  amount               :decimal(10, 2)
#  customer_number      :string(255)
#  charge_code          :string(255)
#  charge_description   :string(255)
#  location             :string(255)
#  line_of_business     :string(255)
#  freight_file         :string(255)
#  broker_file          :string(255)
#  check_number         :string(255)
#  bank_number          :string(255)
#  check_date           :date
#  bank_cash_gl_account :string(255)
#
# Indexes
#
#  index_intacct_payable_lines_on_intacct_payable_id  (intacct_payable_id)
#

class IntacctPayableLine < ActiveRecord::Base
  belongs_to :intacct_payable, :inverse_of => :intacct_payable_lines
end
