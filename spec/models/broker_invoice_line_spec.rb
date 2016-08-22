require 'spec_helper'

describe BrokerInvoiceLine do

  context "duty_charge_type?" do
    it "should identify D as a duty charge type" do
      l = BrokerInvoiceLine.new
      expect(l.duty_charge_type?).to be_falsey

      l.charge_type = "D"
      expect(l.duty_charge_type?).to be_truthy
      l.charge_type = "d"
      expect(l.duty_charge_type?).to be_truthy

      l.charge_type = "B"
      expect(l.duty_charge_type?).to be_falsey
    end
  end

  context "hst_gst_charge_code?" do
    it "should identify all fenix hst/gst charge codes" do
      l = BrokerInvoiceLine.new
      expect(l.hst_gst_charge_code?).to be_falsey

      (250..260).each do |i|
        l.charge_code = "#{i}"
        expect(l.hst_gst_charge_code?).to be_truthy
      end

      l.charge_code = "261"
      expect(l.hst_gst_charge_code?).to be_falsey
    end
  end
end