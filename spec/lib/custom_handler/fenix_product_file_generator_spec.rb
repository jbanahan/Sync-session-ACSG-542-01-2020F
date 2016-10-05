require 'spec_helper'

describe OpenChain::CustomHandler::FenixProductFileGenerator do

  let! (:master_setup) {
    ms = stub_master_setup
    allow(ms).to receive(:custom_feature?).with("Full Fenix Product File").and_return true
    ms
  }

  class FenixProductGeneratorCustomDefinitions
    include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

    attr_reader :cdefs

    def initialize
      @cdefs = self.class.prep_custom_definitions [:prod_part_number, :prod_country_of_origin, :class_customs_description, :class_special_program_indicator, :class_cfia_requirement_id, :class_cfia_requirement_version, :class_cfia_requirement_code, :class_ogd_end_use, :class_ogd_misc_id, :class_ogd_origin, :class_sima_code]
    end
  end

  let (:cdefs) {
    FenixProductGeneratorCustomDefinitions.new.cdefs
  }

  before :each do
    @canada = Factory(:country,:iso_code=>'CA')
    @code = 'XYZ'
  end
  describe "generate" do
    it "should find products, make file, and ftp" do
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)
      expect(@h).to receive(:find_products).and_return('y')
      expect(@h).to receive(:make_file).with('y').and_return('z')
      expect(@h).to receive(:ftp_file).with('z').and_return('a')
      expect(@h.generate).to eq('a')
    end
  end

  describe "find_products" do
    before :each do
      @to_find_1 = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>@canada.id)).product
      @to_find_2 = Factory(:tariff_record,:hts_1=>'1234567891',:classification=>Factory(:classification,:country_id=>@canada.id)).product
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)
    end
    it "should find products that need sync and have canadian classifications" do
      expect(@h.find_products.to_a).to eq([@to_find_1,@to_find_2])
    end
    it "should filter on importer_id if given" do
      @to_find_1.update_attributes(:importer_id => 100)
      h = @h.class.new(@code, 'importer_id' => 100)
      expect(h.find_products.to_a).to eq([@to_find_1])
    end
    it "should apply additional_where filters" do
      @to_find_1.update_attributes(:name=>'XYZ')
      h = @h.class.new(@code, 'additional_where' => "products.name = 'XYZ'")
      expect(h.find_products.to_a).to eq([@to_find_1])
    end
    it "should not find products that don't have canada classifications but need sync" do
      different_country_product = Factory(:tariff_record,:hts_1=>'1234567891',:classification=>Factory(:classification)).product
      expect(@h.find_products.to_a).to eq([@to_find_1,@to_find_2])
    end
    it "should not find products that have classification but don't need sync" do
      @to_find_2.update_attributes(:updated_at=>1.hour.ago)
      @to_find_2.sync_records.create!(:trading_partner=>"fenix-#{@code}",:sent_at=>1.minute.ago,:confirmed_at=>1.minute.ago)
      expect(@h.find_products.to_a).to eq([@to_find_1])
    end
  end

  describe "make_file" do
    before :each do
      @p = Factory(:product,:unique_identifier=>'myuid')
      @c = @p.classifications.create!(:country_id=>@canada.id)
      t = @c.tariff_records.create!(:hts_1=>'1234567890')
    end
    after :each do
      @t.unlink if @t
    end

    it "should generate output file with given products" do
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)

      @p.update_custom_value! cdefs[:prod_country_of_origin], "CN"
      @c.update_custom_value! cdefs[:class_customs_description], "Random Product Description"
      @c.update_custom_value! cdefs[:class_special_program_indicator], "10"
      @c.update_custom_value! cdefs[:class_cfia_requirement_id], "ID"
      @c.update_custom_value! cdefs[:class_cfia_requirement_version], "VER"
      @c.update_custom_value! cdefs[:class_cfia_requirement_code], "COD"
      @c.update_custom_value! cdefs[:class_ogd_end_use], "U"
      @c.update_custom_value! cdefs[:class_ogd_misc_id], "M"
      @c.update_custom_value! cdefs[:class_ogd_origin], "O"
      @c.update_custom_value! cdefs[:class_sima_code], "S"

      @t = @h.make_file [@p]
      read = IO.read(@t.path)
      expect(read[0, 15]).to eq "N".ljust(15)
      expect(read[15, 9]).to eq @code.ljust(9)
      expect(read[31, 40]).to eq "myuid".ljust(40)
      expect(read[71, 20]).to eq "1234567890".ljust(20)
      expect(read[135, 50]).to eq "Random Product Description".ljust(50)
      expect(read[341, 3]).to eq "10 "
      expect(read[359, 3]).to eq "CN "
      expect(read[362, 8]).to eq "ID      "
      expect(read[370, 4]).to eq "VER "
      expect(read[374, 6]).to eq "COD   "
      expect(read[380, 3]).to eq "U  "
      expect(read[383, 3]).to eq "M  "
      expect(read[386, 3]).to eq "O  "
      expect(read[389, 2]).to eq "S "
      expect(read).to end_with "\r\n"
    end
    it "should generate output file using part number" do
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code, 'use_part_number'=>true)
      pn_def = CustomDefinition.where(label: "Part Number", module_type: "Product", data_type: "string").first
      @p.update_custom_value! pn_def, "ABC123"

      @t = @h.make_file [@p]
      read = IO.read(@t.path)
      expect(read[31, 40]).to eq "ABC123".ljust(40)
    end
    it "should write sync records with dummy confirmation date" do
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)
      @t = @h.make_file [@p]
      @p.reload
      expect(@p.sync_records.size).to eq(1)
      sr = @p.sync_records.find_by_trading_partner("fenix-#{@code}")
      expect(sr.sent_at).to be < sr.confirmed_at
      expect(sr.confirmation_file_name).to eq("Fenix Confirmation")
    end

    it "skips adding country of origin if instructed" do
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code, 'suppress_country'=>true)
      # Verify custom definition for country of origin wasn't created
      coo_def = CustomDefinition.where(label: "Country Of Origin", module_type: "Product", data_type: "string").first
      expect(coo_def).to be_nil
      coo_def = CustomDefinition.create!(label: "Country Of Origin", module_type: "Product", data_type: "string")

      @p.update_custom_value! coo_def, "CN"
      @t = @h.make_file [@p]
      read = IO.read(@t.path)
      expect(read[0, 15]).to eq "N".ljust(15)
      expect(read[15, 9]).to eq @code.ljust(9)
      expect(read[31, 40]).to eq "myuid".ljust(40)
      expect(read[71, 10]).to eq "1234567890".ljust(10)
      expect(read[359, 3]).to eq "   "
    end

    it "skips adding description if instructed" do
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code, 'suppress_description'=>true)
      desc_def = CustomDefinition.where(label: "Customs Description", module_type: "Classification", data_type: "string").first
      expect(desc_def).to be_nil
      desc_def = CustomDefinition.create!(label: "Customs Description", module_type: "Classification", data_type: "string")
      @c.update_custom_value! desc_def, "Random Product Description"
      @t = @h.make_file [@p]
      read = IO.read(@t.path)
      expect(read[15, 9]).to eq @code.ljust(9)
      # This would be where description is if we turned it on..should be blank
      expect(read[135, 50]).to eq "".ljust(50)
    end

    it "only uses the first hts line" do
      h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)
      t2 = Factory(:tariff_record, hts_1: "12345", classification: @c)
      @t = h.make_file [@p]
      read = IO.read(@t.path)
      expect(read.lines.length).to eq 1
      expect(read[71, 10]).to eq @c.tariff_records.first.hts_1.ljust(10)
    end

    it "cleanses forbidden characters" do
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)
      coo_def = CustomDefinition.where(label: "Country Of Origin", module_type: "Product", data_type: "string").first
      desc_def = CustomDefinition.where(label: "Customs Description", module_type: "Classification", data_type: "string").first

      @p.update_custom_value! coo_def, "CN"
      @c.update_custom_value! desc_def, "Random Product !"
      @t = @h.make_file [@p]
      read = IO.read(@t.path)
      expect(read[0, 15]).to eq "N".ljust(15)
      expect(read[15, 9]).to eq @code.ljust(9)
      expect(read[31, 40]).to eq "myuid".ljust(40)
      expect(read[71, 20]).to eq "1234567890".ljust(20)
      expect(read[135, 50]).to eq "Random Product".ljust(50)
      expect(read[359, 3]).to eq "CN "
      expect(read).to end_with "\r\n"
    end

    it "skips sync record creation if instructed" do
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)
      @t = @h.make_file [@p], false
      @p.reload
      expect(@p.sync_records.size).to eq(0)
    end

    it "strips leading zeros if instructed" do
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code, 'strip_leading_zeros' => true)
      @p.update_attributes! unique_identifier: "00000#{@p.unique_identifier}"
      @t = @h.make_file [@p]
      read = IO.read(@t.path)
      expect(read[31, 40]).to eq "myuid".ljust(40)
    end

    it "transliterates to windows encoding" do
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)
      desc_def = CustomDefinition.where(label: "Customs Description", module_type: "Classification", data_type: "string").first
      # Description taken from actual data that's failing to correctly transfer
      @c.update_custom_value! desc_def, "Brad Nail, 23G, PIN, Brass, 1”, 6000 pcs"

      @t = @h.make_file [@p]
      read = IO.read(@t.path, encoding: "WINDOWS-1252")
      expect(read[135, 50]).to eq "Brad Nail, 23G, PIN, Brass, 1”, 6000 pcs".ljust(50)
    end

    it "logs an error if data can't be encoded to windows encoding" do
      # Use hebrew chars, since the windows encoding in use in Fenix is a latin one, it can't encode them
      @p.update_attributes! unique_identifier: "בדיקה אם נרשם"

      @t = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code).make_file [@p]
      expect(IO.read(@t.path)).to be_blank
      expect(ErrorLogEntry.first.additional_messages_json).to match(/could not be sent to Fenix/)
    end

    it "disables all 'extra' fields if custom feature is not enabled" do
      # Set values up for the product, so we know they're actually be skipped when generated
      allow(master_setup).to receive(:custom_feature?).with("Full Fenix Product File").and_return false

      @p.update_custom_value! cdefs[:prod_country_of_origin], "CN"
      @c.update_custom_value! cdefs[:class_customs_description], "Random Product Description"
      @c.update_custom_value! cdefs[:class_special_program_indicator], "10"
      @c.update_custom_value! cdefs[:class_cfia_requirement_id], "ID"
      @c.update_custom_value! cdefs[:class_cfia_requirement_version], "VER"
      @c.update_custom_value! cdefs[:class_cfia_requirement_code], "COD"
      @c.update_custom_value! cdefs[:class_ogd_end_use], "U"
      @c.update_custom_value! cdefs[:class_ogd_misc_id], "M"
      @c.update_custom_value! cdefs[:class_ogd_origin], "O"
      @c.update_custom_value! cdefs[:class_sima_code], "S"
      
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)
      
      @t = @h.make_file [@p]
      read = IO.read(@t.path)
      expect(read[0, 15]).to eq "N".ljust(15)
      expect(read[15, 9]).to eq @code.ljust(9)
      expect(read[31, 40]).to eq "myuid".ljust(40)
      expect(read[71, 20]).to eq "1234567890".ljust(20)
      expect(read[135, 50]).to eq "Random Product Description".ljust(50)
      expect(read[341, 3]).to eq "   "
      expect(read[359, 3]).to eq "CN "
      expect(read[362, 8]).to eq "        "
      expect(read[370, 4]).to eq "    "
      expect(read[374, 6]).to eq "      "
      expect(read[380, 3]).to eq "   "
      expect(read[383, 3]).to eq "   "
      expect(read[386, 3]).to eq "   "
      expect(read[389, 2]).to eq "  "
      expect(read).to end_with "\r\n"
    end
  end

  describe "ftp file" do
    it "should send ftp file to ftp2 server and delete it" do
      t = double("tempfile")
      expect(t).to receive(:path).and_return('/tmp/a.txt')
      expect(t).to receive(:unlink)
      expect(FtpSender).to receive(:send_file,).with('ftp2.vandegriftinc.com','VFITRack','RL2VFftp',t,{:folder=>'to_ecs/fenix_products/',:remote_file_name=>'a.txt'})
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)
      @h.ftp_file t
    end

    it "uses the given output directory when sending" do
      t = double("tempfile")
      expect(t).to receive(:path).and_return('/tmp/a.txt')
      expect(t).to receive(:unlink)
      expect(FtpSender).to receive(:send_file,).with('ftp2.vandegriftinc.com','VFITRack','RL2VFftp',t,{:folder=>'to_ecs/fenix_products/subdir',:remote_file_name=>'a.txt'})
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code, {'output_subdirectory' => "subdir"})
      @h.ftp_file t
    end
  end

  describe "run_schedulable" do
    it "should pass in all possible options when provided" do
      hash = {"fenix_customer_code" => "XYZ", "importer_id" => "23",
          "use_part_number" => "false", "additional_where" => "5 > 3", 'suppress_country'=>true}
      fpfg = OpenChain::CustomHandler::FenixProductFileGenerator.new("XYZ",hash)

      expect(OpenChain::CustomHandler::FenixProductFileGenerator).to receive(:new).with("XYZ",hash).and_return(fpfg)
      expect_any_instance_of(OpenChain::CustomHandler::FenixProductFileGenerator).to receive(:generate)
      OpenChain::CustomHandler::FenixProductFileGenerator.run_schedulable(hash)
    end

    it "should not fail on missing options" do
      hash = {"fenix_customer_code" => "XYZ", "importer_id" => "23"}
      fpfg = OpenChain::CustomHandler::FenixProductFileGenerator.new("XYZ",hash)

      expect(OpenChain::CustomHandler::FenixProductFileGenerator).to receive(:new).with("XYZ",hash).and_return(fpfg)
      expect_any_instance_of(OpenChain::CustomHandler::FenixProductFileGenerator).to receive(:generate)
      OpenChain::CustomHandler::FenixProductFileGenerator.run_schedulable(hash)
    end
  end
end
