require 'spec_helper'

describe OpenChain::CustomHandler::JCrew::JCrewDrawbackImportsReport do

  describe "run" do
    let (:entry) {
      e = Factory(:entry, broker_reference: "REF", entry_number: "EN", master_bills_of_lading: "A\n B", house_bills_of_lading: "A\n B", customer_number: "J0000", arrival_date: Time.zone.parse("2016-04-01 04:00"), release_date: Time.zone.now)
      inv = Factory(:commercial_invoice, entry: e)
      inv_line = Factory(:commercial_invoice_line, commercial_invoice: inv, po_number: "PO", part_number: "PART", country_origin_code: "CN", quantity: 20)
      e
    }

    let (:user) {
      Factory(:user, time_zone: "America/New_York")
    }

    after :each do
      @temp.close! if @temp && !@temp.closed?
    end

    it "runs report returning multiple rows for each masterbill found in the entries masterbills field" do
      entry
      @temp = subject.run user, start_date: "2016-04-01", end_date: "2016-04-02"
      expect(@temp).not_to be_nil

      wb = Spreadsheet.open @temp.path

      sheet = wb.worksheet("Drawback Imports 04.01.2016 - 04.02.2016")
      expect(sheet).not_to be_nil
      expect(sheet.rows.length).to eq 3
      expect(sheet.row(0)).to eq ["Broker Reference", "Entry Number", "Master Bill", "Customer Number", "Arrival Date", "Invoice Line - PO Number", "Invoice Line - Part Number", "Invoice Line - Country Origin Code", "Invoice Line - Units"]
      expect(sheet.row(1)).to eq ["REF", "EN", "A", "J0000", excel_date(Date.new(2016, 4, 1)), "PO", "PART", "CN", 20]
      expect(sheet.row(2)).to eq ["REF", "EN", "B", "J0000", excel_date(Date.new(2016, 4, 1)), "PO", "PART", "CN", 20]
    end

    it "finds results for JCREW entries" do
      entry.update_attributes customer_number: "JCREW"
      @temp = subject.run user, start_date: "2016-04-01", end_date: "2016-04-02"
      expect(@temp).not_to be_nil

      wb = Spreadsheet.open @temp.path

      sheet = wb.worksheet("Drawback Imports 04.01.2016 - 04.02.2016")
      expect(sheet).not_to be_nil
      expect(sheet.rows.length).to eq 3
    end

    it "uses dates relative to user's timezone" do
      # This'll make the entry drop off the report since the time is 03:00 UTC, but in the user's timezone that's prior to midnight on 4/1
      entry.update_attributes arrival_date: "2016-04-01 03:00"
      @temp = subject.run user, start_date: "2016-04-01", end_date: "2016-04-02"
      expect(@temp).not_to be_nil

      wb = Spreadsheet.open @temp.path

      sheet = wb.worksheet("Drawback Imports 04.01.2016 - 04.02.2016")
      expect(sheet).not_to be_nil
      expect(sheet.rows.length).to eq 1
    end
  end

  describe "permission?" do
    let (:jcrew) { Factory(:company, alliance_customer_number: "JCREW")}
    let (:user) { Factory(:user, company: jcrew) }

    it "allows users with entry view and can view company to see reporting" do
      expect(user).to receive(:view_entries?).and_return true

      expect(described_class.permission? user).to be_truthy
    end

    it "prevents users without view entry permissions" do 
      expect(user).to receive(:view_entries?).and_return false
      expect(described_class.permission? user).to be_falsey
    end

    it "prevents users who can't see crew company" do
      allow(user).to receive(:view_entries?).and_return true
      expect(described_class.permission? Factory(:user)).to be_falsey
    end
  end
end