describe OpenChain::CustomHandler::VfitrackCustomDefinitionSupport do
  it "should load custom definitions" do
    k = Class.new do
      include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
    end

    defs = k.prep_custom_definitions [:shpln_po, :shpln_sku, :shpln_color, :shpln_size, :shpln_desc, :shpln_coo, :shpln_received_date, :shpln_uom]
    expected = [
      [:shpln_po, 'PO Number', 'string', 'ShipmentLine'],
      [:shpln_sku, 'SKU', 'string', 'ShipmentLine'],
      [:shpln_color, 'Color', 'string', 'ShipmentLine'],
      [:shpln_size, 'Size', 'string', 'ShipmentLine'],
      [:shpln_desc, 'Description', 'string', 'ShipmentLine'],
      [:shpln_coo, 'Country of Origin ISO', 'string', 'ShipmentLine'],
      [:shpln_received_date, 'Received Date', 'date', 'ShipmentLine'],
      [:shpln_uom, 'UOM', 'string', 'ShipmentLine']
    ]
    expected.each do |e|
      cd = defs[e[0]]
      expect(cd.label).to eq(e[1])
      expect(cd.data_type).to eq(e[2])
      expect(cd.module_type).to eq(e[3])
    end
  end
end
