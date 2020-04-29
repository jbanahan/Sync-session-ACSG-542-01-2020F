# == Schema Information
#
# Table name: intacct_checks
#
#  amount                     :decimal(10, 2)
#  bank_cash_gl_account       :string(255)
#  bank_number                :string(255)
#  bill_number                :string(255)
#  broker_file                :string(255)
#  check_date                 :date
#  check_number               :string(255)
#  company                    :string(255)
#  created_at                 :datetime         not null
#  currency                   :string(255)
#  customer_number            :string(255)
#  file_number                :string(255)
#  freight_file               :string(255)
#  gl_account                 :string(255)
#  id                         :integer          not null, primary key
#  intacct_adjustment_key     :string(255)
#  intacct_alliance_export_id :integer
#  intacct_errors             :text(65535)
#  intacct_key                :string(255)
#  intacct_payable_id         :integer
#  intacct_upload_date        :datetime
#  line_of_business           :string(255)
#  location                   :string(255)
#  suffix                     :string(255)
#  updated_at                 :datetime         not null
#  vendor_number              :string(255)
#  vendor_reference           :string(255)
#  voided                     :boolean
#
# Indexes
#
#  index_by_check_unique_identifers                    (file_number,suffix,check_number,check_date,bank_number)
#  index_by_payable_identifiers                        (company,bill_number,vendor_number)
#  index_intacct_checks_on_intacct_alliance_export_id  (intacct_alliance_export_id)
#

class IntacctCheck < ActiveRecord::Base
  attr_accessible :amount, :bank_cash_gl_account, :bank_number, :bill_number,
    :broker_file, :check_date, :check_number, :company, :currency,
    :customer_number, :file_number, :freight_file, :gl_account,
    :intacct_adjustment_key, :intacct_alliance_export_id, :intacct_alliance_export,
    :intacct_errors, :intacct_key, :intacct_payable_id, :intacct_payable,
    :intacct_upload_date, :line_of_business, :location, :suffix, :vendor_number,
    :vendor_reference, :voided

  belongs_to :intacct_alliance_export, inverse_of: :intacct_checks
  belongs_to :intacct_check, inverse_of: :intacct_checks
end
