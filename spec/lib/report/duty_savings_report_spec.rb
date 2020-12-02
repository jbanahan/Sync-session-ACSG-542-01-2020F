describe OpenChain::Report::DutySavingsReport do
  let(:report) { described_class.new }
  let(:arrival_date) { DateTime.new(2016, 01, 15) }
  let(:release_date) { DateTime.new(2016, 01, 16) }

  describe "permission?" do
    let(:co) { create(:company, master: true) }
    let(:u) { create(:user, company: co, entry_view: true)}

    it "allows user at master company who can view entries" do
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission?(u)).to eq true
    end

    it "blocks user not at master company" do
      expect(u).to receive(:view_entries?).and_return true
      u.company.update_attributes(master: false)
      expect(described_class.permission?(u)).to eq false
    end

    it "blocks user who can't view entries" do
      expect(u).to receive(:view_entries?).and_return false
      u.update_attributes(entry_view: false)
      expect(described_class.permission?(u)).to eq false
    end
  end

  describe "run_report" do
    let(:u) { create(:user, time_zone: "Eastern Time (US & Canada)") }
    after { @temp.close if @temp }

    it "generates spreadsheet" do
      create_data arrival_date, release_date

      @temp = described_class.run_report(u, {'start_date' => '2016-01-01', 'end_date' => '2016-02-01', 'customer_numbers' => ["cust num"]})
      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]

      expect(sheet.name).to eq "Duty Savings Report"
      expect(sheet.rows.count).to eq 2
      expect(sheet.row(0)).to eq ['Broker Ref#', 'Arrival Date', 'Release Date', 'Customer Number', 'Vendor Name', 'PO Number', 'Invoice Line Value',
                                  'Entered Value', 'Cost Savings', 'Duty Savings']
    end

    it "adjusts start/end dates to user's timezone" do
      adjusted_start = "2016-01-01 05:00:00"
      adjusted_end = "2016-02-01 05:00:00"
      expect_any_instance_of(described_class).to receive(:create_workbook).with(adjusted_start, adjusted_end, nil)
      expect_any_instance_of(described_class).to receive(:workbook_to_tempfile)
      described_class.run_report(u, {'start_date' => '2016-01-01', 'end_date' => '2016-02-01'})
    end
  end

  describe "run_schedulable" do
    it "sends email with attachment" do
      create_data arrival_date, release_date
      now = release_date.in_time_zone("Eastern Time (US & Canada)").to_datetime.beginning_of_day + 2.days

      Timecop.freeze(now) do
        described_class.run_schedulable({'email' => ['test@vandegriftinc.com'], 'previous_n_days' => 3, 'customer_numbers' => ["cust num"]})
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq [ "test@vandegriftinc.com" ]
      expect(mail.subject).to eq "Duty Savings Report: 01-14-2016 through 01-16-2016"
      expect(mail.attachments.count).to eq 1

      Tempfile.open('attachment') do |t|
        t.binmode
        t << mail.attachments.first.read
        t.flush
        wb = Spreadsheet.open t.path
        sheet = wb.worksheet(0)

        expect(sheet.count).to eq 2
        expect(sheet.row(0)).to eq ['Broker Ref#', 'Arrival Date', 'Release Date', 'Customer Number', 'Vendor Name', 'PO Number', 'Invoice Line Value',
                                    'Entered Value', 'Cost Savings', 'Duty Savings']
      end
    end

    it "calculates previous n months" do
      today = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now.beginning_of_day
      two_months_ago = today.beginning_of_month - 2.months
      this_month = today.beginning_of_month
      expect_any_instance_of(described_class).to receive(:create_workbook).with(two_months_ago, this_month, nil)
      allow_any_instance_of(described_class).to receive(:workbook_to_tempfile)
      described_class.run_schedulable({'previous_n_months' => 2})
    end

    it "calculates previous n days" do
      today = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now.beginning_of_day
      two_days_ago = today - 2.days
      expect_any_instance_of(described_class).to receive(:create_workbook).with(two_days_ago, today, nil)
      allow_any_instance_of(described_class).to receive(:workbook_to_tempfile)
      described_class.run_schedulable({'previous_n_days' => 2})
    end
  end

  describe "query" do
    before { create_data arrival_date, release_date }

    it "generates expected results" do
      r = ActiveRecord::Base.connection.execute report.query('2016-01-01', '2016-02-01', ["cust num"])
      expect(r.count).to eq 1
      expect(r.first[0..9]).to eq ["brok ref", arrival_date, release_date, "cust num", "ACME", "PO num", 25, 15, 10, 2] # for some reason datetime doesn't evaluate properly without range
    end

    it "assigns 0 to 'duty savings' if calculation < 1" do
      @cil.update_attributes(value: 16)
      r = ActiveRecord::Base.connection.execute report.query('2016-01-01', '2016-02-01', ["cust num"])
      expect(r.count).to eq 1
      expect(r.first[9]).to eq 0
    end

    it "doesn't produce null values for 'duty savings'" do
      @cit1.update_attributes(entered_value: 0)
      @cit2.update_attributes(entered_value: 0)
      r = ActiveRecord::Base.connection.execute report.query('2016-01-01', '2016-02-01', ["cust num"])
      expect(r.count).to eq 1
      expect(r.first[9]).to eq 0
    end

    it "omits entries without specified customer number" do
      @ent.update_attributes(customer_number: "foo")
      r = ActiveRecord::Base.connection.execute report.query('2016-01-01', '2016-02-01', ["cust num"])
      expect(r.count).to eq 0
    end

    it "omits entries without release_date in specified range" do
      r = ActiveRecord::Base.connection.execute report.query('2016-05-01', '2016-06-01', ["cust num"])
      expect(r.count).to eq 0
    end

    it "omits invoice lines with a contract amount" do
      @cil.update_attributes(contract_amount: 5)
      r = ActiveRecord::Base.connection.execute report.query('2016-01-01', '2016-02-01', ["cust num"])
      expect(r.count).to eq 0
    end

    it "generates results with null contract amount" do
      @cil.update_attributes(contract_amount: nil)
      r = ActiveRecord::Base.connection.execute report.query('2016-01-01', '2016-02-01', ["cust num"])
      expect(r.count).to eq 1
    end
  end

  def create_data arrival_date, release_date
    @ent = create(:entry, broker_reference: "brok ref", arrival_date: arrival_date, release_date: release_date, customer_number: "cust num")
    @ci = create(:commercial_invoice, entry: @ent)
    @cil = create(:commercial_invoice_line, commercial_invoice: @ci, vendor_name: "ACME", po_number: "PO num", value: 25, contract_amount: 0)
    @cit1 = create(:commercial_invoice_tariff, commercial_invoice_line: @cil, entered_value: 8, duty_amount: 2)
    @cit2 = create(:commercial_invoice_tariff, commercial_invoice_line: @cil, entered_value: 7, duty_amount: 1)
  end

end
