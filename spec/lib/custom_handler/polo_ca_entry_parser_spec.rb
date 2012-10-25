require 'spec_helper'

describe OpenChain::CustomHandler::PoloCaEntryParser do
  describe :parse_workbook do
    context "successful processing" do
      before :each do
        @xlc = mock('xl_client')
        @cf = mock('custom_file')
        @att = mock('attached')
        @att.should_receive(:path).and_return('/path/to')
        @cf.should_receive(:attached).and_return(@att)
        #pass in line number and array of arrays where each sub-array is [column,value, datatype]
        @make_line_lambda = lambda {|line_number,line_array|
          r_val = []
          line_array.each do |ary|
            r_val << {"position"=>{"column"=>ary[0]},"cell"=>{"value"=>ary[1],"datatype"=>ary[2]}}
          end
          @xlc.should_receive(:get_row).with(0,line_number).and_return(r_val) 
        }
        @line_array = [
          [0,'123456','string'],
          [1,'MBOL','string'],
          [2,'HBOL','string'],
          [3,'CONT','string']
        ]
        OpenChain::XLClient.should_receive(:new).with('/path/to').and_return(@xlc)
        @h = OpenChain::CustomHandler::PoloCaEntryParser.new(@cf)
      end
      it 'should read file and call parse record' do
        User.any_instance.stub(:edit_entries?).and_return(true)
        @xlc.should_receive(:last_row_number).and_return(1)
        @make_line_lambda.call 1, @line_array
        @h.should_receive(:parse_record).with({:brok_ref=>'123456',:mbol=>'MBOL',:hbol=>'HBOL',:cont=>'CONT'})
        @h.process(Factory(:master_user))
      end
      it 'should call parse record for multiple files' do
        User.any_instance.stub(:edit_entries?).and_return(true)
        @xlc.should_receive(:last_row_number).and_return(2)
        @make_line_lambda.call 1, @line_array
        @line_array[0][1] = "654321"
        @line_array[1][1] = "MB2"
        @line_array[2][1] = "HB2"
        @line_array[3][1] = "C2"
        @make_line_lambda.call 2, @line_array
        @h.should_receive(:parse_record).with({:brok_ref=>'123456',:mbol=>'MBOL',:hbol=>'HBOL',:cont=>'CONT'})
        @h.should_receive(:parse_record).with({:brok_ref=>'654321',:mbol=>'MB2',:hbol=>'HB2',:cont=>'C2'})
        @h.process(Factory(:master_user))
      end
    end
    context "security" do
      before :each do
        cf = mock("customfile") 
        cf.stub(:id).and_return(1)
        @h = OpenChain::CustomHandler::PoloCaEntryParser.new(cf)
      end
      it 'should error if user cannot edit entries' do
        @h.should_not_receive(:parse_record)
        lambda {@h.process(Factory(:user))}.should raise_error "User does not have permission to process these entries."
      end
      it 'should error if user not in master company' do
        @h.should_not_receive(:parse_record)
        u = Factory(:master_user)
        u.stub(:edit_entries?).and_return(false)
        lambda {@h.process(u)}.should raise_error "User does not have permission to process these entries."
      end
    end
  end
  describe :can_view? do
    before :each do
      cf = mock("customfile") 
      cf.stub(:id).and_return(1)
      @h = OpenChain::CustomHandler::PoloCaEntryParser.new(cf)
    end
    it "should allow if user is from master and can edit entries" do
      User.any_instance.stub(:edit_entries?).and_return(true)
      @h.can_view?(Factory(:master_user)).should be_true
    end
    it "should not allow if user is not from master" do
      User.any_instance.stub(:edit_entries?).and_return(true)
      @h.can_view?(Factory(:user)).should be_false
    end
    it "should not allow if user cannot edit entries" do
      User.any_instance.stub(:edit_entries?).and_return(false)
      @h.can_view?(Factory(:master_user)).should be_false
    end
  end
  describe :parse_record do
    before :each do
      @ca = Factory(:country,:iso_code=>'CA')
      @vals = {:brok_ref=>'12345',:mbol=>'MBOL',:hbol=>'HBOL',:cont=>'CONT'}
      @cf = Factory(:custom_file)
      @h = OpenChain::CustomHandler::PoloCaEntryParser.new(@cf)
    end
    it 'should create entry' do
      @h.parse_record(@vals)
      ent = Entry.find_by_broker_reference('12345')
      ent.master_bills_of_lading.should == 'MBOL'
      ent.house_bills_of_lading.should == 'HBOL'
      ent.container_numbers.should == 'CONT'
      ent.import_country.should == @ca
      ent.source_system.should == 'Fenix' #so it picks up the eventual fenix update
    end
    it 'should handle multiple containers' do
      @vals[:cont] = "C1, C2,  C3  "
      @h.parse_record(@vals)
      ent = Entry.find_by_broker_reference('12345')
      ent.container_numbers.should == "C1 C2 C3"
    end
    it 'should handle multiple house bills' do
      @vals[:hbol] = "C1, C2,  C3  "
      @h.parse_record(@vals)
      ent = Entry.find_by_broker_reference('12345')
      ent.house_bills_of_lading.should == "C1 C2 C3"
    end
    it 'should update existing entry if values have changed' do
      ent = Factory(:entry,:broker_reference=>'12345',:master_bills_of_lading=>'XX',:source_system=>'Fenix')
      @h.parse_record(@vals)
      Entry.count.should == 1
      ent.reload
      ent.master_bills_of_lading.should == 'MBOL'
    end
    it 'should not update existing entry if values have not changed' do
      @h.parse_record(@vals)
      ent = Entry.find_by_broker_reference('12345')
      d = 7.days.ago
      ent.update_attributes(:updated_at=>d)
      @h.parse_record(@vals)
      ent.reload
      ent.updated_at.to_i.should == d.to_i
    end
    it 'should create custom file records' do
      @h.parse_record(@vals)
      ent = Entry.find_by_broker_reference('12345')
      @cf.reload
      @cf.custom_file_records.first.linked_object.should == ent
    end
    it 'should log error if record is not for polo importer' do
      ent = Factory(:entry,:broker_reference=>'12345',:master_bills_of_lading=>'XX',:source_system=>'Fenix',:importer_tax_id=>'99')
      lambda {@h.parse_record(@vals)}.should raise_error "Broker Reference 12345 is not assigned to a Ralph Lauren importer."
    end
  end
end
