require 'spec_helper'

describe DataCrossReference do

  context "hash_for_type" do
    it "should find all for reference" do
      csv = "k,v\nk2,v2"
      described_class.load_cross_references csv, 'xref_type'
      described_class.create!(key:'ak',value:'av',cross_reference_type:'xrt')
      expect(described_class.hash_for_type('xref_type')).to eq({'k'=>'v','k2'=>'v2'})
    end
  end

  context "get_all_pairs" do
    it "should get all pairs for a cross reference type" do
      described_class.create!(key:'a',value:'b',cross_reference_type:'x')
      described_class.create!(key:'c',value:'d',cross_reference_type:'x')
      described_class.create!(key:'dontfind',value:'d',cross_reference_type:'z')
      h = {'a'=>'b','c'=>'d'}
      expect(described_class.get_all_pairs('x')).to eq h
    end
  end
  context "load_cross_references" do
    it "should load csv cross reference data from an IO object" do
      # Make sure we're also updating existing xrefs
      DataCrossReference.create! :company_id=>1, :key=>"key2", :value=>"", :cross_reference_type=>'xref_type'
      csv = "key,value\nkey2,value2\n"

      DataCrossReference.load_cross_references csv, 'xref_type', 1

      xrefs = DataCrossReference.where(:company_id=>1, :cross_reference_type=>'xref_type').order("created_at ASC, id ASC")
      expect(xrefs.length).to eq(2)
      expect(xrefs.first.key).to eq("key2")
      expect(xrefs.first.value).to eq("value2")

      expect(xrefs.last.key).to eq("key")
      expect(xrefs.last.value).to eq("value")
    end
  end

  context "jjill_order_fingerprint" do
    it "should find" do
      described_class.create! key: 1, value:'ABCDEFG', cross_reference_type:described_class::JJILL_ORDER_FINGERPRINT
      o = Order.new
      o.id = 1
      expect(described_class.find_jjill_order_fingerprint(o)).to eq 'ABCDEFG'
    end
    it "should create" do
      o = Order.new
      o.id = 1
      described_class.create_jjill_order_fingerprint! o, 'ABCDEFG'
      expect(described_class.find_jjill_order_fingerprint(o)).to eq 'ABCDEFG'
    end
  end
  context "lenox_item_master_hash" do
    it "should find" do
      described_class.create! key: 'partno', value:'ABCDEFG', cross_reference_type:described_class::LENOX_ITEM_MASTER_HASH
      expect(described_class.find_lenox_item_master_hash('partno')).to eq 'ABCDEFG'
    end
    it "should create" do
      described_class.create_lenox_item_master_hash! 'part_no', 'hashval'
      expect(described_class.where(key:'part_no',value:'hashval',cross_reference_type:described_class::LENOX_ITEM_MASTER_HASH).count).to eq 1
    end
  end
  context "lenox_hts_fingerprint" do
    it "should find" do
      described_class.create! key: described_class.make_compound_key(1, 'US'), value: '9801001010', cross_reference_type: described_class::LENOX_HTS_FINGERPRINT
      expect(described_class.find_lenox_hts_fingerprint(1, 'US')).to eq '9801001010'
    end
    it "should create" do
      described_class.create_lenox_hts_fingerprint! 1, 'US', '9801001010'
      expect(described_class.where(key: described_class.make_compound_key(1, 'US'), value: '9801001010', cross_reference_type: described_class::LENOX_HTS_FINGERPRINT).count).to eq 1
    end
  end
  context "find_rl_profit_center" do
    it "should find an rl profit center from the brand code" do
      company = Factory(:importer)
      DataCrossReference.create! :key=>"brand", :value=>"profit center", :cross_reference_type=>DataCrossReference::RL_BRAND_TO_PROFIT_CENTER, company_id: company.id

      expect(DataCrossReference.find_rl_profit_center_by_brand(company.id, 'brand')).to eq "profit center"
    end
  end

  context "find_rl_brand" do
    it "should find an rl brand code from PO number" do
      DataCrossReference.create! :key=>"po#", :value=>"brand", :cross_reference_type=>DataCrossReference::RL_PO_TO_BRAND

      expect(DataCrossReference.find_rl_brand_by_po('po#')).to eq("brand")
    end
  end

  context "find_ua_plant_to_iso" do
    it "should find" do
      described_class.create!(key:'x',value:'y',cross_reference_type:described_class::UA_PLANT_TO_ISO)
      expect(described_class.find_ua_plant_to_iso('x')).to eq('y')
    end
  end
  context "find_ua_winshuttle_fingerprint" do
    it "should find" do
      described_class.create!(key:DataCrossReference.make_compound_key('x', 'y', 'z'),value:'y',cross_reference_type:described_class::UA_WINSHUTTLE_FINGERPRINT)
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
    it "should find" do
      described_class.create!(key:'x-y-z',value:'a',cross_reference_type:described_class::UA_MATERIAL_COLOR_PLANT)
      expect(described_class.find_ua_material_color_plant('x','y','z')).to eq('a')
    end
  end
  context "create_ua_material_color_plant!" do
    it "should create" do
      described_class.create_ua_material_color_plant! 'x','y','z'
      expect(described_class.find_ua_material_color_plant('x','y','z')).to eq('1')
    end
  end
  context "add_xref!" do
    it "should add" do
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
      c = Factory(:company, alliance_customer_number: "ACME")
      described_class.create!(key: '1111111111', value: '2222222222', cross_reference_type: described_class::US_HTS_TO_CA, company: c)
      expect(described_class.find_us_hts_to_ca('1111111111', c.id)).to eq '2222222222'
    end
  end
  describe "create_us_hts_to_ca!" do
    let!(:co) { Factory(:company, alliance_customer_number: "ACME") }
    
    it "creates" do
      described_class.create_us_hts_to_ca! '1111111111', '2222222222', co.id
      cr = DataCrossReference.first
      expect(cr.key).to eq '1111111111'
      expect(cr.value).to eq '2222222222'
      expect(cr.company).to eq co
    end

    it "strips dots" do
      described_class.create_us_hts_to_ca! '1111.11.1111', '2222.22.2222', co.id
      cr = DataCrossReference.first
      expect(cr.key).to eq '1111111111'
      expect(cr.value).to eq '2222222222'
      expect(cr.company).to eq co
    end
  end

  describe "has_key?" do
    it "determines if an xref key is present in the db table" do
      DataCrossReference.add_xref! DataCrossReference::UA_PLANT_TO_ISO, 'x', 'y', 1
      expect(DataCrossReference.has_key? 'x', DataCrossReference::UA_PLANT_TO_ISO).to be_truthy
      expect(DataCrossReference.has_key? 'askjfda', DataCrossReference::UA_PLANT_TO_ISO).to be_falsey
      expect(DataCrossReference.has_key? nil, DataCrossReference::UA_PLANT_TO_ISO).to be_falsey
    end
  end

  describe "create_lands_end_mid!" do
    it "creates a lands end mid xref" do
      DataCrossReference.create_lands_end_mid! 'factory', 'hts', 'MID'
      expect(DataCrossReference.where(key: DataCrossReference.make_compound_key('factory', 'hts'), cross_reference_type: DataCrossReference::LANDS_END_MID).first.value).to eq "MID"
    end
  end

  describe "find_lands_end_mid" do
    it "finds a created lands end mid" do
      DataCrossReference.create_lands_end_mid! 'factory', 'hts', 'MID'
      expect(DataCrossReference.find_lands_end_mid 'factory', 'hts').to eq 'MID'
    end
  end

  describe "xref_edit_hash" do
    context "polo system" do      
      it "returns information about xref screens user has access to" do
        allow_any_instance_of(MasterSetup).to receive(:system_code).and_return "polo"

        xrefs = DataCrossReference.xref_edit_hash User.new

        expect(xrefs.size).to eq 2
        expect(xrefs['rl_fabric']).to eq title: "MSL+ Fabric Cross References", description: "Enter the starting fabric value in the Failure Fiber field and the final value to send to MSL+ in the Approved Fiber field.", identifier: 'rl_fabric', key_label: "Failure Fiber", value_label: "Approved Fiber", show_value_column: true, allow_duplicate_keys: false, require_company: false
        expect(xrefs['rl_valid_fabric']).to eq title: "MSL+ Valid Fabric List", description: "Only values included in this list are allowed to be sent to to MSL+.", identifier: 'rl_valid_fabric', key_label: "Approved Fiber", value_label: "Value", show_value_column: false, allow_duplicate_keys: false, require_company: false
      end
    end

    context "vfi system" do
      it "returns information about xref screens user has access to" do
        allow_any_instance_of(MasterSetup).to receive(:system_code).and_return "www-vfitrack-net"
        
        xrefs = DataCrossReference.xref_edit_hash(Factory(:sys_admin_user))
        
        expect(xrefs.size).to eq 1
        expect(xrefs['us_hts_to_ca']).to eq title: "System Classification Cross References", description: "Products with a US HTS number and no Canadian tariff are assigned the corresponding Canadian HTS.", identifier: 'us_hts_to_ca', key_label: "United States HTS", value_label: "Canada HTS", allow_duplicate_keys: false, show_value_column: true, require_company: true
      end
    end
  end

  describe "can_view?" do
    context "polo system" do
      before :each do
        allow_any_instance_of(MasterSetup).to receive(:system_code).and_return "polo"
      end

      it "allows access to RL Fabrix xref for anyone" do
        expect(DataCrossReference.can_view? 'rl_fabric', User.new).to be_truthy
      end

      it "allows access to RL Value Fabirc xref for anyone" do
        expect(DataCrossReference.can_view? 'rl_valid_fabric', User.new).to be_truthy
      end
    end

    context "vfi system" do
      before :each do
        allow_any_instance_of(MasterSetup).to receive(:system_code).and_return "www-vfitrack-net"
      end

      it "allows access to US-to-CA xref for sys admins" do
        expect(DataCrossReference.can_view? 'us_hts_to_ca', Factory(:sys_admin_user)).to be_truthy
      end

      it "prevents access for anyone else" do
        expect(DataCrossReference.can_view? 'us_hts_to_ca', User.new).to be_falsey
      end
    end
  end

  describe "find_315_milestone" do
    it "finds a milestone value" do
      e = Entry.new source_system: "source", broker_reference: "ref"
      xref = DataCrossReference.add_xref! DataCrossReference::OUTBOUND_315_EVENT, DataCrossReference.make_compound_key(e.source_system, e.broker_reference, "code"), "value"
      expect(DataCrossReference.find_315_milestone(e, 'code')).to eq "value"
    end
  end

  describe "create_315_milestone!" do
    it "creates a 315 milestone" do
      e = Entry.new source_system: "source", broker_reference: "ref"
      DataCrossReference.create_315_milestone! e, 'code', 'value'
      expect(DataCrossReference.find_315_milestone(e, 'code')).to eq "value"
    end

    it "updates an existing milestone" do
      e = Entry.new source_system: "source", broker_reference: "ref"
      xref = DataCrossReference.create_315_milestone! e, 'code', 'value'
      DataCrossReference.create_315_milestone! e, 'code', 'value2'
      expect(xref.reload.value).to eq "value2"
    end
  end

  describe "create / find_po_fingerprint" do
    it "finds xref object" do
      o = Order.new order_number: "123"
      DataCrossReference.create_po_fingerprint o, "fingerprint"
      xref = DataCrossReference.find_po_fingerprint o
      expect(xref.value).to eq "fingerprint"
    end
  end

  describe "generate_csv" do
    let(:u) { Factory(:sys_admin_user) }
    let!(:co) { Factory(:company, name: "ACME", system_code: "AC") }
    let!(:dcr_1) { DataCrossReference.create!(key: "1111111111", value: "2222222222", cross_reference_type: "xref_name", company: co) }
    let!(:dcr_2) { DataCrossReference.create!(key: "3333333333", value: "4444444444", cross_reference_type: "xref_name", company: co) }

    it "returns nil to unauthorized user" do
      allow(DataCrossReference).to receive(:can_view?).and_return false
      allow(described_class).to receive(:xref_edit_hash).with(u).and_return({"xref_name" => {key_label: "KEY LABEL", value_label: "VALUE LABEL", show_value_column: true, require_company: true}})
      
      expect(described_class.generate_csv("xref_name", u)).to be_nil
    end

    it "returns 4-col layout for xref types with companies" do
      allow(DataCrossReference).to receive(:can_view?).and_return true
      allow(described_class).to receive(:xref_edit_hash).with(u).and_return({"xref_name" => {key_label: "KEY LABEL", value_label: "VALUE LABEL", show_value_column: true, require_company: true}})
      csv = described_class.generate_csv("xref_name", u).split("\n")
      
      expect(csv[0].split(",")).to eq ["KEY LABEL", "VALUE LABEL", "Company", "Last Updated"]
      expect(csv[1].split(",").take(3)).to eq ["1111111111", "2222222222", "ACME (AC)"]
      expect(csv[2].split(",").take(3)).to eq ["3333333333", "4444444444", "ACME (AC)"]
    end

    it "returns 3-col layout for xref types without companies" do
      allow(DataCrossReference).to receive(:can_view?).and_return true
      allow(described_class).to receive(:xref_edit_hash).with(u).and_return({"xref_name" => {key_label: "KEY LABEL", value_label: "VALUE LABEL", show_value_column: true, require_company: false}})
      dcr_1.update_attributes(company: nil)
      dcr_2.update_attributes(company: nil)
      csv = described_class.generate_csv("xref_name", u).split("\n")
      
      expect(csv[0].split(",")).to eq ["KEY LABEL", "VALUE LABEL", "Last Updated"]
      expect(csv[1].split(",").take(2)).to eq ["1111111111", "2222222222"]
      expect(csv[2].split(",").take(2)).to eq ["3333333333", "4444444444"]
    end

    it "returns 3-col layout for xref types that hide value column" do
      allow(DataCrossReference).to receive(:can_view?).and_return true
      allow(described_class).to receive(:xref_edit_hash).with(u).and_return({"xref_name" => {key_label: "KEY LABEL", show_value_column: false, require_company: true}})
      csv = described_class.generate_csv("xref_name", u).split("\n")
      
      expect(csv[0].split(",")).to eq ["KEY LABEL", "Company", "Last Updated"]
      expect(csv[1].split(",").take(2)).to eq ["1111111111", "ACME (AC)"]
      expect(csv[2].split(",").take(2)).to eq ["3333333333", "ACME (AC)"]
    end
  end

  context "HM Pars" do

    let (:used_data_cross_reference) {
      DataCrossReference.create! cross_reference_type: DataCrossReference::HM_PARS_NUMBER, key: "PARS-USED", value: "1"
    }

    let (:unused_data_cross_reference) {
      DataCrossReference.add_hm_pars_number("Pars-Unused")
    }

    describe "find_and_mark_next_unused_hm_pars_number" do
      it "finds the next cross reference and marks it as being used" do
        used_data_cross_reference
        unused_data_cross_reference

        expect(DataCrossReference.find_and_mark_next_unused_hm_pars_number).to eq "Pars-Unused"
        expect(unused_data_cross_reference.reload.value).to eq "1"

        # If the cross reference was marked as used...then there should be no more left and nil shoudl be returned
        expect(DataCrossReference.find_and_mark_next_unused_hm_pars_number).to be_nil
      end
    end

    describe "unused_pars_count" do
      it "returns correct count of unused pars numbers" do
        used_data_cross_reference
        unused_data_cross_reference

        expect(DataCrossReference.unused_pars_count).to eq 1
      end

      it "returns zero if all pars numbers are utilized" do
        used_data_cross_reference
        expect(DataCrossReference.unused_pars_count).to eq 0
      end
    end
  end
end
