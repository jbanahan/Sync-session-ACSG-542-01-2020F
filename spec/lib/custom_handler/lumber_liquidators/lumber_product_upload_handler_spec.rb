require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberProductUploadHandler do
  let (:custom_file) {
    custom_file = CustomFile.new attached_file_name: "file.xlsx"
    allow(custom_file).to receive(:path).and_return "/path/to/file.xlsx"
    custom_file
  }
  subject { described_class.new custom_file }
  let (:lumber_master) { Factory(:company, master: true, system_code: "LUMBER")}
  let (:us_lines) {
    [
      ["Article #", "Name", "Old Article #", "HTS 1"],
      [10039527.0, "TRQ King County Knotty Oak 2mm", "2KO-KC", "4418.90.4605"]
    ]
  }
  let (:ca_lines) {
    [
      ["Shipment #", "Delivery", "Item", "Ship-to Party", "Article", "Actual delivery qty", "Description", "Total Weight", "Weight Unit", "Base UOM", "HS Confirmation", "Comments"],
      [265662.0, "860015120", "10", "2001", "10004816", "5", "L-Cleat, 16G, 2”, 1000 pieces, BOSTICH", "20", "LB", "EA", 7317000090.0]
    ]
  }
  let (:us) { Country.where(iso_code: "US").first_or_create! }
  let (:ca) { Country.where(iso_code: "CA").first_or_create! }

  describe "translate_file_line" do

    context "with us lines" do

      it "detects layout using first line" do
        subject.translate_file_line us_lines[0]
        expect(subject.layout_type).to eq :us
      end

      context "with established layout type of 'US'" do

        before :each do
          lumber_master
          us
          subject.translate_file_line us_lines[0]
        end

        it "translates a line to correct format" do
          OfficialTariff.create! country: us, hts_code: "4418904605"

          output = subject.translate_file_line us_lines[1]
          expect(output.length).to eq 1
          line = output.first
          expect(line).to eq ["LUMBER", "000000000010039527", "2KO-KC", "US", "4418904605", "4418904605", 1]
        end

        it "translates lines with invalid tariffs" do
          output = subject.translate_file_line us_lines[1]
          expect(output.length).to eq 1
          line = output.first
          expect(line).to eq ["LUMBER", "000000000010039527", "2KO-KC", "US", "4418904605", nil, 1]
        end
      end
      
    end

    context "with ca lines" do

      it "detects layout using first line" do
        subject.translate_file_line ca_lines[0]
        expect(subject.layout_type).to eq :canada
      end

      context "with established layout type of 'CA'" do

        before :each do
          ca
          lumber_master
          subject.translate_file_line ca_lines[0]
        end

        it "translates a line to correct format" do
          OfficialTariff.create! country: ca, hts_code: "7317000090"
          output = subject.translate_file_line ca_lines[1]
          expect(output.length).to eq 1
          line = output.first
          expect(line).to eq ["LUMBER", "000000000010004816", "CA", "L-Cleat, 16G, 2”, 1000 pieces, BOSTICH", "7317000090", "7317000090", 1]
        end

        it "translates lines with invalid tariffs" do
          output = subject.translate_file_line ca_lines[1]
          expect(output.length).to eq 1
          line = output.first
          expect(line).to eq ["LUMBER", "000000000010004816", "CA", "L-Cleat, 16G, 2”, 1000 pieces, BOSTICH", "7317000090", nil, 1]
        end
      end
    end

    it "rasies an error if invalid format is used" do
      expect {subject.translate_file_line []}.to raise_error "Unable to determine file layout.  All files must have a header row. US files must have 4 columns. CA files must have 12 columns."
    end
  end

  describe "process" do
    let (:user) { Factory(:user) }
   

    before :each do
      lumber_master
    end

    context "with us lines" do
      let (:custom_defintions) { subject.class.prep_custom_definitions [:prod_old_article, :class_proposed_hts] }

      before :each do
        us
        allow(subject).to receive(:foreach).with(custom_file, skip_headers: false, skip_blank_lines: true).and_yield(us_lines[0]).and_yield(us_lines[1])
      end

      it "parses a us file into an imported file" do
        expect_any_instance_of(ImportedFile).to receive(:process).with user
        subject.process user

        f = ImportedFile.first
        expect(f).not_to be_nil
        expect(f.update_mode).to eq "update"
        expect(f.starting_column).to eq 1
        expect(f.starting_row).to eq 1
        expect(f.module_type).to eq "Product"
        expect(f.user).to eq user

        ss = f.search_setup
        expect(ss).not_to be_nil
        expect(ss.name).to eq "US Parts Upload (Do Not Delete or Modify)"
        expect(ss.user).to eq user
        expect(ss.module_type).to eq "Product"

        cdefs = custom_defintions
        uids = ss.search_columns.map(&:model_field_uid).map(&:to_s)

        expect(uids).to eq([
          'prod_imp_syscode',
          'prod_uid',
          cdefs[:prod_old_article].model_field_uid,
          'class_cntry_iso',
          cdefs[:class_proposed_hts].model_field_uid,
          'hts_hts_1',
          'hts_line_number'
        ])
      end
    end

    context "with ca lines" do
      let (:custom_defintions) { subject.class.prep_custom_definitions [:class_proposed_hts, :class_customs_description] }

      before :each do
        ca
        allow(subject).to receive(:foreach).with(custom_file, skip_headers: false, skip_blank_lines: true).and_yield(ca_lines[0]).and_yield(ca_lines[1])
      end

      it "parses a ca file into an imported file" do
        expect_any_instance_of(ImportedFile).to receive(:process).with user
        subject.process user

        f = ImportedFile.first
        expect(f).not_to be_nil
        expect(f).not_to be_nil
        expect(f.update_mode).to eq "update"
        expect(f.starting_column).to eq 1
        expect(f.starting_row).to eq 1
        expect(f.module_type).to eq "Product"
        expect(f.user).to eq user
        
        ss = f.search_setup
        expect(ss).not_to be_nil
        expect(ss.name).to eq "CA Parts Upload (Do Not Delete or Modify)"
        expect(ss.user).to eq user
        expect(ss.module_type).to eq "Product"

        cdefs = custom_defintions
        uids = ss.search_columns.map(&:model_field_uid).map(&:to_s)

        expect(uids).to eq([
          'prod_imp_syscode',
          'prod_uid',
          'class_cntry_iso',
          cdefs[:class_customs_description].model_field_uid,
          cdefs[:class_proposed_hts].model_field_uid,
          'hts_hts_1',
          'hts_line_number'
        ])
      end
    end
  end

  describe "can_view?" do
    let (:user) { Factory(:user, company: lumber_master) }
    let (:master_setup) { double("MasterSetup") }

    before :each do
      allow(MasterSetup).to receive(:get).and_return master_setup
      allow(master_setup).to receive(:custom_feature?).with("Lumber EPD").and_return true
    end

    it "allows master user that can edit products to view" do
      expect(user).to receive(:edit_products?).and_return true
      expect(described_class.can_view? user).to be_truthy
    end

    it "disallows non-master user" do
      u = Factory(:user)
      allow(u).to receive(:edit_products?).and_return true
      expect(described_class.can_view? u).to be_falsey
    end

    it "disallows users that can't edit products" do
      expect(user).to receive(:edit_products?).and_return false
      expect(described_class.can_view? user).to be_falsey
    end

    it "disallows systems with no Lumber EPD report setup" do
      allow(master_setup).to receive(:custom_feature?).with("Lumber EPD").and_return false
      allow(user).to receive(:edit_products?).and_return true
      expect(described_class.can_view? user).to be_falsey
    end
  end

  describe "valid_file?" do
    it "accepts csv files" do
      expect(described_class.valid_file? "file.csv").to be_truthy
    end

    it "accepts xls files" do
      expect(described_class.valid_file? "file.xls").to be_truthy
    end

    it "accepts xlsx files" do
      expect(described_class.valid_file? "file.xlsx").to be_truthy
    end
  end
end