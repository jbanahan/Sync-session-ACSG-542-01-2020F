# encoding: utf-8

require 'spec_helper'

describe OpenChain::CustomHandler::GenericAllianceProductGenerator do
  before :each do
    @c = Factory(:company,:alliance_customer_number=>'MYCUS', last_alliance_product_push_at: '2000-01-01')
  end
  describe :sync do
    it "should call appropriate methods" do
      k = described_class
      f = mock("file")
      f.should_receive(:closed?).and_return false
      f.should_receive(:close!)
      OpenChain::CustomHandler::GenericAllianceProductGenerator.any_instance.should_receive(:sync_fixed_position).and_return(f)
      OpenChain::CustomHandler::GenericAllianceProductGenerator.any_instance.should_receive(:ftp_file).with(f)
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
      expected = [{:len=>15}, {:len=>40}, {:len=>10}, {:len=>2}, {:len=>1}, {:len=>7}, {:len=>1}, {:len=>3}, {:len=>2}, {:len=>15}, {:len=>15}, {:len=>40}, {:len=>11}, {:len=>4}, {:len=>4}, {:len=>4}, {:len=>10}, {:len=>10}, {:len=>3}]
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

  class CustomFieldBuilder
    include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  end
  
  context "with data" do

    def build_custom_fields custom_fields, product = nil
      @custom_definitions ||= {}
      @cd ||= {}

      cdefs = CustomFieldBuilder.prep_custom_definitions custom_fields
      cdefs.each_pair do |code, definition|
        # Push out to 100 chars since that's way longer than any actual field we're using
        value = nil
        if code == :prod_country_of_origin
          # Country of origin has internal field logic only including it if it's 2 chars..respect that
          value = "CN"
        elsif code == :prod_fda_product
          value = true
        else
          value = "#{definition.id}#{definition.label}".ljust(100, "0")
        end
        
        
        @cd[code] = value
        product.update_custom_value! definition, value if product
      end

      @custom_definitions = @custom_definitions.merge cdefs
    end

    before :each do
      @standard_custom_fields = [:prod_country_of_origin, :prod_part_number]

      @fda_custom_fields = [:prod_fda_product, :prod_fda_product_code, :prod_fda_temperature, :prod_fda_uom, :prod_fda_country, :prod_fda_mid, :prod_fda_shipper_id, 
                    :prod_fda_description, :prod_fda_establishment_no, :prod_fda_container_length, :prod_fda_container_width, :prod_fda_container_height, 
                    :prod_fda_contact_name, :prod_fda_contact_phone, :prod_fda_affirmation_compliance]

      @us = Factory(:country,:iso_code=>"US")
      @p = Factory(:product,:importer=>@c,:name=>"MYNAME")
      Factory(:tariff_record,:hts_1=>"1234567890",:classification=>Factory(:classification,:country=>@us,:product=>@p))
    end

    describe "sync_fixed_position" do
      after :each do
        @tmp.unlink if @tmp
      end
      it "should generate output file with FDA info" do
        build_custom_fields (@standard_custom_fields + @fda_custom_fields), @p
        @tmp = described_class.new(@c).sync_fixed_position
        IO.read(@tmp.path).should == "#{@cd[:prod_part_number][0..14]}MYNAME                                  1234567890#{@cd[:prod_country_of_origin][0..1]}Y#{@cd[:prod_fda_product_code][0..6]}#{@cd[:prod_fda_temperature][0]}#{@cd[:prod_fda_uom][0..2]}#{@cd[:prod_fda_country][0..1]}#{@cd[:prod_fda_mid][0..14]}#{@cd[:prod_fda_shipper_id][0..14]}#{@cd[:prod_fda_description][0..39]}#{@cd[:prod_fda_establishment_no][0..10]}#{@cd[:prod_fda_container_length][0..3]}#{@cd[:prod_fda_container_width][0..3]}#{@cd[:prod_fda_container_height][0..3]}#{@cd[:prod_fda_contact_name][0..9]}#{@cd[:prod_fda_contact_phone][0..9]}#{@cd[:prod_fda_affirmation_compliance][0..2]}\n"
        expect(@c.last_alliance_product_push_at.to_date).to eq Time.zone.now.to_date
      end

      it "does not include FDA info if the product does not have FDA fields" do
        build_custom_fields @standard_custom_fields, @p
        build_custom_fields @fda_custom_fields
        @tmp = described_class.new(@c).sync_fixed_position
        IO.read(@tmp.path).should == "#{@cd[:prod_part_number][0..14]}MYNAME                                  1234567890#{@cd[:prod_country_of_origin][0..1]}N                                                                                                                                 \n"
      end

      it "does not include FDA info if the product's fda product flag is not set" do
        build_custom_fields (@standard_custom_fields + @fda_custom_fields), @p
        @p.update_custom_value! @custom_definitions[:prod_fda_product], false
        @tmp = described_class.new(@c).sync_fixed_position
        IO.read(@tmp.path).should == "#{@cd[:prod_part_number][0..14]}MYNAME                                  1234567890#{@cd[:prod_country_of_origin][0..1]}N                                                                                                                                 \n"
      end

      it "transliterates non-ASCII data" do
        build_custom_fields @standard_custom_fields, @p
        # Text taken from Rails transliterate rdoc example
        @p.update_custom_value! @custom_definitions[:prod_part_number], "Ærøskøbing"
        @tmp = described_class.new(@c).sync_fixed_position
        expect(IO.read(@tmp.path)).to start_with "AEroskobing    "
      end
      it "logs an error for non-translatable products and skips the record" do
        build_custom_fields @standard_custom_fields, @p
        @p.update_custom_value! @custom_definitions[:prod_part_number], "Pilcrow ¶"
        error = nil
        StandardError.any_instance.should_receive(:log_me) do 
          error = $!
        end

        # Nothing will have been written so nil is returned.
        expect(described_class.new(@c).sync_fixed_position).to be_nil
        expect(error.message).to eq "Untranslatable Non-ASCII character for Part Number 'Pilcrow ¶' found at string index 8 in product query column 0: 'Pilcrow ¶'."
      end
    end
    describe "query" do
      before :each do
        build_custom_fields @standard_custom_fields, @p
      end

      it "should output correct data" do
        r = ActiveRecord::Base.connection.execute described_class.new(@c).query
        r.count.should == 1
        vals = r.first
        vals[0].should == @p.id
        vals[1].should == @cd[:prod_part_number]
        vals[2].should == "MYNAME"
        vals[3].should == "1234567890"
        vals[4].should == @cd[:prod_country_of_origin]
        vals[5].should == "N"
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
        @p.update_custom_value! @custom_definitions[:prod_part_number], ""
        r = ActiveRecord::Base.connection.execute described_class.new(@c).query
        r.count.should == 0
      end
      it "should not output country of origin if not 2 digits" do
        @p.update_custom_value! @custom_definitions[:prod_country_of_origin], "CHINA"
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
      it "should include N if FDA Product is not included" do
        row = ActiveRecord::Base.connection.execute(described_class.new(@c).query).first
        expect(row[5]).to eq "N"
      end
      it "should include Y if FDA Product is included" do
        build_custom_fields [:prod_fda_product], @p

        row = ActiveRecord::Base.connection.execute(described_class.new(@c).query).first
        expect(row[5]).to eq "Y"
      end
      it "does not include products already synced" do
        @p.sync_records.create! trading_partner: 'Alliance', sent_at: 2.days.ago, confirmed_at: 1.day.ago
        @p.update_column :updated_at, 3.days.ago

        r = ActiveRecord::Base.connection.execute described_class.new(@c).query
        r.count.should == 0
      end
    end
  end

  describe "run_schedulable" do
    it 'uses customer number from ops to run via scheduler' do
      OpenChain::CustomHandler::GenericAllianceProductGenerator.should_receive(:sync) do |c|
        expect(c.id).to eq @c.id
        nil
      end

      OpenChain::CustomHandler::GenericAllianceProductGenerator.run_schedulable({'alliance_customer_number'=>@c.alliance_customer_number})
    end
  end
end
