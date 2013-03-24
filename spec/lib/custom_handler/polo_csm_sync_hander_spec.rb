require 'spec_helper'

describe OpenChain::CustomHandler::PoloCsmSyncHandler do
  before :each do
    @xlc = mock('xl_client')
    @xlc.stub(:raise_errors=)
    @cf = mock('custom_file')
    @att = mock('attached')
    @att.should_receive(:path).and_return('/path/to')
    @cf.stub(:attached).and_return(@att)
    @cf.stub(:update_attributes)
    OpenChain::XLClient.should_receive(:new).with('/path/to').and_return(@xlc)
    @csm = Factory(:custom_definition,:module_type=>'Product',:label=>"CSM Number",:data_type=>'text')
    @dept = Factory(:custom_definition,:module_type=>'Product',:label=>"CSM Department",:data_type=>'text')
    @h = described_class.new @cf 
    Product.any_instance.stub(:can_edit?).and_return(true)
  end

  # CSM Number is columns C-F in the source spreadsheet concatenated
  # US Style Number is column I

  it "should set CSM numbers for existing product with no CSM custom value" do
    p = Factory(:product)
    @xlc.should_receive(:last_row_number).and_return(2)
    @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
      2=>{'value'=>'140','datatype'=>'string'},
      3=>{'value'=>'ABCDE','datatype'=>'string'},
      4=>{'value'=>'FGHIJ','datatype'=>'string'},
      5=>{'value'=>'KLMNO','datatype'=>'string'},
      8=>{'value'=>p.unique_identifier,'datatype'=>'string'},
      13=>{'value'=>'CSMDEPT','datatype'=>'string'}
    )
    @xlc.should_receive(:get_row_as_column_hash).with(0,2).and_return(
      2=>{'value'=>'ZZZ','datatype'=>'string'},
      3=>{'value'=>'PQRST','datatype'=>'string'},
      4=>{'value'=>'UVWXY','datatype'=>'string'},
      5=>{'value'=>'Z1234','datatype'=>'string'},
      8=>{'value'=>p.unique_identifier,'datatype'=>'string'},
      13=>{'value'=>'CSMDEPT','datatype'=>'string'}
    )
    @h.process Factory(:user)
    p.get_custom_value(@csm).value.should == "140ABCDEFGHIJKLMNO\nZZZPQRSTUVWXYZ1234"
  end
  it "should include non-contiguous CSM numbers for a product" do
    p = Factory(:product)
    @xlc.should_receive(:last_row_number).and_return(3)
    @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
      2=>{'value'=>'140','datatype'=>'string'},
      3=>{'value'=>'ABCDE','datatype'=>'string'},
      4=>{'value'=>'FGHIJ','datatype'=>'string'},
      5=>{'value'=>'KLMNO','datatype'=>'string'},
      8=>{'value'=>p.unique_identifier,'datatype'=>'string'},
      13=>{'value'=>'CSMDEPT','datatype'=>'string'}

    )
    @xlc.should_receive(:get_row_as_column_hash).with(0,2).and_return(
      2=>{'value'=>'140','datatype'=>'string'},
      3=>{'value'=>'ABCDE','datatype'=>'string'},
      4=>{'value'=>'FGHIJ','datatype'=>'string'},
      5=>{'value'=>'KLMNO','datatype'=>'string'},
      8=>{'value'=>'something else','datatype'=>'string'},
      13=>{'value'=>'CSMDEPT','datatype'=>'string'}

    )
    @xlc.should_receive(:get_row_as_column_hash).with(0,3).and_return(
      2=>{'value'=>'ZZZ','datatype'=>'string'},
      3=>{'value'=>'PQRST','datatype'=>'string'},
      4=>{'value'=>'UVWXY','datatype'=>'string'},
      5=>{'value'=>'Z1234','datatype'=>'string'},
      8=>{'value'=>p.unique_identifier,'datatype'=>'string'},
      13=>{'value'=>'CSMDEPT','datatype'=>'string'}

    )
    @h.process Factory(:user)
    p.get_custom_value(@csm).value.should == "140ABCDEFGHIJKLMNO\nZZZPQRSTUVWXYZ1234"
    Product.find_by_unique_identifier('something else').get_custom_value(@csm).value.should == "140ABCDEFGHIJKLMNO"
  end
  it "should create new CSM number for new product" do
    @xlc.should_receive(:last_row_number).and_return(1)
    @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
      2=>{'value'=>'140','datatype'=>'string'},
      3=>{'value'=>'ABCDE','datatype'=>'string'},
      4=>{'value'=>'FGHIJ','datatype'=>'string'},
      5=>{'value'=>'KLMNO','datatype'=>'string'},
      8=>{'value'=>'something else','datatype'=>'string'},
      13=>{'value'=>'CSMDEPT','datatype'=>'string'}

    )
    @h.process Factory(:user)
    p = Product.find_by_unique_identifier('something else')
    p.get_custom_value(@csm).value.should == "140ABCDEFGHIJKLMNO"
    p.get_custom_value(@dept).value.should == 'CSMDEPT'
  end
  it "should drop existing CSM numbers not in file" do
    p = Factory(:product)
    p.update_custom_value!(@csm,'XZY')
    @xlc.should_receive(:last_row_number).and_return(1)
    @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
      2=>{'value'=>'140','datatype'=>'string'},
      3=>{'value'=>'ABCDE','datatype'=>'string'},
      4=>{'value'=>'FGHIJ','datatype'=>'string'},
      5=>{'value'=>'KLMNO','datatype'=>'string'},
      8=>{'value'=>p.unique_identifier,'datatype'=>'string'},
      13=>{'value'=>'CSMDEPT','datatype'=>'string'}
    )
    @h.process Factory(:user)
    p.get_custom_value(@csm).value.should == "140ABCDEFGHIJKLMNO"
  end
  it "should fail if CSM number is not 18 digits" do
    @cf.stub(:id).and_return(1)
    p = Factory(:product)
    @xlc.should_receive(:last_row_number).and_return(1)
    @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
      2=>{'value'=>'140XX','datatype'=>'string'},
      3=>{'value'=>'ABCDE','datatype'=>'string'},
      4=>{'value'=>'FGHIJ','datatype'=>'string'},
      5=>{'value'=>'KLMNO','datatype'=>'string'},
      8=>{'value'=>p.unique_identifier,'datatype'=>'string'},
      13=>{'value'=>'CSMDEPT','datatype'=>'string'}
    )
    Exception.any_instance.should_receive(:log_me)
    @h.process Factory(:user)
    p.get_custom_value(@csm).value.should be_blank 
  end
  it "should not fail for empty lines" do
    @xlc.should_receive(:last_row_number).and_return(1)
    @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return({})
    Exception.any_instance.should_not_receive(:log_me)
    @h.process Factory(:user)
  end
  it "should fail if user cannot edit products" do
    Product.any_instance.stub(:can_edit?).and_return false
    p = Factory(:product)
    @cf.stub(:id).and_return(1)
    @xlc.should_receive(:last_row_number).and_return(1)
    @xlc.should_receive(:get_row_as_column_hash).with(0,1).and_return(
      2=>{'value'=>'140','datatype'=>'string'},
      3=>{'value'=>'ABCDE','datatype'=>'string'},
      4=>{'value'=>'FGHIJ','datatype'=>'string'},
      5=>{'value'=>'KLMNO','datatype'=>'string'},
      8=>{'value'=>p.unique_identifier,'datatype'=>'string'},
      13=>{'value'=>'CSMDEPT','datatype'=>'string'}
    )
    Exception.any_instance.should_receive(:log_me)
    @h.process Factory(:user)
    p.get_custom_value(@csm).value.should be_blank 
  end
end
