describe OpenChain::CustomHandler::Polo::PoloGlobalFrontEndProductParser do

  before :all do 
    described_class.new.cdefs
  end

  after :all do 
    CustomDefinition.destroy_all
  end

  describe "parse_line" do
    let (:row) { 
      [
        "200002644189", "200", "002644", "999", "B9990X004", "LAUREN RALPH LAUREN", "W LRL APP MISSY RTW", 
        "WOMENS", "BOTTOMS", "DENIM", "NO SUBCLASS", 'CLS BOOT 29"', 'CLS BOOT 29"', 'CLASSIC BOOTCUT (LYN) 29"', 
        "STR WSTPT DNM", "HEEL", "INACTIVE", "NOT EXPORTED"
      ]
    }

    let (:user) { Factory(:user) }
    let (:cdefs) { subject.cdefs }

    it "parses a product from a CSV'ized row" do
      p = subject.parse_line row, user, "file.txt"

      expect(p).not_to be_nil
      expect(p.unique_identifier).to eq "200002644189"
      expect(p.custom_value(cdefs[:digit_style_6])).to eq "002644"
      expect(p.custom_value(cdefs[:season])).to eq "999"
      expect(p.custom_value(cdefs[:msl_board_number])).to eq "B9990X004"
      expect(p.custom_value(cdefs[:sap_brand_name])).to eq "LAUREN RALPH LAUREN"
      expect(p.custom_value(cdefs[:rl_merchandise_division_description])).to eq "W LRL APP MISSY RTW"
      expect(p.custom_value(cdefs[:gender_desc])).to eq "WOMENS"
      expect(p.custom_value(cdefs[:product_category])).to eq "BOTTOMS"
      expect(p.custom_value(cdefs[:product_class_description])).to eq "DENIM"
      expect(p.custom_value(cdefs[:ax_subclass])).to eq "NO SUBCLASS"
      expect(p.custom_value(cdefs[:rl_short_description])).to eq 'CLS BOOT 29"'
      expect(p.custom_value(cdefs[:rl_long_description])).to eq 'CLASSIC BOOTCUT (LYN) 29"'
      expect(p.custom_value(cdefs[:merchandising_fabrication])).to eq "STR WSTPT DNM"
      expect(p.custom_value(cdefs[:heel_height])).to eq "HEEL"
      expect(p.custom_value(cdefs[:material_status])).to eq "INACTIVE"
      expect(p.custom_value(cdefs[:ax_export_status])).to eq "NOT EXPORTED"

      expect(p.entity_snapshots.length).to eq 1
      s = p.entity_snapshots.first
      expect(s.user).to eq user
      expect(s.context).to eq "file.txt"
    end

    it "updates a product" do
      product = Product.create! unique_identifier: "200002644189"
      p = subject.parse_line row, user, "file.txt"

      expect(p).to eq product
      expect(p.entity_snapshots.length).to eq 1
    end

    it "does not save or snapshot if product is unchanged" do
      p = Product.create! unique_identifier: "200002644189"      
      p.update_custom_value! cdefs[:digit_style_6], "002644"
      p.update_custom_value! cdefs[:season], "999"
      p.update_custom_value! cdefs[:msl_board_number], "B9990X004"
      p.update_custom_value! cdefs[:sap_brand_name], "LAUREN RALPH LAUREN"
      p.update_custom_value! cdefs[:rl_merchandise_division_description], "W LRL APP MISSY RTW"
      p.update_custom_value! cdefs[:gender_desc], "WOMENS"
      p.update_custom_value! cdefs[:product_category], "BOTTOMS"
      p.update_custom_value! cdefs[:product_class_description], "DENIM"
      p.update_custom_value! cdefs[:ax_subclass], "NO SUBCLASS"
      p.update_custom_value! cdefs[:rl_short_description], 'CLS BOOT 29"'
      p.update_custom_value! cdefs[:rl_long_description], 'CLASSIC BOOTCUT (LYN) 29"'
      p.update_custom_value! cdefs[:merchandising_fabrication], "STR WSTPT DNM"
      p.update_custom_value! cdefs[:heel_height], "HEEL"
      p.update_custom_value! cdefs[:material_status], "INACTIVE"
      p.update_custom_value! cdefs[:ax_export_status], "NOT EXPORTED"

      expect_any_instance_of(Product).not_to receive(:save!)
      expect(subject.parse_line row, user, "file.txt").to be_nil
    end
  end

  describe "parse_file" do
    subject { described_class }
    let (:log) { InboundFile.new }
    let (:data) { '200002644189|200|002644|999|B9990X004|LAUREN RALPH LAUREN|W LRL APP MISSY RTW|WOMENS|BOTTOMS|DENIM|NO SUBCLASS|CLS BOOT 29"|CLS BOOT 29"|CLASSIC BOOTCUT (LYN) 29"|STR WSTPT DNM||INACTIVE|NOT EXPORTED' }

    it "parses file data" do
      expect { subject.parse_file data, log, {key: "file.txt"}}.to change { Product.count }.from(0).to(1)

      p = Product.where(unique_identifier: "200002644189").first
      expect(p).not_to be_nil

      expect(p.entity_snapshots.length).to eq 1
      s = p.entity_snapshots.first
      expect(s.user).to eq User.integration
      expect(s.context).to eq "file.txt"
    end
  end

  describe "material_status_value" do
    let (:cdefs) {
      subject.cdefs
    }

    let (:rule) {
      FieldValidatorRule.new module_type: "Product", one_of: "Active\nInactive", model_field_uid: cdefs[:material_status].model_field_uid
    }

    before :each do 
      expect(subject).to receive(:field_validator_rule).with(:material_status).and_return rule
    end

    it "returns Inactive" do
      expect(subject.material_status_value "InAcTive").to eq "InAcTive"
    end

    it "returns Active" do
      expect(subject.material_status_value "AcTive").to eq "AcTive"
    end

    it "returns nil for any other value" do
      expect(subject.material_status_value "Not AcTive").to be_nil
    end
  end

  describe "ax_export_status_value" do
    let (:cdefs) {
      subject.cdefs
    }

    let (:rule) {
      FieldValidatorRule.new module_type: "Product", one_of: "Exported\nSubmitted\nNot Exported", model_field_uid: cdefs[:ax_export_status].model_field_uid
    }

    before :each do 
      expect(subject).to receive(:field_validator_rule).with(:ax_export_status).and_return rule
    end

    it "returns Exported" do
      expect(subject.ax_export_status_value "Exported").to eq "Exported"
    end

    it "returns Submitted" do
      expect(subject.ax_export_status_value "Submitted").to eq "Submitted"
    end

    it "returns Not Exported" do
      expect(subject.ax_export_status_value "Not Exported").to eq "Not Exported"
    end

    it "returns nil for any other value" do
      expect(subject.ax_export_status_value "Not Submitted").to be_nil
    end
  end
end