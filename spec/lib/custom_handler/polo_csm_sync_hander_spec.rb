require 'spec_helper'

describe OpenChain::CustomHandler::PoloCsmSyncHandler do
  before :each do
    @italy = Factory(:country,:iso_code=>"IT")
    @us = Factory(:country,:iso_code=>"US")
    @xlc = mock('xl_client')
    @xlc.stub(:raise_errors=)
    @cf = mock('custom_file')
    @att = mock('attached')
    @att.should_receive(:path).and_return('/path/to')
    @cf.stub(:attached).and_return(@att)
    @cf.stub(:update_attributes)
    OpenChain::XLClient.should_receive(:new).with('/path/to').and_return(@xlc)
    @csm = Factory(:custom_definition,:module_type=>'Product',:label=>"CSM Number",:data_type=>'string')
  end
  it "should update lines that match" do
    p = Factory(:product)
    p.classifications.create!(:country_id=>@italy.id).tariff_records.create!(:hts_1=>"1234567890",:line_number=>1)
    p2 = Factory(:product)
    p3 = Factory(:product)
    p3.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>'1234567890',:line_number=>1)
    p1_csm = "ABC123XYZ"
    p2_csm = "DEF654GHI"
    p3_csm = 'GHI123ABC'
    Product.any_instance.stub(:can_edit?).and_return(true)
    @xlc.should_receive(:last_row_number).and_return(3)
    @xlc.should_receive(:get_cell).with(0,1,8).and_return({'cell'=>{'value'=>p.unique_identifier}})
    @xlc.should_receive(:get_cell).with(0,1,2).and_return({'cell'=>{'value'=>'ABC'}})
    @xlc.should_receive(:get_cell).with(0,1,3).and_return({'cell'=>{'value'=>'123'}})
    @xlc.should_receive(:get_cell).with(0,1,4).and_return({'cell'=>{'value'=>'XYZ'}})
    @xlc.should_receive(:set_cell).with(0,1,16,'Style Found with IT HTS')
    @xlc.should_receive(:get_cell).with(0,2,8).and_return({'cell'=>{'value'=>p2.unique_identifier}})
    @xlc.should_receive(:get_cell).with(0,2,2).and_return({'cell'=>{'value'=>'DEF'}})
    @xlc.should_receive(:get_cell).with(0,2,3).and_return({'cell'=>{'value'=>'654'}})
    @xlc.should_receive(:get_cell).with(0,2,4).and_return({'cell'=>{'value'=>'GHI'}})
    @xlc.should_receive(:set_cell).with(0,2,16,'Style Found, No US / IT HTS')
    @xlc.should_receive(:get_cell).with(0,3,8).and_return({'cell'=>{'value'=>p3.unique_identifier}})
    @xlc.should_receive(:get_cell).with(0,3,2).and_return({'cell'=>{'value'=>'GHI'}})
    @xlc.should_receive(:get_cell).with(0,3,3).and_return({'cell'=>{'value'=>'123'}})
    @xlc.should_receive(:get_cell).with(0,3,4).and_return({'cell'=>{'value'=>'ABC'}})
    @xlc.should_receive(:set_cell).with(0,3,16,"Style Found, No IT HTS")
    @xlc.should_receive(:set_cell).with(0,3,17,p3.classifications.first.tariff_records.first.hts_1.hts_format)

    @xlc.should_receive(:save)
    OpenChain::CustomHandler::PoloCsmSyncHandler.new(@cf).process Factory(:user)
    p.get_custom_value(@csm).value.should == p1_csm 
    p2.get_custom_value(@csm).value.should == p2_csm
    p3.get_custom_value(@csm).value.should == p3_csm
    p.should have(1).entity_snapshots
  end
  it "should not update with csm numbers that are on different products" do
    p = Factory(:product)
    csm = p.get_custom_value @csm
    csm.value = "ABC123XYZ"
    csm.save!

    p2 = Factory(:product)
    Product.any_instance.stub(:can_edit?).and_return(true)

    @xlc.should_receive(:last_row_number).and_return(1)
    @xlc.should_receive(:get_cell).with(0,1,8).and_return({'cell'=>{'value'=>p2.unique_identifier}})
    @xlc.should_receive(:get_cell).with(0,1,2).and_return({'cell'=>{'value'=>'ABC'}})
    @xlc.should_receive(:get_cell).with(0,1,3).and_return({'cell'=>{'value'=>'123'}})
    @xlc.should_receive(:get_cell).with(0,1,4).and_return({'cell'=>{'value'=>'XYZ'}})
    @xlc.should_receive(:set_cell).with(0,1,16,"Rejected: CSM Number is already assigned to US Style #{p.unique_identifier}")
    @xlc.should_receive(:save)

    OpenChain::CustomHandler::PoloCsmSyncHandler.new(@cf).process Factory(:user)
    p2.get_custom_value(@csm).value.should be_nil 
  end

  it "should update if csm number is in a different custom value" do
    other_cd = Factory(:custom_definition)
    p = Factory(:product)
    p.update_custom_value! other_cd, "ABC123XYZ"

    p2 = Factory(:product)
    Product.any_instance.stub(:can_edit?).and_return(true)

    @xlc.should_receive(:last_row_number).and_return(1)
    @xlc.should_receive(:get_cell).with(0,1,8).and_return({'cell'=>{'value'=>p2.unique_identifier}})
    @xlc.should_receive(:get_cell).with(0,1,2).and_return({'cell'=>{'value'=>'ABC'}})
    @xlc.should_receive(:get_cell).with(0,1,3).and_return({'cell'=>{'value'=>'123'}})
    @xlc.should_receive(:get_cell).with(0,1,4).and_return({'cell'=>{'value'=>'XYZ'}})
    @xlc.should_receive(:set_cell).with(0,1,16,'Style Found, No US / IT HTS')
    @xlc.should_receive(:save)

    OpenChain::CustomHandler::PoloCsmSyncHandler.new(@cf).process Factory(:user)
    p2.get_custom_value(@csm).value.should == "ABC123XYZ"
  end
  
  it "should warn if product already has a different CSM number" do
    p = Factory(:product)
    csm = p.get_custom_value @csm
    csm.value = "1234567890"
    csm.save!

    Product.any_instance.stub(:can_edit?).and_return(true)

    @xlc.should_receive(:last_row_number).and_return(1)
    @xlc.should_receive(:get_cell).with(0,1,8).and_return({'cell'=>{'value'=>p.unique_identifier}})
    @xlc.should_receive(:get_cell).with(0,1,2).and_return({'cell'=>{'value'=>'ABC'}})
    @xlc.should_receive(:get_cell).with(0,1,3).and_return({'cell'=>{'value'=>'123'}})
    @xlc.should_receive(:get_cell).with(0,1,4).and_return({'cell'=>{'value'=>'XYZ'}})
    @xlc.should_receive(:set_cell).with(0,1,16,"Rejected: US Style already has the CSM Number #{csm.value} assigned.")
    @xlc.should_receive(:save)

    OpenChain::CustomHandler::PoloCsmSyncHandler.new(@cf).process Factory(:user)
    p.get_custom_value(@csm).value.should == csm.value
  end
  
  it "should not save products where csm number has not changed" do
    Product.any_instance.stub(:can_edit?).and_return(true)
    d = 1.day.ago
    p = Factory(:product)
    p.update_custom_value! @csm, 'ABC123XYZ'
    p.update_attributes(:updated_at=>d)
    @xlc.should_receive(:last_row_number).and_return(1)
    @xlc.should_receive(:get_cell).with(0,1,8).and_return({'cell'=>{'value'=>p.unique_identifier}})
    @xlc.should_receive(:get_cell).with(0,1,2).and_return({'cell'=>{'value'=>'ABC'}})
    @xlc.should_receive(:get_cell).with(0,1,3).and_return({'cell'=>{'value'=>'123'}})
    @xlc.should_receive(:get_cell).with(0,1,4).and_return({'cell'=>{'value'=>'XYZ'}})
    @xlc.should_receive(:set_cell).with(0,1,16,'Style Found, No US / IT HTS')
    @xlc.should_receive(:save)
    OpenChain::CustomHandler::PoloCsmSyncHandler.new(@cf).process Factory(:user)
    p.reload
    p.get_custom_value(@csm).value.should == 'ABC123XYZ'
    p.entity_snapshots.should be_empty
    p.updated_at.to_i.should == d.to_i
  end
  it "should not update lines that don't match" do
    @xlc.should_receive(:last_row_number).and_return(1)
    @xlc.should_receive(:get_cell).with(0,1,8).and_return({'cell'=>{'value'=>'abc'}})
    @xlc.should_receive(:set_cell).with(0,1,16,'Style Not Found')
    @xlc.should_receive(:save)
    OpenChain::CustomHandler::PoloCsmSyncHandler.new(@cf).process Factory(:user)
  end
  context :security do
    it "should not allow users who can't edit products" do
      p = Factory(:product)
      Product.any_instance.stub(:can_edit?).and_return(false)
      @xlc.stub(:save)
      @cf.stub(:id).and_return("1")
      @xlc.should_receive(:last_row_number).and_return(2)
      @xlc.should_receive(:get_cell).with(0,1,8).and_return({'cell'=>{'value'=>p.unique_identifier}})
      lambda {OpenChain::CustomHandler::PoloCsmSyncHandler.new(@cf).process Factory(:user)}.should raise_error "User does not have permission to edit product #{p.unique_identifier}"
    end
  end
end
