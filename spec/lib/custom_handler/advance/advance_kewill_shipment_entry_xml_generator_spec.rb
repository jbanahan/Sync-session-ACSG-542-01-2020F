describe OpenChain::CustomHandler::Advance::AdvanceKewillShipmentEntryXmlGenerator do

  describe "generate_xml" do
    let (:importer) {
      with_customs_management_id(FactoryBot(:importer), "ADVAN")
    }

    let (:us) {
      FactoryBot(:country, iso_code: "US")
    }

    let (:cdefs) {
      subject.send(:cdefs)
    }

    let (:product) {
      p = FactoryBot(:product, name: "Part Description")
      c = p.classifications.create! country_id: us.id
      c.tariff_records.create! hts_1: "1234509876"
      p.update_custom_value! cdefs[:prod_part_number], "PARTNO"
      p
    }

    let (:order) {
      o = FactoryBot(:order, customer_order_number: "ORDER")
      l = FactoryBot(:order_line, product: product, order: o, country_of_origin: "CN", price_per_unit: 10)
      o
    }

    let (:shipment) {
      s = Shipment.create! reference: "REF", master_bill_of_lading: "MBOL", house_bill_of_lading: "CARR123456789012", vessel: "VESSEL", voyage: "VOYAGE", vessel_carrier_scac: "CARR", mode: "Ocean", est_arrival_port_date: Date.new(2018, 4, 1), departure_date: Date.new(2018, 3, 1), est_departure_date: Date.new(2018, 3, 3), importer_id: importer.id, country_export: us
      container = s.containers.create! container_number: "CONTAINER", seal_number: "SEAL", container_size: "20FT"

      shipment_line_1 = s.shipment_lines.build gross_kgs: BigDecimal("10"), carton_qty: 20, invoice_number: "INV", quantity: 30, container_id: container.id
      shipment_line_1.linked_order_line_id = order.order_lines.first.id
      shipment_line_1.product_id = order.order_lines.first.product.id
      shipment_line_1.save!

      shipment_line_2 = s.shipment_lines.build gross_kgs: BigDecimal("40"), carton_qty: 50, invoice_number: "INV", quantity: 60, container_id: container.id
      shipment_line_2.linked_order_line_id = order.order_lines.first.id
      shipment_line_2.product_id = order.order_lines.first.product.id
      shipment_line_2.save!

      s.reload

      s
    }

    it "generates ADVAN data" do
      data = subject.generate_kewill_shipment_data shipment

      expect(data.customer).to eq "ADVAN"
      expect(data.consignee_code).to eq "ADVAN"
      expect(data.ultimate_consignee_code).to eq "ADVAN"

      # The only difference here between the primary generator and the ADVAN specific one is that this one
      # doesn't generate bol records and sets an Edi Identifier
      expect(data.edi_identifier).not_to be_nil
      expect(data.edi_identifier.master_bill).to eq "123456789012"
      expect(data.edi_identifier.scac).to eq "CARR"

      expect(data.bills_of_lading).to be_blank

      # Just do a totally cursory check that other data is being generated...
      expect(data.containers.length).to eq 1
      c = data.containers.first
      expect(c.container_number).to eq "CONTAINER"

      expect(data.dates.length).to eq 2
      expect(data.invoices.length).to eq 1

      inv = data.invoices.first
      expect(inv.file_number).to eq "123456789012"

      line = inv.invoice_lines.first
      # Make sure the invoice's pieces are the expected value (without sets)
      expect(line.pieces).to eq 30
      expect(line.country_of_export).to eq "US"
      expect(line.hts).to be_nil
      expect(line.pieces_uom).to eq "NO"
      expect(line.unit_price_uom).to eq "PCS"
    end

    it "generates CQ data, using CQSOU for customer number" do
      # CQ piece counts should include set calculations
      importer.system_identifiers.first.update! code: "CQ"

      data = subject.generate_kewill_shipment_data shipment

      expect(data.customer).to eq "CQSOU"
      expect(data.consignee_code).to eq "CQSOU"
      expect(data.ultimate_consignee_code).to eq "CQSOU"
    end

  end
end