# == Schema Information
#
# Table name: intacct_payables
#
#  bill_date                  :date
#  bill_number                :string(255)
#  check_number               :string(255)
#  company                    :string(255)
#  created_at                 :datetime         not null
#  currency                   :string(255)
#  id                         :integer          not null, primary key
#  intacct_alliance_export_id :integer
#  intacct_errors             :text
#  intacct_key                :string(255)
#  intacct_upload_date        :datetime
#  payable_type               :string(255)
#  updated_at                 :datetime         not null
#  vendor_number              :string(255)
#  vendor_reference           :string(255)
#
# Indexes
#
#  index_intacct_payables_on_intacct_alliance_export_id   (intacct_alliance_export_id)
#  intacct_payables_by_company_vendor_number_bill_number  (company,vendor_number,bill_number)
#

class IntacctPayable < ActiveRecord::Base
  belongs_to :intacct_alliance_export, :inverse_of => :intacct_payables
  has_many :intacct_payable_lines, :dependent => :destroy
  has_many :intacct_checks

  PAYABLE_TYPE_BILL ||= 'bill'
  PAYABLE_TYPE_ADVANCED ||= 'advanced'
  PAYABLE_TYPE_CHECK ||= 'invoiced check'

  def canada?
    ['als', 'vcu'].include? company
  end

  def self.suggested_fix error
    return "" if error.blank?

    case error
    when /Description 2: Invalid Vendor/i, /Failed to retrieve Terms for Vendor/i, /Failed to find vendor object/i
      "Create Vendor account in Intacct and/or ensure account has payment Terms set."
    when /Description 2: Invalid Customer/i
      "Create Customer account in Intacct."
    else
      # If there's only a single BL01001973 error with a "Description 2: Could not create Document record", then have the user attempt to clear and retry
      # otherwise, return an unknown error.
      if error.scan("BL01001973").size == 1 && error.scan("XL03000009").size == 1
        "Temporary Upload Error. Click 'Clear This Error' link to try again."
      else
        "Unknown Error. Contact support@vandegriftinc.com to resolve error."
      end
    end
  end
end
