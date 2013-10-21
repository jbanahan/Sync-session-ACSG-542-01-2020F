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

  context :find_rl_profit_center do
    it "should find an rl profit center from the brand code" do
      DataCrossReference.create! :key=>"brand", :value=>"profit center", :cross_reference_type=>DataCrossReference::RL_BRAND_TO_PROFIT_CENTER

      DataCrossReference.find_rl_profit_center_by_brand('brand').should == "profit center"
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
end
