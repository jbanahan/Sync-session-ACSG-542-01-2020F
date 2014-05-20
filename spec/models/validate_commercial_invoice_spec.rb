require 'spec_helper'

describe ValidateCommercialInvoice do

  it "should raise an error if the object has no invoice" do
    vci = ValidateCommercialInvoice.create!
    expect { vci.validate_invoice_date([]) }.to raise_error(RuntimeError, "No invoice found.")
  end

  it "should raise an error if the invoice has no invoice date" do
    vci = ValidateCommercialInvoice.create!
    ci = Factory(:commercial_invoice)
    expect { vci.validate_invoice_date(ci) }.to raise_error(RuntimeError, "No invoice date has been set.")
  end

  it "should return nil if the invoice has an invoice date" do
    vci = ValidateCommercialInvoice.create!
    ci = Factory(:commercial_invoice, invoice_date: Time.now - 5.days)
    vci.validate_invoice_date(ci).should == nil
  end

end