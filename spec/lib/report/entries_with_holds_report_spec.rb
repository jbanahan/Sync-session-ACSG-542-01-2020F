describe OpenChain::Report::EntriesWithHoldsReport do
  describe "permission?" do
    let(:user) { double "user" }
    let!(:ms) { stub_master_setup }

    it "allows users who can view entries and have custom feature enabled" do
      expect(ms).to receive(:custom_feature?).with("Kewill Entries").and_return true
      expect(user).to receive(:view_entries?).and_return true
      expect(described_class.permission? user).to eq true
    end

    it "doesn't allows users who can't view entries" do
      expect(ms).to receive(:custom_feature?).with("Kewill Entries").and_return true
      expect(user).to receive(:view_entries?).and_return false
      expect(described_class.permission? user).to eq false
    end

    it "doesn't allows users with custom feature enabled" do
      expect(ms).to receive(:custom_feature?).with("Kewill Entries").and_return false
      expect(user).to_not receive(:view_entries?)
      expect(described_class.permission? user).to eq false
    end
  end

  describe "run_report" do
    let(:u) { create(:user, time_zone: "Eastern Time (US & Canada)", company: create(:company, master:true)) }
    after { @temp.close if @temp }

    it "generates report" do
      zone = ActiveSupport::TimeZone["America/New_York"]
      entry_1 = create(:entry, customer_number:"ABC", broker_reference:"br_1", entry_number:"en_1", container_numbers:"cn_1", master_bills_of_lading:"mb_1", house_bills_of_lading:"hb_1", customer_references:"cr_1", po_numbers:"po_1", release_date:zone.parse("2019-12-09T00:00:00"), arrival_date:zone.parse("2019-12-02T00:00:00"), on_hold:true)
      entry_2 = create(:entry, customer_number:"DEF", broker_reference:"br_2", entry_number:"en_2", container_numbers:"cn_2", master_bills_of_lading:"mb_2", house_bills_of_lading:"hb_2", customer_references:"cr_2", po_numbers:"po_2", release_date:zone.parse("2019-12-10T00:00:00"), arrival_date:zone.parse("2019-12-03T00:00:00"), on_hold:true)
      entry_too_early = create(:entry, broker_reference:"br_3", entry_number:"en_3", container_numbers:"cn_3", master_bills_of_lading:"mb_3", house_bills_of_lading:"hb_3", customer_references:"cr_3", po_numbers:"po_3", release_date:zone.parse("2019-11-25T00:00:00"), arrival_date:zone.parse("2019-11-15T00:00:00"), on_hold:true)
      entry_too_late = create(:entry, broker_reference:"br_4", entry_number:"en_4", container_numbers:"cn_4", master_bills_of_lading:"mb_4", house_bills_of_lading:"hb_4", customer_references:"cr_4", po_numbers:"po_4", release_date:zone.parse("2020-01-25T00:00:00"), arrival_date:zone.parse("2020-01-15T00:00:00"), on_hold:true)
      entry_wrong_customer = create(:entry, customer_number:"GHI", broker_reference:"br_5", entry_number:"en_5", release_date:zone.parse("2019-12-10T00:00:00"), arrival_date:zone.parse("2019-12-02T00:00:00"), on_hold:true)
      entry_not_on_hold = create(:entry, customer_number:"DEF", broker_reference:"br_6", entry_number:"en_6", release_date:zone.parse("2019-12-10T00:00:00"), arrival_date:zone.parse("2019-12-02T00:00:00"), on_hold:false)
      entry_no_on_hold_status = create(:entry, customer_number:"DEF", broker_reference:"br_7", release_date:zone.parse("2019-12-10T00:00:00"), arrival_date:zone.parse("2019-12-02T00:00:00"), on_hold:nil)

      @temp = described_class.run_report(u, {'start_date' => '2019-12-01', 'end_date' => '2019-12-31', 'customer_numbers' => "ABC\nDEF"})
      wb = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(wb.length).to eq 1

      sheet = wb["Entries With Holds"]
      expect(sheet).to_not be_nil
      expect(sheet.length).to eq 3
      expect(sheet[0]).to eq ['Broker Reference', 'Entry Number', 'Container Numbers', 'Master Bills', 'House Bills', 'Customer References', 'PO Numbers', 'Release Date', 'Arrival Date']
      expect(sheet[1]).to eq ['br_1', 'en_1', 'cn_1', 'mb_1', 'hb_1', 'cr_1', 'po_1', zone.parse("2019-12-09T00:00:00").to_s, zone.parse("2019-12-02T00:00:00").to_s]
      expect(sheet[2]).to eq ['br_2', 'en_2', 'cn_2', 'mb_2', 'hb_2', 'cr_2', 'po_2', Date.new(2019, 12, 10).in_time_zone(u.time_zone).to_s, Date.new(2019, 12, 3).in_time_zone(u.time_zone).to_s]
    end
  end

end