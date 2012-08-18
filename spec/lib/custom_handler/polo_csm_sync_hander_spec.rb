require 'spec_helper'

describe OpenChain::CustomHandler::PoloCsmSyncHandler do
  before :each do
    @italy = Factory(:country,:iso_code=>"IT")
    @xlc = mock('xl_client')
    @cf = mock('custom_file')
    @att = mock('attached')
    @att.should_receive(:path).and_return('/path/to')
    @cf.should_receive(:attached).and_return(@att)
    OpenChain::XLClient.should_receive(:new).with('/path/to').and_return(@xlc)
    @csm = Factory(:custom_definition,:module_type=>'Product',:label=>"CSM Number",:data_type=>'string')
  end
  it "should update lines that match" do
    p = Factory(:product)
    p.classifications.create!(:country_id=>@italy.id).tariff_records.create!(:hts_1=>"1234567890",:line_number=>1)
    p2 = Factory(:product)
    p1_csm = "ABC123XYZ"
    p2_csm = "DEF654GHI"
    Product.any_instance.stub(:can_edit?).and_return(true)
    @xlc.should_receive(:last_row_number).and_return(2)
    @xlc.should_receive(:get_cell).with(0,1,8).and_return({'cell'=>{'value'=>p.unique_identifier}})
    @xlc.should_receive(:get_cell).with(0,1,2).and_return({'cell'=>{'value'=>'ABC'}})
    @xlc.should_receive(:get_cell).with(0,1,3).and_return({'cell'=>{'value'=>'123'}})
    @xlc.should_receive(:get_cell).with(0,1,4).and_return({'cell'=>{'value'=>'XYZ'}})
    @xlc.should_receive(:set_cell).with(0,1,16,'matched')
    @xlc.should_receive(:get_cell).with(0,2,8).and_return({'cell'=>{'value'=>p2.unique_identifier}})
    @xlc.should_receive(:get_cell).with(0,2,2).and_return({'cell'=>{'value'=>'DEF'}})
    @xlc.should_receive(:get_cell).with(0,2,3).and_return({'cell'=>{'value'=>'654'}})
    @xlc.should_receive(:get_cell).with(0,2,4).and_return({'cell'=>{'value'=>'GHI'}})
    @xlc.should_receive(:set_cell).with(0,2,16,'matched - no tariff')
    @xlc.should_receive(:save)
    OpenChain::CustomHandler::PoloCsmSyncHandler.new(@cf).process Factory(:user)
    p.get_custom_value(@csm).value.should == p1_csm 
    p2.get_custom_value(@csm).value.should == p2_csm
    p.should have(1).entity_snapshots
  end
  it "should not update lines that don't match" do
    @xlc.should_receive(:last_row_number).and_return(2)
    @xlc.should_receive(:get_cell).with(0,1,8).and_return({'cell'=>{'value'=>'abc'}})
    @xlc.should_receive(:set_cell).with(0,1,16,'not matched')
    @xlc.should_receive(:get_cell).with(0,2,8).and_return({'cell'=>{'value'=>'def'}})
    @xlc.should_receive(:set_cell).with(0,2,16,'not matched')
    @xlc.should_receive(:save)
    OpenChain::CustomHandler::PoloCsmSyncHandler.new(@cf).process Factory(:user)
  end
  context :security do
    it "should not allow users who can't edit products" do
      p = Factory(:product)
      Product.any_instance.stub(:can_edit?).and_return(false)
      @xlc.should_receive(:last_row_number).and_return(2)
      @xlc.should_receive(:get_cell).with(0,1,8).and_return({'cell'=>{'value'=>p.unique_identifier}})
      lambda {OpenChain::CustomHandler::PoloCsmSyncHandler.new(@cf).process Factory(:user)}.should raise_error "User does not have permission to edit product #{p.unique_identifier}"
    end
  end
end
