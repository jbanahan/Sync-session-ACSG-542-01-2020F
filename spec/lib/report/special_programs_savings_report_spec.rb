describe OpenChain::Report::SpecialProgramsSavingsReport do
  let(:report_headers) { ['Customer Number', 'Broker Reference', 'Entry Number', 'Release Date', 'Country ISO Code',
                    'Invoice-Invoice Number', 'Invoice Line - PO Number', 'Invoice Line - Country Origin Code',
                    'Invoice Line - Part Number', 'Invoice Tariff - HTS Code', 'Invoice Tariff - Description', 'Invoice Tariff - 7501 Entered Value',
                    'Invoice Tariff - Duty Rate', 'Invoice Tariff - Duty', 'SPI (Primary)', 'Common Rate',
                    'Duty without SPI', 'Savings'] }

  describe "permission?" do
    let(:user) { Factory(:user) }
    let(:ms) { stub_master_setup }

    it "allow master users on systems with feature" do
      expect(ms).to receive(:custom_feature?).with('WWW VFI Track Reports').and_return true
      expect(user.company).to receive(:master?).and_return true
      expect(described_class.permission? user).to eq true
    end

    it "blocks non-master users on systems with feature" do
      allow(ms).to receive(:custom_feature?).with('WWW VFI Track Reports').and_return true
      expect(user.company).to receive(:master?).and_return false
      expect(described_class.permission? user).to eq false
    end

    it "blocks master users on systems without feature" do
      expect(ms).to receive(:custom_feature?).with('WWW VFI Track Reports').and_return false
      expect(user.company).to receive(:master?).and_return true
      expect(described_class.permission? user).to eq false
    end
  end

  describe "run_schedulable" do
    it 'takes in a timezone opt and uses that instead of EST' do
      start_date = nil
      end_date = nil

      Time.use_zone("Pacific/Auckland") do
        start_date = 1.month.ago.beginning_of_month.to_s
        end_date = 1.month.ago.end_of_month.to_s
      end

      expected_opts = {
          'companies' => 'SPECIAL',
          'email_to' => 'user@company.com',
          'time_zone' => 'Pacific/Auckland',
          'start_date' => start_date,
          'end_date' => end_date
      }

      expect(OpenChain::Report::SpecialProgramsSavingsReport).to receive(:run_report).with(User.integration, expected_opts)
      OpenChain::Report::SpecialProgramsSavingsReport.run_schedulable({'companies'=>'SPECIAL', 'email_to'=>'user@company.com', 'time_zone'=>'Pacific/Auckland'})
    end

    it 'sends an email' do
      OpenChain::Report::SpecialProgramsSavingsReport.run_schedulable({'companies'=>'SPECIAL', 'email_to'=>'user@company.com', 'time_zone'=>'Pacific/Auckland'})
      expect(ActionMailer::Base.deliveries.size).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["user@company.com"]
      expect(m.subject).to eq "Special Programs Savings Report"
    end

    it 'uses last month as the start and end date with EST as default' do
      mail = double('mail')
      allow(mail).to receive(:deliver_now)
      start_date = nil
      end_date = nil

      Time.use_zone("America/New_York") do
        start_date = 1.month.ago.beginning_of_month.to_s
        end_date = 1.month.ago.end_of_month.to_s
      end
      expected_opts = {
          'companies' => 'SPECIAL',
          'email_to' => 'user@company.com',
          'start_date' => start_date,
          'end_date' => end_date
      }

      expect(OpenChain::Report::SpecialProgramsSavingsReport).to receive(:run_report).with(User.integration, expected_opts)
      expect(OpenMailer).to receive(:send_simple_html).and_return(mail)
      OpenChain::Report::SpecialProgramsSavingsReport.run_schedulable({'companies'=>'SPECIAL', 'email_to'=>'user@company.com'})
    end
  end

  context "run" do
    before do
      @country = Factory(:country, :iso_code=>'US')
      @entry = Factory(:entry, :import_country=>@country, :customer_number=>"SPECIAL", :release_date=>Time.zone.now, :broker_reference=>'99123456',
                       :entry_number => '1231kl0')
      @invoices = []
      @invoice_lines = []
      @invoice_tariffs = []

      ['Invoice 1'].each do |inv_num|
        invoice = Factory(:commercial_invoice, :entry_id=>@entry.id, :invoice_number => inv_num)
        @invoices << invoice
      end

      ['Invoice Line 1'].each_with_index do |inv_line, inv_num|
        invoice_line = Factory(:commercial_invoice_line, :commercial_invoice=>@invoices[inv_num], :po_number=>inv_line,
                               :country_origin_code=>'US', :part_number=>'1234')
        @invoice_lines << invoice_line
      end

      ['Invoice Tariff 1'].each_with_index do |inv_line, inv_num|
        invoice_tariff = Factory(:commercial_invoice_tariff, :commercial_invoice_line=>@invoice_lines[inv_num],
                                 :hts_code=>'123456789', :tariff_description=>'XYZ123', :entered_value=>'134631.67',
                                 :entered_value_7501=>'134634', :duty_rate=>0.18, :duty_amount=>'1514.83', :spi_primary=>"2")
        @invoice_tariffs << invoice_tariff
      end

      @ot = Factory(:official_tariff, :country=>@country, :hts_code=>'123456789', :common_rate_decimal=>0.18)
    end

    it 'should create a worksheet with invoice billing data' do
      tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run 'SPECIAL', 1.year.ago.to_s, 1.day.from_now.to_s
      wb = Spreadsheet.open tmp
      sheet = wb.worksheet 0
      expect(sheet.row(0)).to eq(report_headers)
      duty_without_spi = @ot.common_rate_decimal * @invoice_tariffs[0].entered_value_7501
      savings = duty_without_spi - @invoice_tariffs[0].duty_amount
      expect(sheet.row(1)).to eq([@entry.customer_number, @entry.broker_reference, @entry.entry_number, excel_date(@entry.release_date.to_date), @country.iso_code,
                                  @invoices[0].invoice_number, @invoice_lines[0].po_number, @invoice_lines[0].country_origin_code,
                                  @invoice_lines[0].part_number, @invoice_tariffs[0].hts_code, @invoice_tariffs[0].tariff_description,
                                  @invoice_tariffs[0].entered_value_7501.to_i, @invoice_tariffs[0].duty_rate.to_f, @invoice_tariffs[0].duty_amount.to_f,
                                  @invoice_tariffs[0].spi_primary, @ot.common_rate_decimal.to_f, duty_without_spi.to_f, savings.to_f])
    end

    it 'should work around null value for entered_value_7501' do
      @invoice_tariffs[0].entered_value_7501 = nil
      @invoice_tariffs[0].save!

      tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run 'SPECIAL', 1.year.ago.to_s, 1.day.from_now.to_s
      wb = Spreadsheet.open tmp
      sheet = wb.worksheet 0
      expect(sheet.row(0)).to eq(report_headers)
      duty_without_spi = @ot.common_rate_decimal * @invoice_tariffs[0].entered_value
      savings = duty_without_spi - @invoice_tariffs[0].duty_amount
      expect(sheet.row(1)).to eq([@entry.customer_number, @entry.broker_reference, @entry.entry_number, excel_date(@entry.release_date.to_date), @country.iso_code,
                                  @invoices[0].invoice_number, @invoice_lines[0].po_number, @invoice_lines[0].country_origin_code,
                                  @invoice_lines[0].part_number, @invoice_tariffs[0].hts_code, @invoice_tariffs[0].tariff_description,
                                  @invoice_tariffs[0].entered_value.to_f, @invoice_tariffs[0].duty_rate.to_f, @invoice_tariffs[0].duty_amount.to_f,
                                  @invoice_tariffs[0].spi_primary, @ot.common_rate_decimal.to_f, duty_without_spi.round(2).to_f, savings.round(2).to_f])
    end

    it 'should work around null values for all tariff-level numeric fields' do
      @invoice_tariffs[0].entered_value_7501 = nil
      @invoice_tariffs[0].entered_value = nil
      @invoice_tariffs[0].duty_amount = nil
      @invoice_tariffs[0].duty_rate = nil
      @invoice_tariffs[0].save!

      tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run 'SPECIAL', 1.year.ago.to_s, 1.day.from_now.to_s
      wb = Spreadsheet.open tmp
      sheet = wb.worksheet 0
      expect(sheet.row(0)).to eq(report_headers)
      expect(sheet.row(1)).to eq([@entry.customer_number, @entry.broker_reference, @entry.entry_number, excel_date(@entry.release_date.to_date), @country.iso_code,
                                  @invoices[0].invoice_number, @invoice_lines[0].po_number, @invoice_lines[0].country_origin_code,
                                  @invoice_lines[0].part_number, @invoice_tariffs[0].hts_code, @invoice_tariffs[0].tariff_description,
                                  nil, nil, nil, @invoice_tariffs[0].spi_primary, @ot.common_rate_decimal.to_f, nil, 0])
    end

    it 'should include the notification' do
     msg = 'Common Rate and Duty without SPI is estimated based on the country’s current tariff schedule and may not reflect the historical Common Rate from the date the entry was cleared. For Common Rates with a compound calculation (such as 4% plus $0.05 per KG), only the percentage is used for the estimated Duty without SPI and Savings calculations.'
     tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run 'SPECIAL', 1.year.ago.to_s, 1.day.from_now.to_s
     wb = Spreadsheet.open tmp
     sheet = wb.worksheet 0
     expect(sheet.row(sheet.rows.count - 1)).to eql [msg]
    end

    it 'should total the Invoice Tariff - Duty, Duty without SPI, and Savings columns' do
      tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run "SPECIAL", 1.year.ago.to_s, 1.day.from_now.to_s
      wb = Spreadsheet.open tmp
      sheet = wb.worksheet 0
      duty_without_spi = @ot.common_rate_decimal * @invoice_tariffs[0].entered_value_7501
      savings = duty_without_spi - @invoice_tariffs[0].duty_amount
      expect(sheet.row(sheet.rows.count - 3)).to eql ['Grand Totals', nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
                                       @invoice_tariffs[0].duty_amount.to_f, nil, nil, duty_without_spi.to_f, savings.to_f]
    end

    it 'should handle an array as an argument' do
      tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run ["HANNAH", "BRUCE"], 1.year.ago.to_s, 1.day.from_now.to_s

      wb = Spreadsheet.open tmp
      sheet = wb.worksheet 0
      expect(sheet.row(1)).to be_empty

      @entry.update_attribute(:customer_number, 'HANNAH')
      tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run ["HANNAH", "BRUCE"], 1.year.ago.to_s, 1.day.from_now.to_s
      wb = Spreadsheet.open tmp
      sheet = wb.worksheet 0
      expect(sheet.row(1)).to be_present
    end
    it 'should handle different customers' do
      # We would expect this to not return any records
      tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run "HANNAH\nBRUCE", 1.year.ago.to_s, 1.day.from_now.to_s
      wb = Spreadsheet.open tmp
      sheet = wb.worksheet 0
      expect(sheet.row(1)).to be_empty

      # Now, let's update the entry
      @entry.update_attribute(:customer_number, 'HANNAH')
      tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run "HANNAH\nBRUCE", 1.year.ago.to_s, 1.day.from_now.to_s
      wb = Spreadsheet.open tmp
      sheet = wb.worksheet 0
      expect(sheet.row(1)).to be_present
    end

    it 'should handle different user timezones in input and output' do
      # Let's create a new entry, one that has a release_date in the past, so we can check this works.

      # The DB dates are UTC, so make sure we're translating the start date / end date value
      # to the correct UTC equiv
      release_date = Time.new(2013, 4, 1, 5, 0, 0, "+00:00")

      # Let's check to make sure nothing comes back, if the entry is not in the dates given.
      tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run 'SPECIAL', '2013-03-31', '2013-04-01'
      wb = Spreadsheet.open tmp
      sheet = wb.worksheet 0
      expect(sheet.row(1)).to be_empty

      # Update the release date to a time we know will be 1 day in the future in UTC vs. local timezone
      @entry.update_attributes :release_date => release_date
      sheet = nil

      Time.use_zone(ActiveSupport::TimeZone['Hawaii']) do
        tmp = OpenChain::Report::SpecialProgramsSavingsReport.new.run 'SPECIAL', '2013-03-31', '2013-04-01'
        wb = Spreadsheet.open tmp
        sheet = wb.worksheet 0
      end

      expect(sheet.row(1)).to be_present
    end
  end
end