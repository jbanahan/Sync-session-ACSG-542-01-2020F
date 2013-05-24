require 'spec_helper'

describe BrokerInvoiceLine do

  context :duty_charge_type? do
    it "should identify D as a duty charge type" do
      l = BrokerInvoiceLine.new
      l.duty_charge_type?.should be_false

      l.charge_type = "D"
      l.duty_charge_type?.should be_true
      l.charge_type = "d"
      l.duty_charge_type?.should be_true

      l.charge_type = "B"
      l.duty_charge_type?.should be_false
    end
  end

  context :hst_gst_charge_code? do
    it "should identify all fenix hst/gst charge codes" do
      l = BrokerInvoiceLine.new
      l.hst_gst_charge_code?.should be_false

      (250..260).each do |i|
        l.charge_code = "#{i}"
        l.hst_gst_charge_code?.should be_true
      end

      l.charge_code = "261"
      l.hst_gst_charge_code?.should be_false
    end
  end
end