# == Schema Information
#
# Table name: intacct_alliance_exports
#
#  ap_total            :decimal(10, 2)
#  ar_total            :decimal(10, 2)
#  check_number        :string(255)
#  created_at          :datetime         not null
#  customer_number     :string(255)
#  data_received_date  :datetime
#  data_requested_date :datetime
#  division            :string(255)
#  export_type         :string(255)
#  file_number         :string(255)
#  id                  :integer          not null, primary key
#  invoice_date        :date
#  suffix              :string(255)
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_intacct_alliance_exports_on_file_number_and_suffix  (file_number,suffix)
#

class IntacctAllianceExport < ActiveRecord::Base
  has_many :intacct_receivables, :dependent => :destroy
  has_many :intacct_payables, :dependent => :destroy
  has_many :intacct_checks, :dependent => :destroy

  EXPORT_TYPE_CHECK = 'check'
  EXPORT_TYPE_INVOICE = 'invoice'
end
