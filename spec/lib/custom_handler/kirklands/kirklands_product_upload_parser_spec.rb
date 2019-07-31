describe OpenChain::CustomHandler::Kirklands::KirklandsProductUploadParser do
  let (:file_contents) {
    [
      [12392256, "VendItem-Num", "Yep it's a product of some kind.", "Rubber and some metal", "CN", "yes", 28.5, 9403200050, 2468101214,
        "yes", "FOO\n FD1", "yes", "yes", "yes", 12341234, "yes", 23452345],
      [12392234, nil, "Yep it's a product of some other kind. With a longer descrption", "Rubber and some metal", "CN",
        nil, 28.5, 9403608081, nil, "N", nil, "Y", "N", "N", nil, "Y", nil]
    ]
  }

  let (:custom_file) {
    custom_file = CustomFile.new attached_file_name: "file.xlsx"
    allow(custom_file).to receive(:path).and_return "/path/to/file.xlsx"
    custom_file
  }
  let! (:master_company) {Factory(:importer, name: "Kirklands", master: true, system_code: "KLANDS")}
  let (:user) { Factory(:user) }
  let (:countries) { [Factory(:country, iso_code: "US", import_location: true), Factory(:country, iso_code: "CN", import_location: true)] }

  subject {described_class.new custom_file }

  describe "process" do
    before :each do
      countries
    end

    let (:custom_defintions) {
      subject.class.prep_custom_definitions [ :prod_part_number, :prod_long_description, :prod_material, :prod_country_of_origin, :prod_additional_doc,
      :prod_fob_price, :prod_fda_product, :prod_fda_code, :prod_tsca, :prod_lacey, :prod_add, :prod_add_case, :prod_cvd, :prod_cvd_case ]
    }

    let (:search_column_uids) {
      countries
      cdefs = custom_defintions

      [
        'prod_imp_syscode',
        'prod_uid',
        cdefs[:prod_part_number].model_field_uid.to_s,
        cdefs[:prod_long_description].model_field_uid.to_s,
        cdefs[:prod_material].model_field_uid.to_s,
        cdefs[:prod_country_of_origin].model_field_uid.to_s,
        cdefs[:prod_additional_doc].model_field_uid.to_s,
        cdefs[:prod_fob_price].model_field_uid.to_s,
        'hts_hts_1',
        'hts_hts_2',
        cdefs[:prod_fda_product].model_field_uid.to_s,
        cdefs[:prod_fda_code].model_field_uid.to_s,
        cdefs[:prod_tsca].model_field_uid.to_s,
        cdefs[:prod_lacey].model_field_uid.to_s,
        cdefs[:prod_add].model_field_uid.to_s,
        cdefs[:prod_add_case].model_field_uid.to_s,
        cdefs[:prod_cvd].model_field_uid.to_s,
        cdefs[:prod_cvd_case].model_field_uid.to_s,
        'hts_line_number',
        'class_cntry_iso'
      ]
    }

    it "processes a file, creates a search_setup, imports a file against the setup" do
      expect(subject).to receive(:foreach).with(custom_file, skip_headers: true, skip_blank_lines:true).and_yield(file_contents[0])
      expect_any_instance_of(ImportedFile).to receive(:process).with user
      # Don't worry about how the file contents are translated...just care that it is happening.
      # We'll test this method specifically elsewhere, since it's a pain the try and test as part of the process method testing
      expect(subject).to receive(:translate_file_line).with(file_contents[0]).and_return [["line"]]

      subject.process user

      f = ImportedFile.first
      expect(f.update_mode).to eq "any"
      expect(f.starting_row).to eq 1
      expect(f.starting_column).to eq 1
      expect(f.module_type).to eq "Product"
      expect(f.user).to eq user

      ss = f.search_setup
      expect(ss).not_to be_nil
      expect(ss.name).to eq "Kirklands Products Upload (Do Not Delete or Modify!)"
      expect(ss.user).to eq user
      expect(ss.module_type).to eq "Product"

      # Make sure the expected search columns are created and in the expected order
      cdefs = custom_defintions
      uids = ss.search_columns.map(&:model_field_uid).map(&:to_s)

      expect(uids).to eq search_column_uids
    end
  end

  describe "translate_file_line" do

    it "translates a line into the expected search setup format" do
      line = subject.translate_file_line file_contents[0]
      expect(line).to eq ["KLANDS", "12392256", "VendItem-Num", "Yep it's a product of some kind.", "Rubber and some metal", "CN", true, 28.5, "9403200050", "2468101214", true, "FOO\n FD1", true, true, true, "12341234", true, "23452345", 1, "US"]
      line = subject.translate_file_line file_contents[1]
      expect(line).to eq ["KLANDS", "12392234", "", "Yep it's a product of some other kind. With a longer descrption", "Rubber and some metal", "CN", nil, 28.5, "9403608081", "", false, "", true, false, false, "", true, "", 1, "US"]
    end
  end

  describe "can_view?" do
    it "allows user" do
      ms = double("MasterSetup")
      expect(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:custom_feature?).with("Kirklands").and_return true

      user = Factory(:master_user)
      expect(user).to receive(:edit_products?).and_return true

      expect(described_class.can_view? user).to be_truthy
    end

    it "disallows users that can't edit products" do
      ms = double("MasterSetup")
      expect(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:custom_feature?).with("Kirklands").and_return true

      user = Factory(:master_user)
      expect(user).to receive(:edit_products?).and_return false

      expect(described_class.can_view? user).to be_falsey
    end

    it "disallows users that aren't master users" do
      ms = double("MasterSetup")
      expect(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:custom_feature?).with("Kirklands").and_return true

      expect(described_class.can_view? user).to be_falsey
    end

    it "disallows when kirklands is not enabled" do
      ms = double("MasterSetup")
      expect(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:custom_feature?).with("Kirklands").and_return false

      user = Factory(:master_user)
      allow(user).to receive(:edit_products?).and_return true
      expect(described_class.can_view? user).to be_falsey
    end
  end
end
