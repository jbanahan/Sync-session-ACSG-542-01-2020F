require 'spec_helper'

describe OpenChain::CustomHandler::CustomerInvoiceHandler do
  let!(:cf) { instance_double("CustomFile") }
  let!(:parser) { described_class.new cf }
  
  describe "can_view" do
    let(:u) { Factory(:master_user) }
    let!(:ms) do
      ms = stub_master_setup
      allow(MasterSetup).to receive(:get).and_return ms
      ms
    end

    it "allows access to master users when feature is enabled" do
      allow(ms).to receive(:custom_feature?).with("Customer Invoice Uploader").and_return true
      expect(parser.can_view? u).to eq true
    end

    it "prevents access to non-master users" do
      allow(ms).to receive(:custom_feature?).with("Customer Invoice Uploader").and_return true
      u.company.update_attributes! master: false
      expect(parser.can_view? u).to eq false
    end

    it "prevents access when feature isn't enabled" do
      allow(ms).to receive(:custom_feature?).with("Customer Invoice Uploader").and_return false
      expect(parser.can_view? u).to eq false
    end
  end

  describe "process" do
    let!(:imp) { Factory(:importer, system_code: "ACME")}
    let(:user) { Factory(:user, email: "tufnel@stonehenge.biz") }
    let!(:china) { Factory(:country, iso_code: "CN") }
    let!(:pakistan) { Factory(:country, iso_code: "PK") }
    let!(:indonesia) { Factory(:country, iso_code: "ID") }
    let(:header) {["Invoice Number", "Vendor Name ", "Factory Name", "Invoice Total - Foreign ", "Currency", "Invoice Line - PO Number", "Invoice Line - Middleman Charge", "Invoice Line - Discount - Air/Sea", "Invoice Line - Discount - Early Payment", "Invoice Line - Discount - Trade", "Invoice Line - Part Number", "Invoice Line - Part Description ", "Invoice Date", "Customer Reference Number", "Description of Goods", "Invoice Total - Domestic", "Total Discounts", "Total Charges", "Exchange Rate", "Net Invoice", "Total Net Weight", "Net Weight UOM", "Origin Country ISO Code", "Payment Terms", "Sale Terms", "Ship Mode", "Total Gross Weight", "Total Gross Weight UOM", "Total Volume", "Total Volume UOM", "Invoice Line - Department", "Invoice Line - Export Country ISO Code", "Invoice Line - First Sale", "Invoice Line - Fish and Wildlife", "Invoice Line - Gross Weight", "Invoice Line - Gross Weight UOM ", "Invoice Line - HTS Number ", "Invoice Line - Line Number", "Invoice Line - Mid", "Invoice Line - Net Weight ", "Invoice Line - Net Weight UOM", "Invoice Line - Origin Country ISO Code", "Invoice Line - Pieces", "Invoice Line - Quantity", "Invoice Line - Quantity UOM", "Invoice Line - Unit Price", "Invoice Line - Value - Domestic", "Invoice Line - Value - Foreign", "Invoice Line - Volume", "Invoice Line - Volume UOM"]}
    #                 0            1           2          3      4        5        6      7     8     9         10            11             12            13            14           15     16     17     18    19    20       21          22        23             24             25         26           27               28          29             30      31    32    33   34       35            36   37    38     39         40         41    42  43      44       45    46     47    48      49
    let(:row_1) {["inv num 1", "Vendor 1", "Factory 1", 23.50, "EUR", "PO num 1", 1.25, 2.25, 3.25, 4.25, "part num 1", "part descr 1", "2018-01-01", "cust ref 1", "goods descr 1", 51.10, 21.10, 25.10, 0.50, 61.1, 2.1, "net wt uom 1", "CN", "pay terms 1", "sale terms 1", "ship mode 1", 7.1, "total gross wt uom 1", 5.1, "total vol uom 1", "dept 1", "PK", false, true, 7, "gross wt uom 1", "1111", 1, "MID 1", 8.1, "net wt uom 1", "ID", 101,  3, "qty uom 1", 10.1, 20.1, 25.1, 15.1, "vol uom 1"]}
    let(:row_2) {["inv num 1", "Vendor 1", "Factory 1", 23.50, "EUR", "PO num 2", 1.26, 2.26, 3.26, 4.26, "part num 2", "part descr 2", "2018-01-01", "cust ref 1", "goods descr 1", 51.10, 21.10, 25.10, 0.50, 61.1, 2.1, "net wt uom 1", "CN", "pay terms 1", "sale terms 1", "ship mode 1", 7.1, "total gross wt uom 1", 5.1, "total vol uom 1", "dept 2", "ID", true, false, 8, "gross wt uom 2", "2222", 2, "MID 2", 8.2, "net wt uom 2", "PK", 102, 4, "qty uom 2", 10.2, 20.2, 25.2, 15.2, "vol uom 2"]}
    let(:row_3) {["inv num 2", "Vendor 2", "Factory 2", 23.50, "GBP", "PO num 3", 1.27, 2.27, 3.27, 4.27, "part num 3", "part descr 3", "2018-01-02", "cust ref 2", "goods descr 2", 51.11, 21.11, 25.11, 0.51, 61.2, 2.2, "net wt uom 2", "PK", "pay terms 2", "sale terms 2", "ship mode 2", 7.2, "total gross wt uom 2", 5.2, "total vol uom 2", "dept 3", "CN", false, true, 9, "gross wt uom 3", "3333", 3, "MID 2", 8.3, "net wt uom 3", "CN", 103, 4, "qty uom 3",  10.3, 20.3, 25.3, 15.3, "vol uom 3"]}

    before do
      allow(cf).to receive(:path).and_return "/path/to/file.xlsx"
      allow(cf).to receive(:attached_file_name).and_return "file.xlsx"
      expect_any_instance_of(described_class::Parser).to receive(:foreach).with(cf).and_yield(header).and_yield(row_1).and_yield(row_2).and_yield(row_3)
    end

    it "creates new invoices" do
      parser.process user, {'cust_num' => 'ACME'}
      expect(Invoice.count).to eq 2
      inv = Invoice.first
      expect(inv.invoice_lines.count).to eq 2
      line = inv.invoice_lines.first

      expect(inv.manually_generated?).to eq true
      expect(inv.invoice_number).to eq "inv num 1"
      expect(inv.vendor.name).to eq "Vendor 1"
      expect(inv.vendor.system_code).to eq "ACME-VENDOR-Vendor 1"
      expect(inv.factory.name).to eq "Factory 1"
      expect(inv.factory.system_code).to eq "ACME-FACTORY-Factory 1"
      expect(inv.invoice_total_foreign).to eq 23.50
      expect(inv.currency).to eq "EUR"
      expect(line.po_number).to eq "PO num 1"
      expect(line.middleman_charge).to eq 1.25
      expect(line.air_sea_discount).to eq 2.25
      expect(line.early_pay_discount).to eq 3.25
      expect(line.trade_discount).to eq 4.25
      expect(line.part_number).to eq "part num 1"
      expect(line.part_description).to eq "part descr 1"
      expect(inv.invoice_date).to eq Date.new(2018,1,1)
      expect(inv.customer_reference_number).to eq "cust ref 1"
      expect(inv.description_of_goods).to eq "goods descr 1"
      expect(inv.invoice_total_domestic).to eq 51.10
      expect(inv.total_discounts).to eq 21.10
      expect(inv.total_charges).to eq 25.10
      expect(inv.exchange_rate).to eq 0.5
      expect(inv.net_invoice_total).to eq 61.1
      expect(inv.net_weight).to eq 2.1
      expect(inv.net_weight_uom).to eq "net wt uom 1"
      expect(inv.country_origin).to eq china
      expect(inv.terms_of_payment).to eq "pay terms 1"
      expect(inv.terms_of_sale).to eq "sale terms 1"
      expect(inv.ship_mode).to eq "ship mode 1"
      expect(inv.gross_weight).to eq 7.1
      expect(inv.gross_weight_uom).to eq "total gross wt uom 1"
      expect(inv.volume).to eq 5.1
      expect(line.department).to eq "dept 1"
      expect(line.country_export).to eq pakistan
      expect(line.first_sale).to eq false
      expect(line.fish_wildlife).to eq true
      expect(line.gross_weight).to eq 7
      expect(line.gross_weight_uom).to eq "gross wt uom 1"
      expect(line.hts_number).to eq "1111"
      expect(line.line_number).to eq 1
      expect(line.mid).to eq "MID 1"
      expect(line.net_weight).to eq 8.1
      expect(line.country_origin).to eq indonesia
      expect(line.pieces).to eq 101
      expect(line.quantity).to eq 3
      expect(line.quantity_uom).to eq "qty uom 1"
      expect(line.unit_price).to eq 10.1
      expect(line.value_domestic).to eq 20.1
      expect(line.value_foreign).to eq 25.1
      expect(line.volume).to eq 15.1
      expect(line.volume_uom).to eq "vol uom 1"
      snap = inv.entity_snapshots.first
      expect(snap.user).to eq User.integration
      expect(snap.context).to eq "Custom Invoice Uploader: file.xlsx"
    end

    it "sends email notification about non-updateable invoices" do
      expect(cf).to receive(:attached_file_name).and_return "filename"
      inv = Invoice.create!(importer_id: imp.id, invoice_number: "inv num 2", manually_generated: false)
      InvoiceLine.create!(invoice: inv)
      parser.process user, {'cust_num' => 'ACME'}
      expect(Invoice.count).to eq 2
      inv.reload
      expect(inv.invoice_number).to eq "inv num 2"
      expect(inv.currency).to be_nil
      expect(inv.invoice_lines.count).to eq 1
      line = inv.invoice_lines.first
      expect(line.po_number).to be_nil
      
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.subject).to eq "Custom invoice upload incomplete"
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
      expect(mail.body).to match /file.xlsx.+inv num 2/
    end

    it "updates flagged invoices" do
      expect(cf).to receive(:attached_file_name).and_return "filename"
      inv = Invoice.create!(importer_id: imp.id, invoice_number: "inv num 2", manually_generated: true)
      InvoiceLine.create!(invoice: inv)
      parser.process user, {'cust_num' => 'ACME'}
      expect(Invoice.count).to eq 2
      inv.reload
      expect(inv.invoice_number).to eq "inv num 2"
      expect(inv.vendor.name).to eq "Vendor 2"
      expect(inv.currency).to eq "GBP"
      expect(inv.invoice_lines.count).to eq 1
      line = inv.invoice_lines.first
      expect(line.po_number).to eq "PO num 3"

      expect(ActionMailer::Base.deliveries.pop).to be_nil
    end
  end


end
