require 'spec_helper'

describe OpenChain::CustomHandler::Advance::AdvancePartsUploadParser do

  let (:file_contents) {
    # Taken from an actual file..
    [
      [10692256.0, "AC965T", "INA", "INAAC965T", "Interior Accessories", "FLOOR MATS & CARPET", "RUBBER", "4-PC SET", "FLOOR MAT TAN 1 EA ATOCF", 4016910000.0, "2.70%", 4016910011.0, "7.00%", "$2.28", 4.0]
    ]
  }

  let (:cq) { Factory(:importer, system_code: "CQ") }
  let (:advance) { Factory(:importer, system_code: "ADVANCE") }
  let (:custom_file) {
    custom_file = CustomFile.new attached_file_name: "file.xlsx"
    custom_file.stub(:path).and_return "/path/to/file.xlsx"
    custom_file
  }
  let (:user) { Factory(:user) }
  let (:countries) { [Factory(:country, iso_code: "US", import_location: true), Factory(:country, iso_code: "CA", import_location: true)]}

  subject {described_class.new custom_file }
  

  describe "process" do
    before :each do
      countries
    end

    let (:custom_defintions) {
      subject.class.prep_custom_definitions [:prod_part_number, :prod_short_description, :prod_units_per_set, :class_customs_description, :prod_sku_number]
    }

    let (:search_column_uids) {
      countries
      cdefs = custom_defintions

      [
        'prod_imp_syscode',
        'prod_uid',
        cdefs[:prod_part_number].model_field_uid.to_s,
        cdefs[:prod_sku_number].model_field_uid.to_s,
        cdefs[:prod_short_description].model_field_uid.to_s,
        'prod_name',
        cdefs[:prod_units_per_set].model_field_uid.to_s,
        'class_cntry_iso',
        cdefs[:class_customs_description].model_field_uid.to_s,
        "*fhts_1_#{countries.first.id}",
        "*fhts_1_#{countries.second.id}",
      ]
    }

    it "processes a file, creates a search_setup, imports a file against the setup" do
      subject.should_receive(:foreach).with(custom_file, skip_headers: true, skip_blank_lines:true).and_yield(file_contents[0])
      ImportedFile.any_instance.should_receive(:process).with user
      # Don't worry about how the file contents are translated...just care that it is happening.
      # We'll test this method specifically elsewhere, since it's a pain the try and test as part of the process method testing
      subject.should_receive(:translate_file_line).with(file_contents[0]).and_return [["line"]]

      subject.process user

      f = ImportedFile.first
      expect(f.update_mode).to eq "any"
      expect(f.starting_row).to eq 1
      expect(f.starting_column).to eq 1
      expect(f.module_type).to eq "Product"
      expect(f.user).to eq user

      ss = f.search_setup
      expect(ss).not_to be_nil
      expect(ss.name).to eq "ADVAN/CQ Parts Upload (Do Not Delete or Modify!)"
      expect(ss.user).to eq user
      expect(ss.module_type).to eq "Product"

      # Make sure the expected search columns are created and in the expected order
      cdefs = custom_defintions
      uids = ss.search_columns.map(&:model_field_uid).map(&:to_s)

      expect(uids).to eq search_column_uids
    end

    it "reuses existing search setup" do
      ss = SearchSetup.create! name:  "ADVAN/CQ Parts Upload (Do Not Delete or Modify!)", user_id: user.id, module_type: "Product"
      search_column_uids.each {|uid| ss.search_columns.create! model_field_uid: uid }

      subject.should_receive(:foreach).with(custom_file, skip_headers: true, skip_blank_lines:true).and_yield(file_contents[0])
      ImportedFile.any_instance.should_receive(:process).with user
      subject.should_receive(:translate_file_line).with(file_contents[0]).and_return [["line"]]

      subject.process user

      f = ImportedFile.first
      expect(f.search_setup).to eq ss
    end

    it "raises an error if the search_setup exists without the expected columns" do
      ss = SearchSetup.create! name:  "ADVAN/CQ Parts Upload (Do Not Delete or Modify!)", user_id: user.id, module_type: "Product"
      subject.should_receive(:foreach).with(custom_file, skip_headers: true, skip_blank_lines:true).and_yield(file_contents[0])
      subject.should_receive(:translate_file_line).with(file_contents[0]).and_return [["line"]]

      subject.process user

      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "Unable to process file file.xlsx due to the following error:<br>Expected to find the field 'Importer System Code' in column 1, but found field 'blank' instead."
    end
  end

  describe "translate_file_line" do

    it "translates a line into the expected search setup format" do
      lines = subject.translate_file_line file_contents[0]
      expect(lines.length).to eq 2

      line = lines.first
      expect(line).to eq ["ADVAN", "ADVAN-10692256", "10692256", "", "AC965T", "FLOOR MAT TAN 1 EA ATOCF", 4, "US", "", "4016910000", "4016910011"]
      line = lines.second
      expect(line).to eq ["CQ", "CQ-INAAC965T", "INAAC965T", "10692256", "AC965T", "FLOOR MAT TAN 1 EA ATOCF", 4, "CA", "FLOOR MAT TAN 1 EA ATOCF", "4016910000", "4016910011"]
    end

    it "excludes advan line if missing first column data" do
      file_contents[0][0] = ""
      lines = subject.translate_file_line file_contents[0]
      expect(lines.length).to eq 1

      line = lines.first
      expect(line).to eq ["CQ", "CQ-INAAC965T", "INAAC965T", "", "AC965T", "FLOOR MAT TAN 1 EA ATOCF", 4, "CA", "FLOOR MAT TAN 1 EA ATOCF", "4016910000", "4016910011"]
    end

    it "excludes CQ line if missing third column data" do
      file_contents[0][3] = ""
      lines = subject.translate_file_line file_contents[0]
      expect(lines.length).to eq 1

      line = lines.first
      expect(line).to eq ["ADVAN", "ADVAN-10692256", "10692256", "", "AC965T", "FLOOR MAT TAN 1 EA ATOCF", 4, "US", "", "4016910000", "4016910011"]
    end
  end

  describe "can_view?" do
    it "allows user" do
      ms = double("MasterSetup")
      MasterSetup.should_receive(:get).and_return ms
      ms.stub(:custom_feature?).with("alliance").and_return true

      user = Factory(:master_user)
      user.should_receive(:edit_products?).and_return true

      expect(described_class.can_view? user).to be_true
    end

    it "disallows users that can't edit products" do
      ms = double("MasterSetup")
      MasterSetup.should_receive(:get).and_return ms
      ms.stub(:custom_feature?).with("alliance").and_return true

      user = Factory(:master_user)
      user.should_receive(:edit_products?).and_return false

      expect(described_class.can_view? user).to be_false
    end

    it "disallows users that aren't master users" do
      ms = double("MasterSetup")
      MasterSetup.should_receive(:get).and_return ms
      ms.stub(:custom_feature?).with("alliance").and_return true

      expect(described_class.can_view? user).to be_false
    end

    it "disallows when alliance is not enabled" do
      ms = double("MasterSetup")
      MasterSetup.should_receive(:get).and_return ms
      ms.stub(:custom_feature?).with("alliance").and_return false

      user = Factory(:master_user)
      user.stub(:edit_products?).and_return true
      expect(described_class.can_view? user).to be_false
    end
  end

end