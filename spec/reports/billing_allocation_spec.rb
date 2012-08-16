require 'spec_helper'

describe OpenChain::Report::BillingAllocation do

  it 'should allocate charges by piece count' do
    ent = Factory(:entry,:customer_number=>'abc',:entry_number=>'33612345678',:entered_value=>BigDecimal("100.00"))
    bi = ent.broker_invoices.create!(:invoice_date=>0.seconds.ago)
    bil = bi.broker_invoice_lines.create!(:charge_code=>'0007',:charge_description=>'ENTRY FEE',:charge_amount=>BigDecimal('100.00'),:charge_type=>'R')
    ci = ent.commercial_invoices.crate!(:invoice_number=>'INV001')
    cil_60
  end
  it 'should process multiple broker invoice lines'
  it 'should not process charge type D'
  it 'should process multiple broker invoices individually'
  it 'shouuld allocate accross multiple commercial invoices'
  it 'should not run without start date'
  it 'should not run without end date'
  it 'should not run without customer numbers array'
  it 'should optionally filter by country'
end
