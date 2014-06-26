require 'spec_helper'

describe CustomReportContainerListing do
  before :each do
    @u = Factory(:master_user)
    @u.company.update_attributes(:broker=>true)
    @u.stub(:view_entries?).and_return true
  end
  describe :static_methods do
    it "should allow users who can view entries" do
      described_class.can_view?(@u).should be_true
    end

    it "should not allow users who cannot view entries" do
      @u.stub(:view_entries?).and_return false
      described_class.can_view?(@u).should be_false
    end

    it "should allow parameters for all entry fields" do
      described_class.criterion_fields_available(@u).should == CoreModule::ENTRY.model_fields(@u).values
    end
  end

  describe :run do
    it "should make a row for each container" do
      ent = Factory(:entry,:container_numbers=>"123\n456",:broker_reference=>"ABC")
      rpt = described_class.new
      rpt.search_columns.build(:rank=>0,:model_field_uid=>:ent_brok_ref)
      arrays = rpt.to_arrays @u
      arrays.should have(3).rows
      expect(arrays[0]).to eq ["Container Number", "Broker Reference"]
      expect(arrays[1]).to eq ["123", "ABC"]
      expect(arrays[2]).to eq ["456", "ABC"]
    end

    it "includes weblinks" do
      ms = double("MasterSetup")
      MasterSetup.stub(:get).and_return ms
      ms.stub(:request_host).and_return "localhost"

      ent = Factory(:entry,:container_numbers=>"123\n456",:broker_reference=>"ABC")
      rpt = described_class.new include_links: true
      rpt.search_columns.build(:rank=>0,:model_field_uid=>:ent_brok_ref)

      arrays = rpt.to_arrays @u
      expect(arrays[0]).to eq ["Web Links", "Container Number", "Broker Reference"]
      expect(arrays[1]).to eq [ent.excel_url, "123", "ABC"]
    end
  end
end
