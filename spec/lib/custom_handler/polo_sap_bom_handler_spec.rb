require 'spec_helper'

describe OpenChain::CustomHandler::PoloSapBomHandler do
  context 'security' do
    it "shoud allow user who can edit products" do
      u = User.new
      u.should_receive(:edit_products?).and_return(true)
      described_class.new(nil).can_view?(u).should be_true
    end
    it "should not allow user who can't edit products" do
      u = User.new
      u.should_receive(:edit_products?).and_return(false)
      described_class.new(nil).can_view?(u).should be_false
    end
  end

  context "xl_client processing" do
    before :each do
      @xlc = mock("XL Client")
      @cf = mock('custom_file')
      @cf.stub(:attached_file_name).and_return('t.xlsx')
      @att = mock('attached')
      @att.should_receive(:path).and_return('/path/to')
      @cf.stub(:attached).and_return(@att)
      User.any_instance.stub(:edit_products?).and_return true
      OpenChain::XLClient.should_receive(:new).with('/path/to').and_return(@xlc)
    end
    it "should create new parent product and new existing children" do
      @xlc.should_receive(:last_row_number).and_return(2)
      @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10003','datatype'=>'number'}, #child material number
        38=>{'value'=>'1','datatype'=>'number'} #quantity
      )
      @xlc.should_receive(:get_row_as_column_hash).with(0,2).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10004','datatype'=>'number'}, #child material number
        38=>{'value'=>'2','datatype'=>'number'} #quantity
      )
      described_class.new(@cf).process Factory(:user)
      p = Product.find_by_unique_identifier 'parentuid'
      p.should have(2).bill_of_materials_children
      r = p.bill_of_materials_children.to_a
      r.first.child_product.unique_identifier.should == '10003'
      r.first.quantity.should == 1
      r.last.child_product.unique_identifier.should == '10004'
      r.last.quantity.should == 2
    end
    it "should process two parents with two children each" do
      @xlc.should_receive(:last_row_number).and_return(4)
      @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10003','datatype'=>'number'}, #child material number
        38=>{'value'=>'1','datatype'=>'number'} #quantity
      )
      @xlc.should_receive(:get_row_as_column_hash).with(0,2).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10004','datatype'=>'number'}, #child material number
        38=>{'value'=>'2','datatype'=>'number'} #quantity
      )
      @xlc.should_receive(:get_row_as_column_hash).with(0,3).and_return(
        0=>{'value'=>'parentuid2','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10005','datatype'=>'number'}, #child material number
        38=>{'value'=>'1','datatype'=>'number'} #quantity
      )
      @xlc.should_receive(:get_row_as_column_hash).with(0,4).and_return(
        0=>{'value'=>'parentuid2','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10006','datatype'=>'number'}, #child material number
        38=>{'value'=>'2','datatype'=>'number'} #quantity
      )
      described_class.new(@cf).process Factory(:user)
      p2 = Product.find_by_unique_identifier('parentuid2')
      p2.should have(2).bill_of_materials_children
      p2.child_products.first.unique_identifier.should == '10005'
      p2.child_products.last.unique_identifier.should == '10006'
      Product.find_by_unique_identifier('parentuid').should have(2).bill_of_materials_children
    end
    it "should process duplicate parents with different plant codes and only take last values" do
      @xlc.should_receive(:last_row_number).and_return(4)
      @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10003','datatype'=>'number'}, #child material number
        38=>{'value'=>'1','datatype'=>'number'} #quantity
      )
      @xlc.should_receive(:get_row_as_column_hash).with(0,2).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10004','datatype'=>'number'}, #child material number
        38=>{'value'=>'2','datatype'=>'number'} #quantity
      )
      @xlc.should_receive(:get_row_as_column_hash).with(0,3).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode2','datatype'=>'string'}, #plant code
        35=>{'value'=>'10005','datatype'=>'number'}, #child material number
        38=>{'value'=>'1','datatype'=>'number'} #quantity
      )
      @xlc.should_receive(:get_row_as_column_hash).with(0,4).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode2','datatype'=>'string'}, #plant code
        35=>{'value'=>'10006','datatype'=>'number'}, #child material number
        38=>{'value'=>'2','datatype'=>'number'} #quantity
      )
      described_class.new(@cf).process Factory(:user)
      p = Product.find_by_unique_identifier 'parentuid'
      p.should have(2).bill_of_materials_children
      r = p.bill_of_materials_children.to_a
      r.first.child_product.unique_identifier.should == '10005'
      r.first.quantity.should == 1
      r.last.child_product.unique_identifier.should == '10006'
      r.last.quantity.should == 2
    end
    it "should associate existing parent / child" do
      p = Factory(:product,:unique_identifier=>'parentuid')
      c = Factory(:product,:unique_identifier=>'10003')
      @xlc.should_receive(:last_row_number).and_return(1)
      @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10003','datatype'=>'number'}, #child material number
        38=>{'value'=>'1','datatype'=>'number'} #quantity
      )
      described_class.new(@cf).process Factory(:user)
      Product.count.should == 2
      p.child_products.to_a.should == [c]
    end
    it "should associate new child with existing parent" do
      p = Factory(:product,:unique_identifier=>'parentuid')
      @xlc.should_receive(:last_row_number).and_return(1)
      @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10003','datatype'=>'number'}, #child material number
        38=>{'value'=>'1','datatype'=>'number'} #quantity
      )
      described_class.new(@cf).process Factory(:user)
      Product.count.should == 2
      c = Product.find_by_unique_identifier '10003'
      c.should_not be_nil
      p.child_products.to_a.should == [c]
    end
    it "should maintain existing parent when new parent added for child" do
      old_parent = Factory(:product)
      c = Factory(:product,:unique_identifier=>'10003')
      c.bill_of_materials_parents.create!(:parent_product_id=>old_parent.id,:quantity=>1)
      @xlc.should_receive(:last_row_number).and_return(1)
      @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10003','datatype'=>'number'}, #child material number
        38=>{'value'=>'1','datatype'=>'number'} #quantity
      )
      described_class.new(@cf).process Factory(:user)
      Product.count.should == 3
      c.reload
      c.should have(2).bill_of_materials_parents
    end
    it "should clear existing children (but shouldn't delete them) when parent is processed" do
      p = Factory(:product,:unique_identifier=>'parentuid')
      old_c = Factory(:product)
      p.bill_of_materials_children.create!(:child_product_uid=>old_c.id,:quantity=>1)
      @xlc.should_receive(:last_row_number).and_return(1)
      @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10003','datatype'=>'number'}, #child material number
        38=>{'value'=>'1','datatype'=>'number'} #quantity
      )
      described_class.new(@cf).process Factory(:user)
      Product.count.should == 3
      old_c.reload
      old_c.parent_products.should be_empty
      p.reload
      p.child_products.first.unique_identifier.should == '10003'
    end
    it "should write message to user account" do
      u = Factory(:user)
      @xlc.should_receive(:last_row_number).and_return(1)
      @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
        0=>{'value'=>'parentuid','datatype'=>'string'}, #parent material number
        23=>{'value'=>'plantcode','datatype'=>'string'}, #plant code
        35=>{'value'=>'10003','datatype'=>'number'}, #child material number
        38=>{'value'=>'1','datatype'=>'number'} #quantity
      )
      described_class.new(@cf).process u
      u.should have(1).messages
    end
  end
end
