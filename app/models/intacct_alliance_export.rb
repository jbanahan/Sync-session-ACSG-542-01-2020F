# == Schema Information
#
# Table name: intacct_alliance_exports
#
#  id                  :integer          not null, primary key
#  file_number         :string(255)
#  suffix              :string(255)
#  data_requested_date :datetime
#  data_received_date  :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  division            :string(255)
#  customer_number     :string(255)
#  invoice_date        :date
#  check_number        :string(255)
#  ap_total            :decimal(10, 2)
#  ar_total            :decimal(10, 2)
#  export_type         :string(255)
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
