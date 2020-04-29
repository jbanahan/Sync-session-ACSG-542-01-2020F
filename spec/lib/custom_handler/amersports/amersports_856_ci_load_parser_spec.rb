describe OpenChain::CustomHandler::AmerSports::AmerSports856CiLoadParser do

  let (:data) {
    File.read 'spec/fixtures/files/amersports_856.dat'
  }

  describe "parse" do
    let (:importer) { with_customs_management_id(Factory(:importer, system_code: "WILSON"), "WILSON") }
    let (:us) { Factory(:country, iso_code: "US") }
    let (:product_1) {
      p = Factory(:product, unique_identifier: "WILSON-WTDPCH00251", importer: importer)
      c = p.classifications.create! country_id: us.id
      c.tariff_records.create! hts_1: "1234567890"
      p
    }
    let (:product_2) {
      p = Factory(:product, unique_identifier: "WILSON-WTDPCH00218", importer: importer)
      c = p.classifications.create! country_id: us.id
      c.tariff_records.create! hts_1: "1234567890"
      p
    }

    let (:entries) { [] }

    before :each do
      expect(described_class).to receive(:delay).and_return described_class
      allow_any_instance_of(described_class).to receive(:generate_xls_to_google_drive) do |inst, path, invoice|
        entries << invoice
      end
    end

    context "with products" do
      before :each do
        product_1
        product_2
      end

      it "parses an 856 file into workbook" do
        described_class.parse data
        expect(entries.length).to eq 1

        e = entries.first

        expect(e.customer).to eq "WILSON"
        expect(e.invoices.length).to eq 1
        inv = e.invoices.first

        expect(inv.invoice_number).to eq "LD161214"
        expect(inv.invoice_date).to eq Date.new(2016, 12, 14)

        expect(inv.invoice_lines.length).to eq 2

        line = inv.invoice_lines.first

        expect(line.country_of_origin).to eq "CN"
        expect(line.part_number).to eq "WTDPCH00251"
        expect(line.po_number).to eq "5301428515"
        expect(line.pieces).to eq 180
        expect(line.hts).to eq "1234567890"
        expect(line.foreign_value).to eq 2511
        expect(line.cartons).to eq 37
        expect(line.gross_weight).to eq 273

        line = inv.invoice_lines.second

        expect(line.country_of_origin).to eq "CN"
        expect(line.part_number).to eq "WTDPCH00218"
        expect(line.po_number).to eq "5301428518"
        expect(line.pieces).to eq 780
        expect(line.hts).to eq "1234567890"
        expect(line.foreign_value).to eq 7137
        expect(line.cartons).to be_nil
        expect(line.gross_weight).to be_nil
      end

      it "parses part number differently for non-Wilson accounts and translates Atomic to Salomon account" do
        with_customs_management_id(Factory(:importer, system_code: "SALOMON"), "SALOMON")
        # This also tests that ATOMIC is translated to Salomon
        described_class.parse data.gsub("WILSON    ", "ATOMIC    ")
        expect(entries.length).to eq 1

        line = entries.first.invoices.first.invoice_lines.first

        expect(line.part_number).to eq "TDPCH0"
      end

      it "translates ARMADA to Salomon account" do
        with_customs_management_id(Factory(:importer, system_code: "SALOMON"), "SALOMON")
        described_class.parse data.gsub("WILSON    ", "ARMADA    ")
        expect(entries.length).to eq 1

        line = entries.first.invoices.first.invoice_lines.first

        expect(line.part_number).to eq "TDPCH0"
      end

      it "handles invalid importer code" do
        expect {described_class.parse data.gsub("WILSON    ", "BOGUS     ")}.to raise_error "Invalid AMERSPORTS Importer code received: 'BOGUS'."
      end

      it "doesn't process PRECOR files" do
        described_class.parse data.gsub("WILSON    ", "PRECOR    ")
        expect(entries.length).to eq 0
      end
    end

    context "without products" do
      before :each do
        importer
        us
      end

      it "doesn't roll lines together if products aren't found - even if tariff numbers are the same" do
        described_class.parse data
        inv = entries.first.invoices.first

        expect(inv.invoice_lines.length).to eq 2

        line = inv.invoice_lines.first

        expect(line.country_of_origin).to eq "CN"
        expect(line.part_number).to eq "WTDPCH00251"
        expect(line.po_number).to eq "5301428515"
        expect(line.pieces).to eq 180
        expect(line.hts).to eq "950699"
        expect(line.foreign_value).to eq 2511

        line = inv.invoice_lines.second

        expect(line.country_of_origin).to eq "CN"
        expect(line.part_number).to eq "WTDPCH00218"
        expect(line.po_number).to eq "5301428518"
        expect(line.pieces).to eq 780
        expect(line.hts).to eq "950699"
        expect(line.foreign_value).to eq 7137
      end
    end

    it "raises an error if importer is missing" do
      expect {described_class.parse data}.to raise_error "Unable to find AmerSports importer account with code 'WILSON'."
    end

    it "raises an error if US country isn't found" do
      # The country is only referenced when looking up product tariff data, so it
      # the product needs to be set.
      product_1
      us.destroy

      expect {described_class.parse data}.to raise_error "Unable to find US country."
    end

  end
end