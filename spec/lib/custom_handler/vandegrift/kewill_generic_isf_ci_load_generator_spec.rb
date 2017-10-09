describe OpenChain::CustomHandler::Vandegrift::KewillGenericIsfCiLoadGenerator do
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  let (:importer) {
    Factory(:importer, alliance_customer_number: "CUST")
  }

  let (:isf) {
    isf = SecurityFiling.new broker_customer_number: "CUST", master_bill_of_lading: "MBOL", importer_id: importer.id
    isf_line = SecurityFilingLine.new part_number: "PART", po_number: "PO", country_of_origin_code: "COO", mid: "MID", hts_code: "12345678"
    isf.security_filing_lines << isf_line

    isf
  }

  describe "generate_entry_data" do  

    let (:cdefs) {
      self.class.prep_custom_definitions([:prod_part_number, :shpln_coo, :shpln_invoice_number])
    }

    let (:us) {
      Factory(:country, iso_code: "US")
    }

    context "with isf data only" do
      it "generates entry data" do
        e = subject.generate_entry_data isf
        expect(e).not_to be_nil

        expect(e.customer).to eq "CUST"
        expect(e.invoices.length).to eq 1

        i = e.invoices.first
        expect(i.invoice_lines.length).to eq 1

        line = i.invoice_lines.first
        expect(line.part_number).to eq "PART"
        expect(line.po_number).to eq "PO"
        expect(line.country_of_origin).to eq "COO"
        expect(line.hts).to eq "12345678"
        expect(line.mid).to eq "MID"
        expect(line.seller_mid).to eq "MID"
        expect(line.buyer_customer_number).to eq "CUST"
      end
    end

    context "with shipment data" do
      let (:product) {
        p = Factory(:product, unique_identifier: "UID", importer: importer)
        p.update_custom_value! cdefs[:prod_part_number], "PART"
        p.update_hts_for_country us, "1234567890"

        p
      }

      let (:factory) {
        Factory(:company, factory:true, mid: "POMID")
      }

      let (:order) {
        order = Factory(:order, order_number: "PO", customer_order_number: "PO", importer: importer, factory_id: factory.id)
        order.order_lines.create! product: product, price_per_unit: BigDecimal("1.50"), country_of_origin: "CA"

        order
      }

      let! (:shipment) {
        shipment = Factory(:shipment, importer: importer, master_bill_of_lading: "MBOL")
        line = shipment.shipment_lines.create! quantity: 10, linked_order_line_id: order.order_lines.first.id, product: product, carton_qty: 10, gross_kgs: BigDecimal("10.50")
        line = shipment.shipment_lines.create! quantity: 5, linked_order_line_id: order.order_lines.first.id, product: product, carton_qty: 5, gross_kgs: BigDecimal("5.5")

        shipment
      }

      it "references shipment to generate additional entry data" do
        e = subject.generate_entry_data isf
        expect(e).not_to be_nil

        expect(e.customer).to eq "CUST"
        expect(e.invoices.length).to eq 1

        i = e.invoices.first
        expect(i.invoice_lines.length).to eq 1

        line = i.invoice_lines.first
        expect(line.part_number).to eq "PART"
        expect(line.po_number).to eq "PO"
        expect(line.country_of_origin).to eq "COO"
        expect(line.mid).to eq "MID"
        expect(line.seller_mid).to eq "MID"
        expect(line.buyer_customer_number).to eq "CUST"

        expect(line.hts).to eq "1234567890"
        expect(line.cartons).to eq 15
        expect(line.gross_weight).to eq 16
        expect(line.pieces).to eq 15
        expect(line.unit_price).to eq BigDecimal("1.50")
        expect(line.foreign_value).to eq BigDecimal("22.50")
      end

      it "reference shipment by house bill" do
        isf.update_attributes! house_bills_of_lading: "HBOL"
        shipment.update_attributes! master_bill_of_lading: "", house_bill_of_lading: "HBOL"

        e = subject.generate_entry_data isf
        expect(e).not_to be_nil

        #Easiest way to determine that there was a shipment match is to check that there are cartons listed
        expect(e.invoices.length).to eq 1

        i = e.invoices.first
        expect(i.invoice_lines.length).to eq 1
        line = i.invoice_lines.first
        expect(line.cartons).to eq 15
      end

      it "uses isf tariff if product tariff doesn't match" do
        product.update_hts_for_country us, "0123456789"

        e = subject.generate_entry_data isf
        line = e.invoices.first.invoice_lines.first

        expect(line.hts).to eq "12345678"
      end

      it "uses shipment line's invoice number" do
        shipment.shipment_lines.each do |line|
          line.update_custom_value! cdefs[:shpln_invoice_number], "INV"
        end

        e = subject.generate_entry_data isf
        expect(e.invoices.length).to eq 1
        expect(e.invoices.first.invoice_number).to eq "INV"
      end

      it "uses shipment line's country of origin if ISF is missing" do
        isf.security_filing_lines.first.country_of_origin_code = ""
        order.order_lines.first.update_attributes! country_of_origin: ""

        shipment.shipment_lines.each do |line|
          line.update_custom_value! cdefs[:shpln_coo], "ID"
        end

        e = subject.generate_entry_data isf
        line = e.invoices.first.invoice_lines.first

        expect(line.country_of_origin).to eq "ID"
      end

      it "uses order line data to fill in missing ISF data" do
        line = isf.security_filing_lines.first
        line.country_of_origin_code = ""
        line.mid = ""

        e = subject.generate_entry_data isf
        line = e.invoices.first.invoice_lines.first

        expect(line.country_of_origin).to eq "CA"
        expect(line.mid).to eq "POMID"
      end

      context "with alternate output configurations" do
        let (:output_config) { KeyJsonItem.isf_config("CUST").first_or_create! json_data: {}.to_json }

        it "does not utilize shipment data if instructed" do
          output_config.update_attributes! json_data: {use_shipment: false}.to_json

          # If shipment data isn't utilized, then there should be no piece counts, weights, etc
          e = subject.generate_entry_data isf
          line = e.invoices.first.invoice_lines.first
          expect(line.hts).to eq "12345678"
          expect(line.cartons).to be_nil
          expect(line.gross_weight).to be_nil
          expect(line.pieces).to be_nil
          expect(line.unit_price).to be_nil
          expect(line.foreign_value).to be_nil
        end

        it "does not utilize shipment pieces if instructed" do
          output_config.update_attributes! json_data: {use_shipment_pieces: false}.to_json

          # If pieces aren't utilized, the value can't be calculated
          e = subject.generate_entry_data isf
          line = e.invoices.first.invoice_lines.first

          expect(line.pieces).to be_nil
          expect(line.foreign_value).to be_nil

          # Makes sure the other shipment line data populated
          expect(line.hts).to eq "1234567890"
          expect(line.cartons).to eq 15
          expect(line.gross_weight).to eq 16
          expect(line.unit_price).to eq BigDecimal("1.50")
        end

        it "does not utilize shipment gross weight if instructed" do
          output_config.update_attributes! json_data: {use_shipment_gross_weight: false}.to_json

          e = subject.generate_entry_data isf
          line = e.invoices.first.invoice_lines.first

          expect(line.gross_weight).to be_nil

          expect(line.hts).to eq "1234567890"
          expect(line.cartons).to eq 15
          expect(line.pieces).to eq 15
          expect(line.unit_price).to eq BigDecimal("1.50")
          expect(line.foreign_value).to eq BigDecimal("22.50")
        end

        it "does not utilize cartons if instructed" do
          output_config.update_attributes! json_data: {use_shipment_cartons: false}.to_json

          e = subject.generate_entry_data isf
          line = e.invoices.first.invoice_lines.first

          expect(line.cartons).to be_nil

          expect(line.hts).to eq "1234567890"
          expect(line.gross_weight).to eq 16
          expect(line.pieces).to eq 15
          expect(line.unit_price).to eq BigDecimal("1.50")
          expect(line.foreign_value).to eq BigDecimal("22.50")
        end

        it "does not utilize product hts if instructed" do
          output_config.update_attributes! json_data: {use_product_hts: false}.to_json

          e = subject.generate_entry_data isf
          line = e.invoices.first.invoice_lines.first

          expect(line.hts).to eq "12345678"

          # Verify the other data from the shipment line populated
          expect(line.gross_weight).to eq 16
          expect(line.cartons).to eq 15
          expect(line.pieces).to eq 15
          expect(line.unit_price).to eq BigDecimal("1.50")
          expect(line.foreign_value).to eq BigDecimal("22.50")
        end
      end
    end
  end

  describe "generate_and_send" do

    it "generates isf data, generates an excel workbook and sends to google drive" do
      gen = instance_double(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator)
      expect(subject).to receive(:kewill_generator).and_return gen
      data = "data"
      expect(subject).to receive(:generate_entry_data).and_return data
      expect(gen).to receive(:generate_xls_to_google_drive).with("CUST CI Load/MBOL.xls", [data])

      subject.generate_and_send isf
    end
  end


  describe "drive_path" do

    it "uses masterbill to geneate drive path" do
      expect(subject.drive_path isf).to eq "CUST CI Load/MBOL.xls"
    end

    it "falls back to house bill if master bill is blank" do 
      isf.master_bill_of_lading = ""
      isf.house_bills_of_lading = "HBOL"
      expect(subject.drive_path isf).to eq "CUST CI Load/HBOL.xls"
    end
  end
end