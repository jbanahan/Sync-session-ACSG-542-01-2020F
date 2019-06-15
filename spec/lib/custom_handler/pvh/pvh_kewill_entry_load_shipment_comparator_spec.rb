describe OpenChain::CustomHandler::Pvh::PvhKewillEntryLoadShipmentComparator do

  subject { described_class }

  describe "has_entry_load_configured?" do
    let (:importer) { Factory(:importer, system_code: "PVH") }

    let (:shipment) {
      Factory(:shipment, importer:importer, country_import: Factory(:country, iso_code: "US"))
    }

    it "returns true for US shipments" do
      expect(subject.has_entry_load_configured? shipment).to eq true
    end

    it "returns false for other countries" do
      shipment.update_attributes! country_import_id: Factory(:country, iso_code: "!S").id
      shipment.reload

      expect(subject.has_entry_load_configured? shipment).to eq false
    end

    it "returns false if importer is not PVH" do
      importer.update_attributes! system_code: "NOTPVH"
      
      expect(subject.has_entry_load_configured? shipment).to eq false
    end    
  end
end