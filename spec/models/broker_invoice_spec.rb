require 'spec_helper'

describe BrokerInvoice do
  before :each do
    MasterSetup.get.update_attributes(:broker_invoice_enabled=>true)
    @inv = Factory(:broker_invoice)
  end
  it 'should not be visible without permission' do
    u = Factory(:user,:broker_invoice_view=>false)
    u.company.update_attributes(:master=>true)
    @inv.can_view?(u).should be_false
  end
  it 'should not be visible without company permission' do
    u = Factory(:user,:broker_invoice_view=>true)
    @inv.can_view?(u).should be_false
  end
  it 'should be visible with permission' do
    u = Factory(:user,:broker_invoice_view=>true)
    u.company.update_attributes(:master=>true)
    @inv.can_view?(u).should be_true
  end
end
