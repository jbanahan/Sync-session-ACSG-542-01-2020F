require 'spec_helper'

describe OpenChain::CustomHandler::FenixInvoiceParser do
  before :each do
    @content = File.read 'spec/support/bin/fenix_invoices.csv'
    @k = OpenChain::CustomHandler::FenixInvoiceParser
  end
  it "should write invoice" do
    @k.parse @content
    BrokerInvoice.count.should == 2
    bi = BrokerInvoice.find_by_broker_reference_and_source_system '280952', 'Fenix'
    bi.invoice_total.should == 50.85 #does not include GST (code 2)
    bi.suffix.should be_blank
    bi.currency.should == 'CAD'
    bi.invoice_date = Date.new(2013,1,14)
    bi.invoice_number.should == '9'
  end
  it "should write details" do
    @k.parse @content
    bi = BrokerInvoice.find_by_broker_reference_and_source_system '280952', 'Fenix'
    bi.should have(3).broker_invoice_lines

    billing = bi.broker_invoice_lines.find_by_charge_code '5'
    billing.charge_description.should == 'BILLING'
    billing.charge_amount.should == 45
    billing.charge_type.should == 'R'
    
    hst = bi.broker_invoice_lines.find_by_charge_code '255'
    hst.charge_description.should == 'HST (ON)'
    hst.charge_amount.should == 5.85
    hst.charge_type.should == 'R'
    
    gst = bi.broker_invoice_lines.find_by_charge_code '2'
    gst.charge_description.should == 'GST ON IMPORTS'
    gst.charge_amount.should == 4523.98
    gst.charge_type.should == 'D'
  end
  it "should replace invoice" do
    #going to process, then delete a line, then reprocess and line should come back
    @k.parse @content
    bi = BrokerInvoice.find_by_broker_reference_and_source_system '280952', 'Fenix'
    bi.broker_invoice_lines.first.destroy
    bi.update_attributes(:invoice_total=>2)
    
    @k.parse @content
    bi.reload
    bi.should have(3).broker_invoice_lines
    bi.invoice_total.should == 50.85
  end
  it "should match to entry" do
    ent = Factory(:entry,:source_system=>'Fenix',:broker_reference=>'280952')
    @k.parse @content
    bi = BrokerInvoice.find_by_broker_reference_and_source_system '280952', 'Fenix'
    bi.entry.should == ent
  end
end
