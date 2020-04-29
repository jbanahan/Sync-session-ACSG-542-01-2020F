require 'open_chain/report/report_helper'
require 'open_chain/report/us_billing_summary'

# Maintains the interface for the original FootLockerBillingSummary
# For other importers, use UsBillingSummary directly.
module OpenChain; module Report; class FootLockerBillingSummary < UsBillingSummary

  def self.permission? user
    super
  end

  def self.run_report run_by, settings={}
    super run_by, settings.merge('customer_number' => 'FOOLO')
  end

end; end; end

