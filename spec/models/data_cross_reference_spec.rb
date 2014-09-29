require 'spec_helper'

describe DataCrossReference do

  context :hash_for_type do
    it "should find all for reference" do
      csv = "k,v\nk2,v2"
      described_class.load_cross_references csv, 'xref_type'
      described_class.create!(key:'ak',value:'av',cross_reference_type:'xrt')
      described_class.hash_for_type('xref_type').should == {'k'=>'v','k2'=>'v2'}
    end
  end

  context :get_all_pairs do
    it "should get all pairs for a cross reference type" do
      described_class.create!(key:'a',value:'b',cross_reference_type:'x')
      described_class.create!(key:'c',value:'d',cross_reference_type:'x')
      described_class.create!(key:'dontfind',value:'d',cross_reference_type:'z')
      h = {'a'=>'b','c'=>'d'}
      expect(described_class.get_all_pairs('x')).to eq h
    end
  end
  context :load_cross_references do
    it "should load csv cross reference data from an IO object" do
      # Make sure we're also updating existing xrefs
      DataCrossReference.create! :company_id=>1, :key=>"key2", :value=>"", :cross_reference_type=>'xref_type'
      csv = "key,value\nkey2,value2\n"

      DataCrossReference.load_cross_references csv, 'xref_type', 1

      xrefs = DataCrossReference.where(:company_id=>1, :cross_reference_type=>'xref_type').order("created_at ASC, id ASC")
      xrefs.length.should == 2
      xrefs.first.key.should == "key2"
      xrefs.first.value.should == "value2"

      xrefs.last.key.should == "key"
      xrefs.last.value.should == "value"
    end
  end

  context :jjill_order_fingerprint do
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
  context :lenox_item_master_hash do
    it "should find" do
      described_class.create! key: 'partno', value:'ABCDEFG', cross_reference_type:described_class::LENOX_ITEM_MASTER_HASH
      expect(described_class.find_lenox_item_master_hash('partno')).to eq 'ABCDEFG'
    end
    it "should create" do
      described_class.create_lenox_item_master_hash! 'part_no', 'hashval'
      expect(described_class.where(key:'part_no',value:'hashval',cross_reference_type:described_class::LENOX_ITEM_MASTER_HASH).count).to eq 1
    end
  end
  context :find_rl_profit_center do
    it "should find an rl profit center from the brand code" do
      company = Factory(:importer)
      DataCrossReference.create! :key=>"brand", :value=>"profit center", :cross_reference_type=>DataCrossReference::RL_BRAND_TO_PROFIT_CENTER, company_id: company.id

      expect(DataCrossReference.find_rl_profit_center_by_brand(company.id, 'brand')).to eq "profit center"
    end
  end

  context :find_rl_brand do
    it "should find an rl brand code from PO number" do
      DataCrossReference.create! :key=>"po#", :value=>"brand", :cross_reference_type=>DataCrossReference::RL_PO_TO_BRAND

      DataCrossReference.find_rl_brand_by_po('po#').should == "brand"
    end
  end

  context :find_ua_plant_to_iso do
    it "should find" do
      described_class.create!(key:'x',value:'y',cross_reference_type:described_class::UA_PLANT_TO_ISO)
      described_class.find_ua_plant_to_iso('x').should == 'y'
    end
  end
  context :find_ua_winshuttle_hts do
    it "should find" do
      described_class.create!(key:'x',value:'y',cross_reference_type:described_class::UA_WINSHUTTLE)
      described_class.find_ua_winshuttle_hts('x').should == 'y'
    end
  end
  context :find_ua_material_color_plant do
    it "should find" do
      described_class.create!(key:'x-y-z',value:'a',cross_reference_type:described_class::UA_MATERIAL_COLOR_PLANT)
      described_class.find_ua_material_color_plant('x','y','z').should == 'a'
    end
  end
  context :create_ua_material_color_plant! do
    it "should create" do
      described_class.create_ua_material_color_plant! 'x','y','z'
      described_class.find_ua_material_color_plant('x','y','z').should == '1'
    end
  end
  context :add_xref! do
    it "should add" do
      d = described_class.add_xref! described_class::UA_PLANT_TO_ISO, 'x', 'y', 1
      d = described_class.find d.id
      d.cross_reference_type.should == described_class::UA_PLANT_TO_ISO
      d.key.should == 'x'
      d.value.should == 'y'
      d.company_id.should == 1
    end
  end

  describe "has_key?" do
    it "determines if an xref key is present in the db table" do
      DataCrossReference.add_xref! DataCrossReference::UA_PLANT_TO_ISO, 'x', 'y', 1
      expect(DataCrossReference.has_key? 'x', DataCrossReference::UA_PLANT_TO_ISO).to be_true
      expect(DataCrossReference.has_key? 'askjfda', DataCrossReference::UA_PLANT_TO_ISO).to be_false
      expect(DataCrossReference.has_key? nil, DataCrossReference::UA_PLANT_TO_ISO).to be_false
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
    it "returns information about xref screens user has access to" do
      # At the moment, only polo system has xrefs
      MasterSetup.any_instance.stub(:system_code).and_return "polo"

      xrefs = DataCrossReference.xref_edit_hash User.new

      expect(xrefs.size).to eq 2
      expect(xrefs['rl_fabric']).to eq title: "MSL+ Fabric Cross References", description: "Enter the starting fabric value in the Failure Fiber field and the final value to send to MSL+ in the Approved Fiber field.", identifier: 'rl_fabric', key_label: "Failure Fiber", value_label: "Approved Fiber", show_value_column: true
      expect(xrefs['rl_valid_fabric']).to eq title: "MSL+ Valid Fabric List", description: "Only values included in this list are allowed to be sent to to MSL+.", identifier: 'rl_valid_fabric', key_label: "Approved Fiber", value_label: "Value", show_value_column: false
    end
  end

  describe "can_view?" do
    context "polo system" do
      before :each do
        MasterSetup.any_instance.stub(:system_code).and_return "polo"
      end

      it "allows access to RL Fabrix xref for anyone" do
        expect(DataCrossReference.can_view? 'rl_fabric', User.new).to be_true
      end

      it "allows access to RL Value Fabirc xref for anyone" do
        expect(DataCrossReference.can_view? 'rl_valid_fabric', User.new).to be_true
      end

    end
  end
end
