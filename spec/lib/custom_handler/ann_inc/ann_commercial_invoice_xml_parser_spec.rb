describe OpenChain::CustomHandler::AnnInc::AnnCommercialInvoiceXmlParser do

  let (:xml) { IO.read "spec/fixtures/files/ann_commercial_invoice.xml"}
  let (:document) { REXML::Document.new xml }
  let (:middleman_document) { REXML::Document.new IO.read("spec/fixtures/files/ann_commercial_invoice_middleman.xml")}
  let (:discounts_document) { REXML::Document.new IO.read("spec/fixtures/files/ann_commercial_invoice_discounts.xml")}
  let (:factory) { Company.create! factory: true, name: "ANN Factory", mid: "MID12345" }
  let! (:po) { Factory(:order, importer: ann, factory: factory, customer_order_number: "6238635") }
  let! (:ann) { Factory(:importer, system_code: "ATAYLOR", alliance_customer_number: "ATAYLOR") }

  describe "parse" do

    let! (:product) {
      p = Factory(:product, importer: ann, unique_identifier: "ATAYLOR-419488")
      c = p.classifications.create! country: Factory(:country, iso_code: "US")
      t = c.tariff_records.create! hts_1: "1234567890"
    }

    it "parses a commercial invoice" do
      kg = instance_double(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator)
      invoice = nil
      expect(kg).to receive(:generate_xls_to_google_drive) do |path, invoice_data|
        expect(path).to eq "Ann CI Load/435_1181_17_HK.xls"
        invoice = invoice_data.first
      end
      expect(subject).to receive(:kewill_generator).and_return kg
      # Mock this out for now, we'll test it more thoroughly below
      expect(subject).to receive(:us_hts).with("419488").and_return "1234567890"

      subject.parse(document)

      expect(invoice).not_to be_nil

      expect(invoice.customer).to eq "ATAYLOR"
      expect(invoice.invoices.length).to eq 1
      i = invoice.invoices.first

      expect(i.invoice_number).to eq "435/1181/17/HK"
      expect(i.currency).to eq "USD"
      expect(i.exchange_rate).to eq BigDecimal("1.0")
      expect(i.invoice_date).to eq Date.new(2017, 4, 9)

      expect(i.invoice_lines.length).to eq 1

      line = i.invoice_lines.first

      expect(line.po_number).to eq "6238635"
      expect(line.part_number).to eq "419488"
      expect(line.country_of_origin).to eq "ID"
      expect(line.quantity_2).to eq BigDecimal("669.8")
      expect(line.pieces).to eq 1457
      expect(line.hts).to eq "1234567890"
      expect(line.foreign_value).to eq BigDecimal("16187.27")
      expect(line.unit_price).to eq BigDecimal("11.11")
      expect(line.quantity_1).to eq 1457
      expect(line.department).to eq "226"
      expect(line.buyer_customer_number).to eq "ATAYLOR"
      expect(line.cartons).to eq 34
      expect(line.mid).to eq "MID12345"
      # There's no charges so the ndc should be blank
      expect(line.non_dutiable_amount).to be_nil
    end

    it "handles middleman charges" do 
      kg = instance_double(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator)
      invoice = nil
      expect(kg).to receive(:generate_xls_to_google_drive) do |path, invoice_data|
        invoice = invoice_data.first
      end
      expect(subject).to receive(:kewill_generator).and_return kg
      # Mock this out for now, we'll test it more thoroughly below
      expect(subject).to receive(:us_hts).with("419488").and_return "1234567890"

      subject.parse(middleman_document)

      i = invoice.invoices.first
      line = i.invoice_lines.first
      expect(line.non_dutiable_amount).to eq BigDecimal("-100")
      expect(line.first_sale).to eq BigDecimal("16386.27")
    end

    it "handles discounts totalling higher than middleman charges" do 
      kg = instance_double(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator)
      invoice = nil
      expect(kg).to receive(:generate_xls_to_google_drive) do |path, invoice_data|
        invoice = invoice_data.first
      end
      expect(subject).to receive(:kewill_generator).and_return kg
      # Mock this out for now, we'll test it more thoroughly below
      expect(subject).to receive(:us_hts).with("419488").and_return "1234567890"

      subject.parse(discounts_document)

      i = invoice.invoices.first
      line = i.invoice_lines.first
      expect(line.non_dutiable_amount).to eq BigDecimal("-101")
      expect(line.first_sale).to be_nil
      # Unit price calculation should come after discounts are added back in
      expect(line.unit_price).to eq BigDecimal("11.18")
    end

    it "converts weight in LB to KG" do
      expect(subject).to receive(:us_hts).with("419488").and_return "1234567890"

      element = REXML::XPath.first(document, "/UniversalInterchange/Body/UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/NetWeightUnit/Code")
      element.text = "LB"

      entry = nil
      expect(subject).to receive(:send_invoice) do |invoice|
        entry = invoice
      end

      subject.parse(document)

      expect(entry).not_to be_nil

      line = entry.invoices.first.invoice_lines.first

      expect(line.quantity_2).to eq BigDecimal("303.82")
    end

    it "handles missing orders" do
      expect(subject).to receive(:us_hts).with("419488").and_return "1234567890"
      po.destroy
      entry = nil
      expect(subject).to receive(:send_invoice) do |invoice|
        entry = invoice
      end

      subject.parse(document)
      line = entry.invoices.first.invoice_lines.first
      expect(line.mid).to be_nil
    end

    it "handles missing factory" do
      expect(subject).to receive(:us_hts).with("419488").and_return "1234567890"
      po.factory = nil
      po.save!
      entry = nil
      expect(subject).to receive(:send_invoice) do |invoice|
        entry = invoice
      end

      subject.parse(document)
      line = entry.invoices.first.invoice_lines.first
      expect(line.mid).to be_nil
    end
  end

  describe "us_hts" do
    let (:api_client) {
      instance_double(OpenChain::Api::ProductApiClient)
    }

    let (:inner_repsonse) {
      {
        "classifications" => [
          {"class_cntry_iso" => "CA"},
          {"class_cntry_iso" => "US",
            "tariff_records" => [
              {"hts_hts_1" => "1234567890"}
            ]
          }
        ]
      }
    }

    let (:uid_response) {
      {"product" => inner_repsonse }
    }

    before :each do
      allow(subject).to receive(:api_client).and_return api_client
    end

    it "uses api client to find tariff data from ann system by unique identifier" do
      expect(api_client).to receive(:find_by_uid).with("12345", ["class_cntry_iso", "hts_hts_1"]).and_return uid_response

      expect(subject.us_hts("12345")).to eq "1234567890"
    end

    it "looks for hts by related styles if unique id search is invalid" do
      expect(api_client).to receive(:find_by_uid).with("12345", ["class_cntry_iso", "hts_hts_1"]).and_return({"product" => nil})
      expect(api_client).to receive(:search) do |params|
        expect(params[:fields]).to eq ["class_cntry_iso", "hts_hts_1"]
        expect(params[:search_criterions].length).to eq 1
        c = params[:search_criterions].first
        expect(c.model_field_uid).to eq "*cf_35"
        expect(c.operator).to eq "co"
        expect(c.value).to eq "12345"

        expect(params[:per_page]).to eq 1
        

        {"results" => [inner_repsonse]}
      end

      expect(subject.us_hts("12345")).to eq "1234567890"
    end
  end
end