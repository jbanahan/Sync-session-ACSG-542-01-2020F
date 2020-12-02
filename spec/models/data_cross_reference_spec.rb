describe DataCrossReference do

  context "hash_for_type" do
    subject { described_class }

    it "finds all for reference" do
      csv = "k,v\nk2,v2"
      subject.load_cross_references csv, 'xref_type'
      subject.create!(key: 'ak', value: 'av', cross_reference_type: 'xrt')
      expect(subject.hash_for_type('xref_type')).to eq({'k' => 'v', 'k2' => 'v2'})
    end

    it "finds xrefs only for given company" do
      subject.load_cross_references "k,v", 'xref_type', 1
      subject.load_cross_references "k,v", 'xref_type', 2
      expect(subject.hash_for_type('xref_type')).to eq({'k' => 'v'})
    end
  end

  context "get_all_pairs" do
    it "gets all pairs for a cross reference type" do
      described_class.create!(key: 'a', value: 'b', cross_reference_type: 'x')
      described_class.create!(key: 'c', value: 'd', cross_reference_type: 'x')
      described_class.create!(key: 'dontfind', value: 'd', cross_reference_type: 'z')
      h = {'a' => 'b', 'c' => 'd'}
      expect(described_class.get_all_pairs('x')).to eq h
    end
  end

  context "load_cross_references" do
    it "loads csv cross reference data from an IO object" do
      # Make sure we're also updating existing xrefs
      described_class.create! company_id: 1, key: "key2", value: "", cross_reference_type: 'xref_type'
      csv = "key,value\nkey2,value2\n"

      described_class.load_cross_references csv, 'xref_type', 1

      xrefs = described_class.where(company_id: 1, cross_reference_type: 'xref_type').order("created_at ASC, id ASC")
      expect(xrefs.length).to eq(2)
      expect(xrefs.first.key).to eq("key2")
      expect(xrefs.first.value).to eq("value2")

      expect(xrefs.last.key).to eq("key")
      expect(xrefs.last.value).to eq("value")
    end
  end

  context "jjill_order_fingerprint" do
    it "finds" do
      described_class.create! key: 1, value: 'ABCDEFG', cross_reference_type: described_class::JJILL_ORDER_FINGERPRINT
      o = Order.new
      o.id = 1
      expect(described_class.find_jjill_order_fingerprint(o)).to eq 'ABCDEFG'
    end

    it "creates" do
      o = Order.new
      o.id = 1
      described_class.create_jjill_order_fingerprint! o, 'ABCDEFG'
      expect(described_class.find_jjill_order_fingerprint(o)).to eq 'ABCDEFG'
    end
  end

  context "lenox_item_master_hash" do
    it "finds" do
      described_class.create! key: 'partno', value: 'ABCDEFG', cross_reference_type: described_class::LENOX_ITEM_MASTER_HASH
      expect(described_class.find_lenox_item_master_hash('partno')).to eq 'ABCDEFG'
    end

    it "creates" do
      described_class.create_lenox_item_master_hash! 'part_no', 'hashval'
      expect(described_class.where(key: 'part_no', value: 'hashval', cross_reference_type: described_class::LENOX_ITEM_MASTER_HASH).count).to eq 1
    end
  end

  context "lenox_hts_fingerprint" do
    it "finds" do
      described_class.create! key: described_class.make_compound_key(1, 'US'), value: '9801001010', cross_reference_type: described_class::LENOX_HTS_FINGERPRINT
      expect(described_class.find_lenox_hts_fingerprint(1, 'US')).to eq '9801001010'
    end

    it "creates" do
      described_class.create_lenox_hts_fingerprint! 1, 'US', '9801001010'
      expect(described_class.where(key: described_class.make_compound_key(1, 'US'),
                                   value: '9801001010',
                                   cross_reference_type: described_class::LENOX_HTS_FINGERPRINT).count).to eq 1
    end
  end

  context "find_ascena_brand" do
    before do
      described_class.create!(key: "justice", value: "JST", cross_reference_type: DataCrossReference::ASCE_BRAND)
    end

    it "finds an ascena brand from the department" do
      expect(described_class.find_ascena_brand('justice')).to eq('JST')
    end

    it "does not care about capitalization" do
      # Just in case we get odd capitalization, we want to ignore that entirely
      expect(described_class.find_ascena_brand('JusTice')).to eq('JST')
    end
  end

  context "find_rl_profit_center" do
    it "finds an rl profit center from the brand code" do
      company = create(:importer)
      described_class.create! key: "brand", value: "profit center", cross_reference_type: DataCrossReference::RL_BRAND_TO_PROFIT_CENTER, company_id: company.id

      expect(described_class.find_rl_profit_center_by_brand(company.id, 'brand')).to eq "profit center"
    end
  end

  context "find_rl_brand" do
    it "finds an rl brand code from PO number" do
      described_class.create! key: "po#", value: "brand", cross_reference_type: DataCrossReference::RL_PO_TO_BRAND

      expect(described_class.find_rl_brand_by_po('po#')).to eq("brand")
    end
  end

  context "find_ua_plant_to_iso" do
    it "finds" do
      described_class.create!(key: 'x', value: 'y', cross_reference_type: described_class::UA_PLANT_TO_ISO)
      expect(described_class.find_ua_plant_to_iso('x')).to eq('y')
    end
  end

  context "find_ua_country_by_site" do
    it "finds" do
      described_class.create!(key: 'x', value: 'y', cross_reference_type: described_class::UA_SITE_TO_COUNTRY)
      expect(described_class.find_ua_country_by_site('x')).to eq('y')
    end
  end

  context "find_ua_winshuttle_fingerprint" do
    it "finds" do
      described_class.create!(key: described_class.make_compound_key('x', 'y', 'z'), value: 'y', cross_reference_type: described_class::UA_WINSHUTTLE_FINGERPRINT)
      expect(described_class.find_ua_winshuttle_fingerprint('x', 'y', 'z')).to eq('y')
    end
  end

  describe "create_ua_winshuttle_fingerprint!" do
    it "creates fingerprints" do
      described_class.create_ua_winshuttle_fingerprint! 'x', 'y', 'z', 'fingerprint'
      expect(described_class.find_ua_winshuttle_fingerprint('x', 'y', 'z')).to eq "fingerprint"
    end

    it "uses existing fingerprints" do
      xref = described_class.create_ua_winshuttle_fingerprint! 'x', 'y', 'z', 'fingerprint'
      new_xref = described_class.create_ua_winshuttle_fingerprint! 'x', 'y', 'z', 'fingerprint'
      expect(xref.id).to eq new_xref.id
    end
  end

  context "find_ua_material_color_plant" do
    it "finds" do
      described_class.create!(key: 'x-y-z', value: 'a', cross_reference_type: described_class::UA_MATERIAL_COLOR_PLANT)
      expect(described_class.find_ua_material_color_plant('x', 'y', 'z')).to eq('a')
    end
  end

  context "create_ua_material_color_plant!" do
    it "creates" do
      described_class.create_ua_material_color_plant! 'x', 'y', 'z'
      expect(described_class.find_ua_material_color_plant('x', 'y', 'z')).to eq('1')
    end
  end

  context "add_xref!" do
    it "adds" do
      d = described_class.add_xref! described_class::UA_PLANT_TO_ISO, 'x', 'y', 1
      d = described_class.find d.id
      expect(d.cross_reference_type).to eq(described_class::UA_PLANT_TO_ISO)
      expect(d.key).to eq('x')
      expect(d.value).to eq('y')
      expect(d.company_id).to eq(1)
    end
  end

  describe "find_us_hts_to_ca" do
    it "finds" do
      c = create(:company, alliance_customer_number: "ACME")
      described_class.create!(key: '1111111111', value: '2222222222', cross_reference_type: described_class::US_HTS_TO_CA, company: c)
      expect(described_class.find_us_hts_to_ca('1111111111', c.id)).to eq '2222222222'
    end
  end

  describe "create_us_hts_to_ca!" do
    let(:co) { create(:company, alliance_customer_number: "ACME") }

    it "creates" do
      described_class.create_us_hts_to_ca! '1111111111', '2222222222', co.id
      cr = described_class.first
      expect(cr.key).to eq '1111111111'
      expect(cr.value).to eq '2222222222'
      expect(cr.company).to eq co
    end

    it "strips dots" do
      described_class.create_us_hts_to_ca! '1111.11.1111', '2222.22.2222', co.id
      cr = described_class.first
      expect(cr.key).to eq '1111111111'
      expect(cr.value).to eq '2222222222'
      expect(cr.company).to eq co
    end
  end

  describe "find_ca_hts_to_descr" do
    it "finds" do
      c = create(:company, alliance_customer_number: "ACME")
      described_class.create!(key: '1111111111', value: 'asbestos car', cross_reference_type: described_class::CA_HTS_TO_DESCR, company: c)
      expect(described_class.find_ca_hts_to_descr('1111111111', c.id)).to eq 'asbestos car'
    end
  end

  describe "create_ca_hts_to_descr" do
    let(:co) { create(:company, alliance_customer_number: "ACME") }

    it "creates" do
      described_class.create_ca_hts_to_descr! '1111111111', 'asbestos car', co.id
      cr = described_class.first
      expect(cr.key).to eq '1111111111'
      expect(cr.value).to eq 'asbestos car'
      expect(cr.company).to eq co
    end

    it "strips dots from key" do
      described_class.create_ca_hts_to_descr! '1111.11.1111', 'asbestos.car', co.id
      cr = described_class.first
      expect(cr.key).to eq '1111111111'
      expect(cr.value).to eq 'asbestos.car'
      expect(cr.company).to eq co
    end
  end

  describe "find_pvh_invoice" do
    it "finds" do
      described_class.destroy_all
      described_class.create!(key: "pvh*~*inv_num", cross_reference_type: described_class::PVH_INVOICES)
      expect(described_class.find_pvh_invoice("pvh", "inv_num")).to eq true
    end
  end

  describe "create_pvh_invoice" do
    it "creates" do
      expect { described_class.create_pvh_invoice!("pvh", "inv_num") }.to change(described_class, :count).from(0).to(1)
      xref = described_class.first
      expect(xref.cross_reference_type).to eq(described_class::PVH_INVOICES)
      expect(xref.key).to eq "pvh*~*inv_num"
    end
  end

  describe "key?" do
    it "determines if an xref key is present in the db table" do
      described_class.add_xref! DataCrossReference::UA_PLANT_TO_ISO, 'x', 'y', 1
      expect(described_class.key?('x', DataCrossReference::UA_PLANT_TO_ISO)).to be true

      expect(described_class.key?('askjfda', DataCrossReference::UA_PLANT_TO_ISO)).not_to be true
      expect(described_class.key?(nil, DataCrossReference::UA_PLANT_TO_ISO)).not_to be true
    end
  end

  describe "company_for_xref" do
    let(:u) { instance_double "user" }
    let!(:xref_edit_hash) { {key_label: "key", value_label: "value", company: {system_code: "ACME"}} }

    it "returns company associated with xref_edit_hash, looking-up by system_code" do
      co = create(:company, system_code: "ACME")
      expect(described_class.company_for_xref(xref_edit_hash)).to eq co
    end

    it "returns company associated with xref_edit_hash, looking-up by alliance_customer_number" do
      co = create(:company, alliance_customer_number: "ACME")
      xref_edit_hash[:company] = {alliance_customer_number: "ACME"}

      expect(described_class.company_for_xref(xref_edit_hash)).to eq co
    end

    it "returns company associated with xref_edit_hash, looking-up by fenix_customer_number" do
      co = create(:company, fenix_customer_number: "ACME")
      xref_edit_hash[:company] = {fenix_customer_number: "ACME"}

      expect(described_class.company_for_xref(xref_edit_hash)).to eq co
    end

    it "returns nil if no company is associated" do
      xref_edit_hash.delete :company
      expect(described_class.company_for_xref(xref_edit_hash)).to be_nil
    end
  end

  describe "preprocess_and_add_xref!" do
    let(:xref_hsh) do
      {
        "xref_type" => {
          show_value_column: true,
          identifier: "xref_type",
          require_company: false,
          preprocessor: ->(k, v) { {key: k, value: v} }
        }
      }
    end

    it "returns false if preprocessed key is nil and makes no changes" do
      preprocessor = ->(_key, _value) { {key: nil, value: "value"} }
      xref_hsh["xref_type"][:preprocessor] = preprocessor

      expect(described_class).to receive(:xref_edit_hash).with(nil).and_return xref_hsh
      described_class.destroy_all
      expect(described_class.preprocess_and_add_xref!("xref_type", "unprocessed_key", "unprocessed_value")).to eq false
      expect(described_class.count).to eq 0
    end

    it "returns false if preprocessed value is nil and makes no changes when value is required" do
      preprocessor = ->(_key, _value) { {key: "key", value: nil} }
      xref_hsh["xref_type"][:preprocessor] = preprocessor

      expect(described_class).to receive(:xref_edit_hash).with(nil).and_return xref_hsh
      described_class.destroy_all
      expect(described_class.preprocess_and_add_xref!("xref_type", "unprocessed_key", "unprocessed_value")).to eq false
      expect(described_class.count).to eq 0
    end

    it "returns true and updates xref when preprocessed key and value exist" do
      preprocessor = ->(_key, _value) { {key: "key", value: "value"} }
      xref_hsh["xref_type"][:preprocessor] = preprocessor

      expect(described_class).to receive(:xref_edit_hash).with(nil).and_return xref_hsh
      described_class.destroy_all
      expect(described_class.preprocess_and_add_xref!("xref_type", "unprocessed_key", "unprocessed_value")).to eq true
      expect(described_class.count).to eq 1
      xref = described_class.first
      expect(xref.key).to eq "key"
      expect(xref.value).to eq "value"
    end

    it "returns true and updates xref when preprocessed value is nil and value is not required" do
      preprocessor = ->(_key, _value) { {key: "key", value: nil} }
      xref_hsh["xref_type"][:preprocessor] = preprocessor
      xref_hsh["xref_type"][:show_value_column] = false

      expect(described_class).to receive(:xref_edit_hash).with(nil).and_return xref_hsh
      described_class.destroy_all
      expect(described_class.preprocess_and_add_xref!("xref_type", "unprocessed_key", "unprocessed_value")).to eq true
      expect(described_class.count).to eq 1
      xref = described_class.first
      expect(xref.key).to eq "key"
      expect(xref.value).to be_nil
    end

    it "returns true and updates if value is not required" do
      xref_hsh["xref_type"][:allow_blank_value] = true
      expect(described_class).to receive(:xref_edit_hash).with(nil).and_return xref_hsh
      described_class.destroy_all
      expect(described_class.preprocess_and_add_xref!("xref_type", "key", nil)).to eq true
      expect(described_class.count).to eq 1
      xref = described_class.first
      expect(xref.key).to eq "key"
      expect(xref.value).to be_nil
    end
  end

  context "one-time alert reference fields" do
    before do
      described_class.create!(cross_reference_type: "ota_reference_fields", key: "Entry~ent_entry_num")
      described_class.create!(cross_reference_type: "ota_reference_fields", key: "Entry~ent_release_date")
      described_class.create!(cross_reference_type: "ota_reference_fields", key: "Shipment~shp_ref")
    end

    describe "hash_ota_reference_fields" do
      it "returns hash of xref fields" do
        expect(described_class.hash_ota_reference_fields).to eq("Entry" => [:ent_entry_num, :ent_release_date], "Shipment" => [:shp_ref])
      end
    end

    describe "update_ota_reference_fields!" do
      it "updates xref fields" do
        update_hsh = {"Entry" => [:ent_entry_num], "Shipment" => [:shp_ref, :shp_mode], "Product" => [:prod_uid]}
        described_class.update_ota_reference_fields! update_hsh
        updated = ["Entry~ent_entry_num", "Product~prod_uid", "Shipment~shp_mode", "Shipment~shp_ref"]
        expect(described_class.where(cross_reference_type: "ota_reference_fields").pluck(:key).sort).to eq updated
      end
    end
  end

  describe "xref_edit_hash" do
    # no two lambdas share the same identity so this simplifies the tests
    def strip_preproc hsh
      hsh.delete(:preprocessor)
      hsh
    end

    let! (:master_setup) do
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).and_return false
      ms
    end

    let(:preproc) {  OpenChain::DataCrossReferenceUploadPreprocessor }

    context "polo system" do
      before do
        allow(master_setup).to receive(:custom_feature?).with("Polo").and_return true
      end

      it "returns information about xref screens user has access to" do
        xrefs = described_class.xref_edit_hash User.new

        expect(xrefs.size).to eq 2
        # rubocop:disable Layout/LineLength
        expect(strip_preproc(xrefs['rl_fabric'])).to eq title: "MSL+ Fabric Cross References", description: "Enter the starting fabric value in the Failure Fiber field and the final value to send to MSL+ in the Approved Fiber field.", identifier: 'rl_fabric', key_label: "Failure Fiber", value_label: "Approved Fiber", show_value_column: true, allow_duplicate_keys: false, require_company: false
        expect(strip_preproc(xrefs['rl_valid_fabric'])).to eq title: "MSL+ Valid Fabric List", description: "Only values included in this list are allowed to be sent to to MSL+.", identifier: 'rl_valid_fabric', key_label: "Approved Fiber", value_label: "Value", show_value_column: false, allow_duplicate_keys: false, require_company: false
        # rubocop:enable Layout/LineLength
      end
    end

    context "www system" do
      before do
        allow(master_setup).to receive(:custom_feature?).with("WWW").and_return true
      end

      it "returns information about xref screens sys-admin user has access to" do
        xrefs = described_class.xref_edit_hash(create(:sys_admin_user))

        expect(xrefs.size).to eq 5
        # rubocop:disable Layout/LineLength
        expect(strip_preproc(xrefs['siemens_billing_standard'])).to eq title: "Siemens Billing Standard Group", description: "Tax IDs for the standard Siemens billing report", identifier: "siemens_billing_standard", key_label: "Tax ID", allow_duplicate_keys: false, require_company: false, allow_blank_values: false, show_value_column: false, value_label: "Value"
        expect(strip_preproc(xrefs['siemens_billing_energy'])).to eq title: "Siemens Billing Energy Group", description: "Tax IDs for the energy Siemens billing report", identifier: "siemens_billing_energy", key_label: "Tax ID", allow_duplicate_keys: false, require_company: false, allow_blank_values: false, show_value_column: false, value_label: "Value"
        expect(strip_preproc(xrefs['part_xref'])).to eq title: "Part Cross Reference", description: "Enter the Part Number in the Part field and true or false in the active field", identifier: "part_xref", key_label: "Part", value_label: "Active", require_company: true, allow_blank_value: false, show_value_column: true, allow_duplicate_keys: false, upload_instructions: "Spreadsheet should contain a header row, with Part Number in column A and true or false in column B."
        expect(strip_preproc(xrefs['spi_available_country_combination'])).to eq title: "SPI-Available Country Combinations", description: "Combinations of entry country of export and origin ISO codes that have SPI available.", identifier: "spi_available_country_combination", key_label: "Export Country ISO*~*Origin Country ISO", value_label: "N/A - unused", key_upload_label: "Export Country ISO", value_upload_label: "Origin Country ISO", allow_duplicate_keys: false, require_company: false, show_value_column: true
        expect(strip_preproc(xrefs['billing_invoice_customer'])).to eq title: "Billing Invoice Customers", description: "Customer Numbers for companies that have billing invoices generated off their broker invoices.", identifier: "billing_invoice_customer", key_label: "Customer Number", allow_blank_values: false, require_company: false, show_value_column: false, value_label: "N/A - unused", allow_duplicate_keys: false
        # rubocop:enable Layout/LineLength
      end
    end

    context "vfi system" do
      before do
        allow(master_setup).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return true
      end

      let(:milestone_config) { OpenChain::MilestoneNotificationConfigSupport }

      it "returns information about xref screens sys-admin user has access to" do
        key_selector = instance_double(milestone_config::DataCrossReferenceKeySelector)
        expect(milestone_config::DataCrossReferenceKeySelector).to receive(:new).with("Entry").and_return key_selector
        val_selector = instance_double(milestone_config::DataCrossReferenceValueSelector)
        expect(milestone_config::DataCrossReferenceValueSelector).to receive(:new).with("Entry").and_return val_selector

        xrefs = described_class.xref_edit_hash(create(:sys_admin_user))

        # rubocop:disable Layout/LineLength
        expect(xrefs.size).to eq 13
        expect(strip_preproc(xrefs['us_hts_to_ca'])).to eq title: "System Classification Cross References", description: "Products with a US HTS number and no Canadian tariff are assigned the corresponding Canadian HTS.", identifier: 'us_hts_to_ca', key_label: "United States HTS", value_label: "Canada HTS", allow_duplicate_keys: false, show_value_column: true, require_company: true, company: {system_code: "HENNE"}
        expect(strip_preproc(xrefs['asce_mid'])).to eq title: "Ascena MID-Vendor List", description: "MID-Vendors on this list are used to generate the Daily First Sale Exception report", identifier: "asce_mid", key_label: "MID-Vendor ID", value_label: "FS Start Date", allow_duplicate_keys: false, show_value_column: true, require_company: false
        expect(strip_preproc(xrefs['shp_ci_load_goods'])).to eq title: "Shipment Entry Load Goods Descriptions", description: "Enter the customer number and corresponding default Goods Description.", identifier: "shp_ci_load_goods", key_label: "Customer Number", value_label: "Goods Description", allow_duplicate_keys: false, show_value_column: true, require_company: false
        expect(strip_preproc(xrefs['shp_entry_load_cust'])).to eq title: "Shipment Entry Load Customers", show_value_column: true, value_label: "Document Type", allowed_values: ["Standard", "Rollup"], description: "Enter the customer number to enable sending Shipment data to Kewill.", identifier: "shp_entry_load_cust", key_label: "Customer Number", allow_duplicate_keys: false, require_company: false
        expect(strip_preproc(xrefs['shp_ci_load_cust'])).to eq title: "Shipment CI Load Customers", description: "Enter the customer number to enable sending Shipment CI Load data to Kewill.", identifier: "shp_ci_load_cust", key_label: "Customer Number", value_label: "Value", allow_duplicate_keys: false, show_value_column: false, require_company: false
        expect(strip_preproc(xrefs['hm_pars'])).to eq title: "H&M PARS Numbers", description: "Enter the PARS numbers to use for the H&M export shipments to Canada. To mark a PARS Number as used, edit it and key a '1' into the 'PARS Used?' field.", identifier: "hm_pars", key_label: "PARS Number", value_label: "PARS Used?", allow_duplicate_keys: false, show_value_column: true, require_company: false, upload_instructions: 'Spreadsheet should contain a Header row labeled "PARS Numbers" in column A.  List all PARS numbers thereafter in column A.', allow_blank_value: true
        expect(strip_preproc(xrefs['entry_mids'])).to eq title: "Manufacturer ID", description: "Manufacturer IDs used to validate entries", identifier: "entry_mids", key_label: "MID", value_label: "Value", allow_duplicate_keys: false, show_value_column: false, require_company: true, upload_instructions: 'Spreadsheet should contain a header row, with MID Code in column A', allow_blank_value: false
        expect(strip_preproc(xrefs['inv_ci_load_cust'])).to eq title: "Invoice CI Load Customers", description: "Enter the customer number to enable sending Invoice CI Load data to Kewill.", identifier: "inv_ci_load_cust", key_label: "Customer Number", value_label: "Value", allow_duplicate_keys: false, show_value_column: false, require_company: false
        expect(strip_preproc(xrefs['asce_brand_xref'])).to eq title: "Ascena Brands", description: "Enter the full brand name in the Brand Name field and enter the brand abbreviation in the Brand Abbrev field.", identifier: "asce_brand_xref", key_label: "Brand Name", value_label: "Brand Abbrev", allow_duplicate_keys: false, show_value_column: true, require_company: false, upload_instructions: 'Spreadsheet should contain a header row labels "Brand Name" in column A and "Brand Abbrev" in column B. List full brand names in column A and brand abbreviations in column b', allow_blank_value: false
        expect(strip_preproc(xrefs['asce_mid'])).to eq title: "Ascena MID-Vendor List", description: "MID-Vendors on this list are used to generate the Daily First Sale Exception report", identifier: "asce_mid", key_label: "MID-Vendor ID", value_label: "FS Start Date", allow_duplicate_keys: false, show_value_column: true, require_company: false
        expect(strip_preproc(xrefs['mid_xref'])).to eq title: "MID Cross Reference", description: "Enter the create Identifier in the Code field and the actual MID in the MID field.", identifier: "mid_xref", key_label: "Code", value_label: "MID", allow_duplicate_keys: false, show_value_column: true, require_company: true, allow_blank_value: false, upload_instructions: "Spreadsheet should contain a header row, with create Code in column A and MID in column B."
        expect(strip_preproc(xrefs['tradelens_entry_milestone_fields'])).to eq title: "TradeLens Entry Milestone Fields", description: "Assign entry fields to TradeLens API endpoint.", key_label: "Field", allowed_keys: key_selector, value_label: "Endpoint", allowed_values: val_selector, allow_blank_value: false, show_value_column: true, allow_duplicate_keys: false, identifier: "tradelens_entry_milestone_fields", require_company: false
        expect(strip_preproc(xrefs['part_xref'])).to eq allow_blank_value: false, allow_duplicate_keys: false, description: "Enter the Part Number in the Part field and true or false in the active field", value_label: "Active", upload_instructions: "Spreadsheet should contain a header row, with Part Number in column A and true or false in column B.", title: "Part Cross Reference", show_value_column: true, require_company: true, key_label: "Part", identifier: "part_xref"
        # rubocop:enable Layout/LineLength
      end

      it "returns info about xref screens xref-maintenance group member has access to" do
        g = create(:group, system_code: "xref-maintenance")
        u = create(:user, groups: [g])

        # rubocop:disable Layout/LineLength
        xrefs = described_class.xref_edit_hash(u)
        expect(xrefs.size).to eq 10
        expect(strip_preproc(xrefs['us_hts_to_ca'])).to eq title: "System Classification Cross References", description: "Products with a US HTS number and no Canadian tariff are assigned the corresponding Canadian HTS.", identifier: 'us_hts_to_ca', key_label: "United States HTS", value_label: "Canada HTS", allow_duplicate_keys: false, show_value_column: true, require_company: true, company: {system_code: "HENNE"}
        expect(strip_preproc(xrefs['asce_mid'])).to eq title: "Ascena MID-Vendor List", description: "MID-Vendors on this list are used to generate the Daily First Sale Exception report", identifier: "asce_mid", key_label: "MID-Vendor ID", value_label: "FS Start Date", allow_duplicate_keys: false, show_value_column: true, require_company: false
        expect(strip_preproc(xrefs['shp_ci_load_goods'])).to eq title: "Shipment Entry Load Goods Descriptions", description: "Enter the customer number and corresponding default Goods Description.", identifier: "shp_ci_load_goods", key_label: "Customer Number", value_label: "Goods Description", allow_duplicate_keys: false, show_value_column: true, require_company: false
        expect(strip_preproc(xrefs['shp_entry_load_cust'])).to eq title: "Shipment Entry Load Customers", show_value_column: true, value_label: "Document Type", allowed_values: ["Standard", "Rollup"], description: "Enter the customer number to enable sending Shipment data to Kewill.", identifier: "shp_entry_load_cust", key_label: "Customer Number", allow_duplicate_keys: false, require_company: false
        expect(strip_preproc(xrefs['shp_ci_load_cust'])).to eq title: "Shipment CI Load Customers", description: "Enter the customer number to enable sending Shipment CI Load data to Kewill.", identifier: "shp_ci_load_cust", key_label: "Customer Number", value_label: "Value", allow_duplicate_keys: false, show_value_column: false, require_company: false
        expect(strip_preproc(xrefs['entry_mids'])).to eq title: "Manufacturer ID", description: "Manufacturer IDs used to validate entries", identifier: "entry_mids", key_label: "MID", value_label: "Value", allow_duplicate_keys: false, show_value_column: false, require_company: true, upload_instructions: 'Spreadsheet should contain a header row, with MID Code in column A', allow_blank_value: false
        expect(strip_preproc(xrefs['inv_ci_load_cust'])).to eq title: "Invoice CI Load Customers", description: "Enter the customer number to enable sending Invoice CI Load data to Kewill.", identifier: "inv_ci_load_cust", key_label: "Customer Number", value_label: "Value", allow_duplicate_keys: false, show_value_column: false, require_company: false
        expect(strip_preproc(xrefs['asce_brand_xref'])).to eq title: "Ascena Brands", description: "Enter the full brand name in the Brand Name field and enter the brand abbreviation in the Brand Abbrev field.", identifier: "asce_brand_xref", key_label: "Brand Name", value_label: "Brand Abbrev", allow_duplicate_keys: false, show_value_column: true, require_company: false, upload_instructions: 'Spreadsheet should contain a header row labels "Brand Name" in column A and "Brand Abbrev" in column B. List full brand names in column A and brand abbreviations in column b', allow_blank_value: false
        expect(strip_preproc(xrefs['asce_mid'])).to eq title: "Ascena MID-Vendor List", description: "MID-Vendors on this list are used to generate the Daily First Sale Exception report", identifier: "asce_mid", key_label: "MID-Vendor ID", value_label: "FS Start Date", allow_duplicate_keys: false, show_value_column: true, require_company: false
        expect(strip_preproc(xrefs['mid_xref'])).to eq title: "MID Cross Reference", description: "Enter the create Identifier in the Code field and the actual MID in the MID field.", identifier: "mid_xref", key_label: "Code", value_label: "MID", allow_duplicate_keys: false, show_value_column: true, require_company: true, allow_blank_value: false, upload_instructions: "Spreadsheet should contain a header row, with create Code in column A and MID in column B."
        expect(strip_preproc(xrefs['ca_hts_to_descr'])).to eq title: "Canada Customs Description Cross References", description: "Products automatically assigned a CA HTS are given the corresponding customs description.", identifier: 'ca_hts_to_descr', key_label: "Canada HTS", value_label: "Customs Description", allow_duplicate_keys: false, show_value_column: true, require_company: true, company: {system_code: "HENNE"}
        # rubocop:enable Layout/LineLength
      end
    end

    context "ll system" do
      before do
        allow(master_setup).to receive(:custom_feature?).with("Lumber Liquidators").and_return true
      end

      let (:admin_user) do
        u = User.new
        allow(u).to receive(:admin?).and_return true
        u
      end

      it "returns information about xref screens admin user has access to" do
        xrefs = described_class.xref_edit_hash admin_user

        expect(xrefs.size).to eq 3
        # rubocop:disable Layout/LineLength
        expect(strip_preproc(xrefs['ll_carb_statement'])).to eq title: "CARB Statements", description: "Enter the CARB Statement code in the Code field and the Code Description in the Description field.", identifier: "ll_carb_statement", key_label: "Code", value_label: "Description", allow_duplicate_keys: false, show_value_column: true, require_company: false
        expect(strip_preproc(xrefs['ll_patent_statement'])).to eq title: "Patent Statements", description: "Enter the Patent Statement code in the Code field and the Code Description in the Description field.", identifier: "ll_patent_statement", key_label: "Code", value_label: "Description", allow_duplicate_keys: false, show_value_column: true, require_company: false
        # rubocop:enable Layout/LineLength
      end
    end
  end

  describe "can_view?" do
    let! (:master_setup) do
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).and_return false
      ms
    end

    context "polo system" do
      before do
        allow(master_setup).to receive(:custom_feature?).with("Polo").and_return true
      end

      it "allows access to RL Fabrix xref for anyone" do
        expect(described_class.can_view?('rl_fabric', User.new)).to eq true
      end

      it "allows access to RL Value Fabirc xref for anyone" do
        expect(described_class.can_view?('rl_valid_fabric', User.new)).to eq true
      end
    end

    context "under armour system" do
      before do
        allow(master_setup).to receive(:custom_feature?).with("UnderArmour").and_return true
      end

      it "allows access to UA sites xref for anyone" do
        expect(described_class.can_view?('ua_site', User.new)).to eq true
      end
    end

    context "vfi system" do
      before do
        allow(master_setup).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return true
      end

      context "us_hts_to_ca" do
        it "allows access to US-to-CA xref for sys admins" do
          expect(described_class.can_view?('us_hts_to_ca', create(:sys_admin_user))).to eq true
        end

        it "prevents access for anyone else" do
          expect(described_class.can_view?('us_hts_to_ca', User.new)).to eq false
        end
      end

      context "asce_mid" do
        it "allows access to ASCE MID xref for sys admins" do
          expect(described_class.can_view?('asce_mid', create(:sys_admin_user))).to eq true
        end

        it "prevents access for anyone else" do
          expect(described_class.can_view?('asce_mid', User.new)).to eq false
        end
      end

      context "ca_hts_to_descr" do
        let(:user) { create(:user) }

        it "allows access for members of group 'Cross Reference Maintenance'" do
          group = create(:group, system_code: "xref-maintenance")
          user.groups << group
          expect(described_class.can_view?('ca_hts_to_descr', user)).to eq true
        end

        it "prevents access for anyone else" do
          expect(described_class.can_view?('ca_hts_to_descr', user)).to eq false
        end
      end

      context "one-time-alert reference fields" do
        it "allows access for administrators" do
          user = create(:admin_user)
          expect(described_class.can_view?("ota_reference_fields", user)).to eq true
        end

        it "prevents access for anyone else" do
          user = create(:user)
          expect(described_class.can_view?("ota_reference_fields", user)).to eq false
        end
      end

    end
  end

  describe "find_315_milestone" do
    it "finds a milestone value" do
      e = Entry.new source_system: "source", broker_reference: "ref"
      described_class.add_xref! DataCrossReference::OUTBOUND_315_EVENT, described_class.make_compound_key(e.source_system, e.broker_reference, "code"), "value"
      expect(described_class.find_315_milestone(e, 'code')).to eq "value"
    end
  end

  describe "create_315_milestone!" do
    it "creates a 315 milestone" do
      e = Entry.new source_system: "source", broker_reference: "ref"
      described_class.create_315_milestone! e, 'code', 'value'
      expect(described_class.find_315_milestone(e, 'code')).to eq "value"
    end

    it "updates an existing milestone" do
      e = Entry.new source_system: "source", broker_reference: "ref"
      xref = described_class.create_315_milestone! e, 'code', 'value'
      described_class.create_315_milestone! e, 'code', 'value2'
      expect(xref.reload.value).to eq "value2"
    end
  end

  describe "create / find_po_fingerprint" do
    it "finds xref object" do
      o = Order.new order_number: "123"
      described_class.create_po_fingerprint o, "fingerprint"
      xref = described_class.find_po_fingerprint o
      expect(xref.value).to eq "fingerprint"
    end
  end

  describe "generate_csv" do
    let(:u) { create(:sys_admin_user) }
    let!(:co) { create(:company, name: "ACME", system_code: "AC") }
    let!(:dcr_1) { described_class.create!(key: "1111111111", value: "2222222222", cross_reference_type: "xref_name", company: co) }
    let!(:dcr_2) { described_class.create!(key: "3333333333", value: "4444444444", cross_reference_type: "xref_name", company: co) }

    it "returns nil to unauthorized user" do
      allow(described_class).to receive(:can_view?).and_return false
      allow(described_class).to receive(:xref_edit_hash)
        .with(u)
        .and_return({"xref_name" => {key_label: "KEY LABEL",
                                     value_label: "VALUE LABEL",
                                     show_value_column: true,
                                     require_company: true}})

      expect(described_class.generate_csv("xref_name", u)).to be_nil
    end

    it "returns 4-col layout for xref types with companies" do
      allow(described_class).to receive(:can_view?).and_return true
      allow(described_class).to receive(:xref_edit_hash)
        .with(u)
        .and_return({"xref_name" => {key_label: "KEY LABEL",
                                     value_label: "VALUE LABEL",
                                     show_value_column: true,
                                     require_company: true}})
      csv = described_class.generate_csv("xref_name", u).split("\n")

      expect(csv[0].split(",")).to eq ["KEY LABEL", "VALUE LABEL", "Company", "Last Updated"]
      expect(csv[1].split(",").take(3)).to eq ["1111111111", "2222222222", "ACME (AC)"]
      expect(csv[2].split(",").take(3)).to eq ["3333333333", "4444444444", "ACME (AC)"]
    end

    it "returns 3-col layout for xref types without companies" do
      allow(described_class).to receive(:can_view?).and_return true
      allow(described_class).to receive(:xref_edit_hash)
        .with(u)
        .and_return({"xref_name" => {key_label: "KEY LABEL", value_label: "VALUE LABEL", show_value_column: true, require_company: false}})

      dcr_1.update(company: nil)
      dcr_2.update(company: nil)
      csv = described_class.generate_csv("xref_name", u).split("\n")

      expect(csv[0].split(",")).to eq ["KEY LABEL", "VALUE LABEL", "Last Updated"]
      expect(csv[1].split(",").take(2)).to eq ["1111111111", "2222222222"]
      expect(csv[2].split(",").take(2)).to eq ["3333333333", "4444444444"]
    end

    it "returns 3-col layout for xref types that hide value column" do
      allow(described_class).to receive(:can_view?).and_return true
      allow(described_class).to receive(:xref_edit_hash)
        .with(u)
        .and_return({"xref_name" => {key_label: "KEY LABEL", show_value_column: false, require_company: true}})
      csv = described_class.generate_csv("xref_name", u).split("\n")

      expect(csv[0].split(",")).to eq ["KEY LABEL", "Company", "Last Updated"]
      expect(csv[1].split(",").take(2)).to eq ["1111111111", "ACME (AC)"]
      expect(csv[2].split(",").take(2)).to eq ["3333333333", "ACME (AC)"]
    end
  end

  context "HM Pars" do

    let (:used_data_cross_reference) do
      described_class.create! cross_reference_type: DataCrossReference::HM_PARS_NUMBER, key: "PARS-USED", value: "1"
    end

    let (:unused_data_cross_reference) do
      described_class.add_hm_pars_number("Pars-Unused")
    end

    describe "find_and_mark_next_unused_hm_pars_number" do
      it "finds the next cross reference and marks it as being used" do
        used_data_cross_reference
        unused_data_cross_reference

        expect(described_class.find_and_mark_next_unused_hm_pars_number).to eq unused_data_cross_reference
        expect(unused_data_cross_reference.reload.value).to eq "1"

        # If the cross reference was marked as used...then there should be no more left and nil shoudl be returned
        expect(described_class.find_and_mark_next_unused_hm_pars_number).to be_nil
      end

      it "uses alphabetic sorting to determine next pars number to use" do
        unused_data_cross_reference
        new_unused = described_class.add_hm_pars_number("A Pars-Unused")
        expect(described_class.find_and_mark_next_unused_hm_pars_number).to eq new_unused
      end
    end

    describe "unused_pars_count" do
      it "returns correct count of unused pars numbers" do
        used_data_cross_reference
        unused_data_cross_reference

        expect(described_class.unused_pars_count).to eq 1
      end

      it "returns zero if all pars numbers are utilized" do
        used_data_cross_reference
        expect(described_class.unused_pars_count).to eq 0
      end
    end
  end

  context "UN Locodes" do
    let (:importer) { create(:importer) }
    let! (:importer_locode) { described_class.create! cross_reference_type: DataCrossReference::UN_LOCODE_TO_US_CODE, key: "USLAX", value: "LAX", company_id: importer.id }
    let! (:locode) { described_class.create! cross_reference_type: DataCrossReference::UN_LOCODE_TO_US_CODE, key: "USORD", value: "ORD" }

    describe "find_us_port_code" do

      # Should not find a company specific xref
      it "finds a generic xref" do
        expect(described_class.find_us_port_code("USORD")).to eq "ORD"
      end

      it "finds a company specific xref" do
        expect(described_class.find_us_port_code("USLAX", company: importer)).to eq "LAX"
      end

      it "falls back to a generic xref if no company specific one is present" do
        expect(described_class.find_us_port_code("USORD", company: importer)).to eq "ORD"
      end

      it "does not find a company specific xref if company is not passed as a param" do
        expect(described_class.find_us_port_code("USLAX")).to be_nil
      end
    end
  end

  describe "find_mid" do
    let (:company) { create(:importer) }
    let! (:mid) {  described_class.create! key: "key", value: "MID1", company: company, cross_reference_type: DataCrossReference::MID_XREF}

    it "finds an mid record" do
      expect(described_class.find_mid("key", company)).to eq "MID1"
    end

    it "allows using company id" do
      expect(described_class.find_mid("key", company.id)).to eq "MID1"
    end

    it "returns nil if not found" do
      expect(described_class.find_mid("key2", company)).to eq nil
    end
  end

  describe "keys" do
    it "returns all key values for a particular type" do
      described_class.create! cross_reference_type: "test", key: "K1"
      described_class.create! cross_reference_type: "test", key: "K2"
      # Make sure pluck is being used to pull the key value back, since we don't need all the values
      # from the xref record just to return keys in a set
      expect_any_instance_of(ActiveRecord::Relation).to receive(:pluck).with(:key).and_call_original

      set = described_class.keys "test"
      expect(set).to be_a Set
      expect(set.size).to eq 2
      expect(set).to include "K1"
      expect(set).to include "K2"
    end
  end
end
