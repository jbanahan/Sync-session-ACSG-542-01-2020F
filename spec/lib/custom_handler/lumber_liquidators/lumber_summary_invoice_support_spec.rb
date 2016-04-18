require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSummaryInvoiceSupport do

  subject { Class.new { include OpenChain::CustomHandler::LumberLiquidators::LumberSummaryInvoiceSupport }.new }
  let (:sheet) { wb, sheet = XlsMaker.create_workbook_and_sheet "Sheet", []; sheet }
  let (:entry) { Factory(:entry) }
  let (:broker_invoice) { Factory(:broker_invoice, invoice_total: BigDecimal("100"), invoice_date: Date.new(2016, 4, 1), entry: entry) }
  let (:broker_invoice_2) { Factory(:broker_invoice, invoice_total: BigDecimal("10"), invoice_date: Date.new(2016, 3, 1), entry: entry) }
  before :each do
    ms = double("MasterSetup")
    ms.stub(:request_host).and_return "http://localhost"
    MasterSetup.stub(:get).and_return ms
  end

  describe "generate_summary" do
    
    it "creates a summary page with data from each invoice" do
      now = Time.zone.now.to_date
      subject.generate_summary sheet, [broker_invoice, broker_invoice_2], now

      expect(sheet.row(0)).to eq ["Vandegrift Forwarding Co., Inc"]
      expect(sheet.row(1)).to eq ["Statement of Account as of", now]
      expect(sheet.row(2)).to eq ["Company", "Lumber Liquidators"]
      expect(sheet.row(3)).to eq []
      expect(sheet.row(4)).to eq ["Invoice", "Invoice Date", "Invoice Amount"]
      expect(sheet.row(5)).to eq [Spreadsheet::Link.new(broker_invoice.entry.excel_url, broker_invoice.invoice_number.to_s), broker_invoice.invoice_date, broker_invoice.invoice_total.to_f]
      expect(sheet.row(6)).to eq [Spreadsheet::Link.new(broker_invoice_2.entry.excel_url, broker_invoice_2.invoice_number.to_s), broker_invoice_2.invoice_date, broker_invoice_2.invoice_total.to_f]
      expect(sheet.row(7)).to eq []
      expect(sheet.row(8)).to eq ["", "Total:", 110.0]
    end

    it "skips summary date line if no date is given" do
      subject.generate_summary sheet, [broker_invoice], nil

      expect(sheet.row(0)).to eq ["Vandegrift Forwarding Co., Inc"]
      expect(sheet.row(1)).to eq ["Company", "Lumber Liquidators"]
      expect(sheet.row(2)).to eq []
      expect(sheet.row(3)).to eq ["Invoice", "Invoice Date", "Invoice Amount"]
      expect(sheet.row(4)).to eq [Spreadsheet::Link.new(broker_invoice.entry.excel_url, broker_invoice.invoice_number.to_s), broker_invoice.invoice_date, broker_invoice.invoice_total.to_f]
      expect(sheet.row(5)).to eq []
      expect(sheet.row(6)).to eq ["", "Total:", 100.0]
    end
  end

  describe "generate_supplemental_summary_page" do
    it "generates a supplemental summary" do
      subject.generate_supplemental_summary_page sheet, broker_invoice

      expect(sheet.row(0)).to eq ["Vandegrift Forwarding Co., Inc"]
      expect(sheet.row(1)).to eq ["Company", "Lumber Liquidators"]
      expect(sheet.row(2)).to eq []
      expect(sheet.row(3)).to eq ["Invoice", "Invoice Date", "Invoice Amount"]
      expect(sheet.row(4)).to eq [Spreadsheet::Link.new(broker_invoice.entry.excel_url, broker_invoice.invoice_number.to_s), broker_invoice.invoice_date, broker_invoice.invoice_total.to_f]
      expect(sheet.row(5)).to eq []
      expect(sheet.row(6)).to eq ["", "Total:", 100.0]
    end
  end

  describe "generate_summary_invoice_page" do
    it "generates a summary page" do
      now = Time.zone.now.to_date
      subject.generate_summary_invoice_page sheet, [broker_invoice, broker_invoice_2], now

      expect(sheet.row(0)).to eq ["Vandegrift Forwarding Co., Inc"]
      expect(sheet.row(1)).to eq ["Statement of Account as of", now]
      expect(sheet.row(2)).to eq ["Company", "Lumber Liquidators"]
      expect(sheet.row(3)).to eq []
      expect(sheet.row(4)).to eq ["Invoice", "Invoice Date", "Invoice Amount"]
      expect(sheet.row(5)).to eq [Spreadsheet::Link.new(broker_invoice.entry.excel_url, broker_invoice.invoice_number.to_s), broker_invoice.invoice_date, broker_invoice.invoice_total.to_f]
      expect(sheet.row(6)).to eq [Spreadsheet::Link.new(broker_invoice_2.entry.excel_url, broker_invoice_2.invoice_number.to_s), broker_invoice_2.invoice_date, broker_invoice_2.invoice_total.to_f]
      expect(sheet.row(7)).to eq []
      expect(sheet.row(8)).to eq ["", "Total:", 110.0]
    end
  end
end