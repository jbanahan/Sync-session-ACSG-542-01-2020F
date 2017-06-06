describe OpenChain::CustomHandler::AmerSports::AmerSports856CiLoadParser do

  let (:data) {
    File.read 'spec/fixtures/files/amersports_856.dat'
  }

  describe "parse" do
    let (:importer) { Factory(:importer, system_code: "WILSON", alliance_customer_number: "WILSON") }
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
        expect(inv.invoice_date).to eq Date.new(2016,12,14)

        # Since they have the same tariff / country of origin...the two lines should be 
        # rolled up into a single one
        expect(inv.invoice_lines.length).to eq 1

        line = inv.invoice_lines.first

        expect(line.country_of_origin).to eq "CN"
        expect(line.part_number).to be_nil
        expect(line.po_number).to eq "5301428515"
        expect(line.pieces).to eq 960
        expect(line.hts).to eq "1234567890"
        expect(line.foreign_value).to eq 9648
        expect(line.cartons).to eq 37
        expect(line.gross_weight).to eq 273
      end

      it "parses part number differently for non-Wilson accounts" do
        Factory(:importer, system_code: "ATOMIC", alliance_customer_number: "ATOMI") 
        described_class.parse data.gsub("WILSON    ", "ATOMIC    ")
        expect(entries.length).to eq 1

        line = entries.first.invoices.first.invoice_lines.first

        expect(line.part_number).to eq "TDPCH0"
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
        expect(line.cartons).to eq 37
        expect(line.gross_weight).to eq 273

        line = inv.invoice_lines.second

        expect(line.country_of_origin).to eq "CN"
        expect(line.part_number).to eq "WTDPCH00218"
        expect(line.po_number).to eq "5301428518"
        expect(line.pieces).to eq 780
        expect(line.hts).to eq "950699"
        expect(line.foreign_value).to eq 7137
        # Cartons and Gross weight are only carried to the first line because they 
        # come from the invoice header level in the file
        expect(line.cartons).to be_nil
        expect(line.gross_weight).to be_nil
      end

      it "doesn't roll products together if the hts numbers are different" do
        product_1
        product_2

        product_2.classifications.first.tariff_records.first.update_attributes! hts_1: "9876543210"

        described_class.parse data
      inv = entries.first.invoices.first

        expect(inv.invoice_lines.length).to eq 2
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