# == Schema Information
#
# Table name: intacct_checks
#
#  id                         :integer          not null, primary key
#  company                    :string(255)
#  file_number                :string(255)
#  suffix                     :string(255)
#  bill_number                :string(255)
#  customer_number            :string(255)
#  vendor_number              :string(255)
#  check_number               :string(255)
#  check_date                 :date
#  bank_number                :string(255)
#  vendor_reference           :string(255)
#  amount                     :decimal(10, 2)
#  freight_file               :string(255)
#  broker_file                :string(255)
#  location                   :string(255)
#  line_of_business           :string(255)
#  currency                   :string(255)
#  gl_account                 :string(255)
#  bank_cash_gl_account       :string(255)
#  intacct_alliance_export_id :integer
#  intacct_upload_date        :datetime
#  intacct_key                :string(255)
#  intacct_errors             :text
#  intacct_payable_id         :integer
#  intacct_adjustment_key     :string(255)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  voided                     :boolean
#
# Indexes
#
#  index_by_check_unique_identifers                    (file_number,suffix,check_number,check_date,bank_number)
#  index_by_payable_identifiers                        (company,bill_number,vendor_number)
#  index_intacct_checks_on_intacct_alliance_export_id  (intacct_alliance_export_id)
#

class IntacctCheck < ActiveRecord::Base
  belongs_to :intacct_alliance_export, inverse_of: :intacct_checks
  belongs_to :intacct_check, inverse_of: :intacct_checks
end
