# encoding: utf-8

require 'spec_helper'

describe OpenChain::CustomHandler::GenericAllianceProductGenerator do
  before :each do
    @c = Factory(:company,:alliance_customer_number=>'MYCUS')
  end
  describe :sync do
    it "should call appropriate methods" do
      k = described_class
      m = mock("generator")
      k.should_receive(:new).with(@c).and_return m
      f = mock("file")
      f.should_receive(:unlink)
      m.should_receive(:sync_fixed_position).and_return(f)
      m.should_receive(:ftp_file).with(f)
      k.sync(@c).should be_nil
    end
  end
  describe :remote_file_name do
    it "should base remote file name on alliance customer number" do
      g = described_class.new(@c)
      g.remote_file_name.should match /^[0-9]{10}-MYCUS.DAT$/
    end
  end

  describe :fixed_position_map do
    it "should output correct mapping" do
      expected = [{:len=>15},{:len=>40},{:len=>10},{:len=>2}]
      described_class.new(@c).fixed_position_map.should == expected
    end
  end

  describe :new do 
    it "should initialize with a company id" do
      g = described_class.new(@c.id)
      # Just use remote filename as the check if the importer loaded correctly
      g.remote_file_name.end_with?("#{@c.alliance_customer_number}.DAT").should be_true
    end

    it "should initialize with a company record" do
      g = described_class.new(@c)
      g.remote_file_name.end_with?("#{@c.alliance_customer_number}.DAT").should be_true
    end

    it "should error if importer has no alliance number" do
      @c.update_attributes :alliance_customer_number => ""
      expect{described_class.new(@c)}.to raise_error "Importer is required and must have an alliance customer number"
    end

    it "should error if importer is not found" do
      expect{described_class.new(-1)}.to raise_error "Importer is required and must have an alliance customer number"
    end
  end

  context "with data" do
    before :each do
      @coo, @pn = ["Country of Origin","Part Number"].collect do |nm|
        Factory(:custom_definition,:module_type=>"Product",:label=>nm,:data_type=>"string")
      end
      @us = Factory(:country,:iso_code=>"US")
      @p = Factory(:product,:importer=>@c,:name=>"MYNAME")
      @p.update_custom_value! @coo, "CN"
      @p.update_custom_value! @pn, "MYPN"
      Factory(:tariff_record,:hts_1=>"1234567890",:classification=>Factory(:classification,:country=>@us,:product=>@p))
    end
    describe "sync_fixed_position" do
      after :each do
        @tmp.unlink if @tmp
      end
      it "should generate output file" do
        @tmp = described_class.new(@c).sync_fixed_position
        IO.read(@tmp.path).should == "MYPN           MYNAME                                  1234567890CN\n"
      end
      it "transliterates non-ASCII data" do
        # Text taken from Rails transliterate rdoc example
        @p.update_custom_value! @pn, "Ærøskøbing"
        @tmp = described_class.new(@c).sync_fixed_position
        expect(IO.read(@tmp.path)).to eq "AEroskobing    MYNAME                                  1234567890CN\n"
      end
      it "logs an error for non-translatable products and skips the record" do
        @p.update_custom_value! @pn, "Copyright ©"
        error = nil
        StandardError.any_instance.should_receive(:log_me) do 
          error = $!
        end

        # Nothing will have been written so nil is returned.
        expect(described_class.new(@c).sync_fixed_position).to be_nil
        expect(error.message).to eq "Untranslatable Non-ASCII character for Part Number 'Copyright ©' found at string index 10 in product query column 0: 'Copyright ©'."
      end
    end
    describe "query" do
      it "should output correct data" do
        r = ActiveRecord::Base.connection.execute described_class.new(@c).query
        r.count.should == 1
        vals = r.first
        vals[0].should == @p.id
        vals[1].should == "MYPN"
        vals[2].should == "MYNAME"
        vals[3].should == "1234567890"
        vals[4].should == "CN"
      end
      it "should limit to importer supplied" do
        #don't find this one
        Factory(:tariff_record,:hts_1=>"1234567890",:classification=>Factory(:classification,:country=>@us,:product=>Factory(:product,:importer=>Factory(:company))))
        r = ActiveRecord::Base.connection.execute described_class.new(@c).query
        r.count.should == 1
        vals = r.first
        vals[0].should == @p.id
      end
      it "should not output if part number is blank" do
        @p.update_custom_value! @pn, ""
        r = ActiveRecord::Base.connection.execute described_class.new(@c).query
        r.count.should == 0
      end
      it "should not output country of origin if not 2 digits" do
        @p.update_custom_value! @coo, "CHINA"
        r = ActiveRecord::Base.connection.execute described_class.new(@c).query
        r.first[4].should == ""
      end
      it "should only output US classifications" do
        Factory(:tariff_record,:hts_1=>'1234567777',:classification=>Factory(:classification,:product=>@p))
        r = ActiveRecord::Base.connection.execute described_class.new(@c).query
        r.count.should == 1
        r.first[3].should == '1234567890'
      end
      it "should not output product without US classification" do
        @p.classifications.destroy_all
        r = ActiveRecord::Base.connection.execute described_class.new(@c).query
        r.count.should == 0
      end
      it "should not output product without HTS number" do
        @p.classifications.first.tariff_records.first.update_attributes(:hts_1=>"")
        r = ActiveRecord::Base.connection.execute described_class.new(@c).query
        r.count.should == 0
      end
    end
  end
end
