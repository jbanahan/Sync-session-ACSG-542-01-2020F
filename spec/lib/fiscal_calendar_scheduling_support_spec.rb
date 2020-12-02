describe OpenChain::FiscalCalendarSchedulingSupport do

  subject {
    Class.new {
      include OpenChain::FiscalCalendarSchedulingSupport
    }.new
  }

  let (:importer) { create(:importer, system_code: "IMP") }
  let! (:fiscal_month) { FiscalMonth.create! company_id: importer.id, year: 2017, month_number: 3, start_date: Date.new(2017, 3, 6), end_date: Date.new(2017, 4, 2) }

  describe "run_if_fiscal_day" do

    it "yields if the given date is on the Xth date of the importers fiscal calendar" do
      expect {|b| subject.run_if_fiscal_day(importer, 6, current_time: Date.new(2017, 3, 11), &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 11))
    end

    it "does not yield if the given date is not on the xth day of the fiscal month" do
      expect { |b| subject.run_if_fiscal_day(importer, 7, current_time: Date.new(2017, 3, 11), &b) }.not_to yield_control
    end

    it "yields based off the relation to the fiscal calendars end date" do
      expect {|b| subject.run_if_fiscal_day(importer, 3, current_time: Date.new(2017, 3, 31), relative_to_start: false, &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 31))
    end

    it "handles times with zones" do
      # Use a time that when translated to the default timezone (Eastern) that results in it being the 5th day fo the fiscal calendar
      time = ActiveSupport::TimeZone["UTC"].parse "2017-03-12 00:00"

      expect {|b| subject.run_if_fiscal_day(importer, 6, current_time: time, &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 11))
    end

    it "allows using an alternate timezone" do
      # Use a time that when translated to the default timezone (Eastern) that results in it being the 5th day fo the fiscal calendar
      time = ActiveSupport::TimeZone["UTC"].parse "2017-03-12 00:00"

      # Because we're doing the calculation based on UTC, 3-12 is not the 5th day of the fiscal month.
      expect { |b| subject.run_if_fiscal_day(importer, 6, current_time: time, relative_to_timezone: "UTC", &b) }.not_to yield_control
    end

    it "utilizes the current_time if not given" do
      # By default, the code will translate the frozen current_time to Eastern, so it'll be 3/11 and thus yielded
      Timecop.freeze(ActiveSupport::TimeZone["UTC"].parse "2017-03-12 00:00") do
        expect {|b| subject.run_if_fiscal_day(importer, 6, current_time: Date.new(2017, 3, 11), &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 11))
      end
    end

    it "allows passing importer id" do
      expect {|b| subject.run_if_fiscal_day(importer.id, 6, current_time: Date.new(2017, 3, 11), &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 11))
    end

    it "allows passing importer system code" do
      expect {|b| subject.run_if_fiscal_day(importer.system_code, 6, current_time: Date.new(2017, 3, 11), &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 11))
    end

    it "yields if the given date is on the Xth date of a fiscal quarter" do
      month_number = [1, 4, 7, 10].sample
      fiscal_quarter_first_month = FiscalMonth.create! company_id: importer.id, year: 2017, month_number: month_number, start_date: Date.new(2017, 9, 6), end_date: Date.new(2017, 10, 2)

      expect {|b| subject.run_if_fiscal_day(importer, 8, current_time: Date.new(2017, 9, 13), scheduling_type: described_class::QUARTERLY_SCHEDULING, &b)}.to yield_with_args(fiscal_quarter_first_month, Date.new(2017, 9, 13))
    end

    it "does not yield if the given date is not on the Xth date of a fiscal quarter" do
      fiscal_quarter_first_month = FiscalMonth.create! company_id: importer.id, year: 2017, month_number: 7, start_date: Date.new(2017, 9, 6), end_date: Date.new(2017, 10, 2)

      expect { |b| subject.run_if_fiscal_day(importer, 7, current_time: Date.new(2017, 9, 13), scheduling_type: described_class::QUARTERLY_SCHEDULING, &b) }.not_to yield_control
    end

    it "yields if the given date is on the Xth date of a fiscal quarter involving month-spanning" do
      fiscal_quarter_first_month = FiscalMonth.create! company_id: importer.id, year: 2017, month_number: 7, start_date: Date.new(2017, 7, 5), end_date: Date.new(2017, 8, 2)
      fiscal_quarter_second_month = FiscalMonth.create! company_id: importer.id, year: 2017, month_number: 8, start_date: Date.new(2017, 8, 3), end_date: Date.new(2017, 9, 5)
      fiscal_quarter_third_month = FiscalMonth.create! company_id: importer.id, year: 2017, month_number: 9, start_date: Date.new(2017, 9, 6), end_date: Date.new(2017, 10, 2)

      # Current date falls within the third month, but the first month should be returned, and we should get this
      # result because the date happens to be the 70th date of the quarter.
      expect {|b| subject.run_if_fiscal_day(importer, 71, current_time: Date.new(2017, 9, 13), scheduling_type: described_class::QUARTERLY_SCHEDULING, &b)}.to yield_with_args(fiscal_quarter_first_month, Date.new(2017, 9, 13))
    end

    it "yields if the given date is on the Xth date of a fiscal quarter involving month-and-year-spanning" do
      fiscal_quarter_first_month = FiscalMonth.create! company_id: importer.id, year: 2018, month_number: 1, start_date: Date.new(2017, 12, 15), end_date: Date.new(2018, 1, 14)
      fiscal_quarter_second_month = FiscalMonth.create! company_id: importer.id, year: 2018, month_number: 2, start_date: Date.new(2018, 1, 15), end_date: Date.new(2018, 2, 14)

      expect {|b| subject.run_if_fiscal_day(importer, 38, current_time: Date.new(2018, 1, 21), scheduling_type: described_class::QUARTERLY_SCHEDULING, &b)}.to yield_with_args(fiscal_quarter_first_month, Date.new(2018, 1, 21))
    end

    it "handles case where first month of quarter is missing" do
      fiscal_quarter_second_month = FiscalMonth.create! company_id: importer.id, year: 2018, month_number: 2, start_date: Date.new(2018, 1, 15), end_date: Date.new(2018, 2, 14)

      expect { |b| subject.run_if_fiscal_day(importer, 38, current_time: Date.new(2018, 1, 21), scheduling_type: described_class::QUARTERLY_SCHEDULING, &b) }.not_to yield_control
    end

    it "yields if the given date is on the Xth date of a fiscal half year" do
      month_number = [1, 7].sample
      fiscal_half_first_month = FiscalMonth.create! company_id: importer.id, year: 2017, month_number: month_number, start_date: Date.new(2017, 9, 6), end_date: Date.new(2017, 10, 2)

      expect {|b| subject.run_if_fiscal_day(importer, 8, current_time: Date.new(2017, 9, 13), scheduling_type: described_class::BIANNUAL_SCHEDULING, &b)}.to yield_with_args(fiscal_half_first_month, Date.new(2017, 9, 13))
    end

    it "does not yield if the given date is not on the Xth date of a fiscal half year" do
      FiscalMonth.create! company_id: importer.id, year: 2017, month_number: 7, start_date: Date.new(2017, 9, 6), end_date: Date.new(2017, 10, 2)

      expect { |b| subject.run_if_fiscal_day(importer, 7, current_time: Date.new(2017, 9, 13), scheduling_type: described_class::BIANNUAL_SCHEDULING, &b) }.not_to yield_control
    end

    it "yields if the given date is on the Xth date of a fiscal half year involving month-spanning" do
      fiscal_half_first_month = FiscalMonth.create! company_id: importer.id, year: 2017, month_number: 7, start_date: Date.new(2017, 7, 5), end_date: Date.new(2017, 8, 2)
      FiscalMonth.create! company_id: importer.id, year: 2017, month_number: 8, start_date: Date.new(2017, 8, 3), end_date: Date.new(2017, 9, 5)
      FiscalMonth.create! company_id: importer.id, year: 2017, month_number: 9, start_date: Date.new(2017, 9, 6), end_date: Date.new(2017, 10, 2)

      # Current date falls within the third month, but the first month should be returned, and we should get this
      # result because the date happens to be the 70th date of the half.
      expect {|b| subject.run_if_fiscal_day(importer, 71, current_time: Date.new(2017, 9, 13), scheduling_type: described_class::BIANNUAL_SCHEDULING, &b)}.to yield_with_args(fiscal_half_first_month, Date.new(2017, 9, 13))
    end

    it "yields if the given date is on the Xth date of a fiscal half year involving month-and-year-spanning" do
      fiscal_half_first_month = FiscalMonth.create! company_id: importer.id, year: 2018, month_number: 1, start_date: Date.new(2017, 12, 15), end_date: Date.new(2018, 1, 14)
      FiscalMonth.create! company_id: importer.id, year: 2018, month_number: 2, start_date: Date.new(2018, 1, 15), end_date: Date.new(2018, 2, 14)

      expect {|b| subject.run_if_fiscal_day(importer, 38, current_time: Date.new(2018, 1, 21), scheduling_type: described_class::BIANNUAL_SCHEDULING, &b)}.to yield_with_args(fiscal_half_first_month, Date.new(2018, 1, 21))
    end

    it "handles case where first month of half year is missing" do
      FiscalMonth.create! company_id: importer.id, year: 2018, month_number: 2, start_date: Date.new(2018, 1, 15), end_date: Date.new(2018, 2, 14)

      expect { |b| subject.run_if_fiscal_day(importer, 38, current_time: Date.new(2018, 1, 21), scheduling_type: described_class::BIANNUAL_SCHEDULING, &b) }.not_to yield_control
    end
  end

  describe "run_if_configured" do
    let (:config) {
      {"company" => "ASCE"}
    }

    let (:fiscal_month) { FiscalMonth.new }
    let (:fiscal_date) { Date.new 2017, 3, 1 }

    it "uses configuration with default values" do
      expect(subject).to receive(:run_if_fiscal_day).with("ASCE", 1, relative_to_timezone: "America/New_York", relative_to_start: true, scheduling_type: described_class::MONTHLY_SCHEDULING).and_yield fiscal_month, fiscal_date

      expect {|b| subject.run_if_configured(config, &b) }.to yield_with_args fiscal_month, fiscal_date
    end

    it "passes alternate timezone, relative to start and quarterly scheduling type values" do
      config["relative_to_start"] = "false"
      config["relative_to_timezone"] = "UTC"
      config["quarterly"] = true

      expect(subject).to receive(:run_if_fiscal_day).with("ASCE", 1, relative_to_timezone: "UTC", relative_to_start: false, scheduling_type: described_class::QUARTERLY_SCHEDULING)
      expect {|b| subject.run_if_configured(config, &b)}.not_to yield_control
    end

    it "passes alternate biannual scheduling type values" do
      config["biannually"] = true

      expect(subject).to receive(:run_if_fiscal_day).with("ASCE", 1, relative_to_timezone: "America/New_York", relative_to_start: true, scheduling_type: described_class::BIANNUAL_SCHEDULING)
      expect {|b| subject.run_if_configured(config, &b)}.not_to yield_control
    end
  end

  describe "get_fiscal_quarter_start_end_dates" do
    let(:company) { create(:company) }

    it "gets quarter start end dates" do
      fm_1 = FiscalMonth.create!(year:2025, month_number:1, start_date:Date.new(2025, 4, 5), end_date:Date.new(2025, 5, 4), company_id:company.id)
      fm_2 = FiscalMonth.create!(year:2025, month_number:2, start_date:Date.new(2025, 5, 5), end_date:Date.new(2025, 6, 4), company_id:company.id)
      fm_3 = FiscalMonth.create!(year:2025, month_number:3, start_date:Date.new(2025, 6, 5), end_date:Date.new(2026, 7, 4), company_id:company.id)

      expect(described_class.get_fiscal_quarter_start_end_dates fm_1).to eq [fm_1.start_date, fm_3.end_date]
      expect(described_class.get_fiscal_quarter_start_end_dates fm_2).to eq [fm_1.start_date, fm_3.end_date]
      expect(described_class.get_fiscal_quarter_start_end_dates fm_3).to eq [fm_1.start_date, fm_3.end_date]
    end

    it "handles incomplete fiscal calendar" do
      fm_2 = FiscalMonth.create!(year:2025, month_number:2, start_date:Date.new(2025, 5, 5), end_date:Date.new(2025, 6, 4), company_id:company.id)

      expect(described_class.get_fiscal_quarter_start_end_dates fm_2).to eq [nil, nil]
    end
  end

  describe "get_fiscal_half_start_end_dates" do
    let(:company) { create(:company) }

    it "gets quarter start end dates" do
      fm_1 = FiscalMonth.create!(year: 2025, month_number: 1, start_date: Date.new(2025, 4, 5), end_date: Date.new(2025, 5, 4), company_id: company.id)
      fm_2 = FiscalMonth.create!(year: 2025, month_number: 2, start_date: Date.new(2025, 5, 5), end_date: Date.new(2025, 6, 4), company_id: company.id)
      fm_3 = FiscalMonth.create!(year: 2025, month_number: 3, start_date: Date.new(2025, 6, 5), end_date: Date.new(2026, 7, 4), company_id: company.id)
      fm_4 = FiscalMonth.create!(year: 2025, month_number: 4, start_date: Date.new(2025, 7, 5), end_date: Date.new(2026, 8, 4), company_id: company.id)
      fm_5 = FiscalMonth.create!(year: 2025, month_number: 5, start_date: Date.new(2025, 8, 5), end_date: Date.new(2026, 9, 4), company_id: company.id)
      fm_6 = FiscalMonth.create!(year: 2025, month_number: 6, start_date: Date.new(2025, 9, 5), end_date: Date.new(2026, 10, 4), company_id: company.id)

      expect(described_class.get_fiscal_half_start_end_dates fm_1).to eq [fm_1.start_date, fm_6.end_date]
      expect(described_class.get_fiscal_half_start_end_dates fm_2).to eq [fm_1.start_date, fm_6.end_date]
      expect(described_class.get_fiscal_half_start_end_dates fm_3).to eq [fm_1.start_date, fm_6.end_date]
      expect(described_class.get_fiscal_half_start_end_dates fm_4).to eq [fm_1.start_date, fm_6.end_date]
      expect(described_class.get_fiscal_half_start_end_dates fm_5).to eq [fm_1.start_date, fm_6.end_date]
      expect(described_class.get_fiscal_half_start_end_dates fm_6).to eq [fm_1.start_date, fm_6.end_date]
    end

    it "handles incomplete fiscal calendar" do
      fm_2 = FiscalMonth.create!(year:2025, month_number:2, start_date:Date.new(2025, 5, 5), end_date:Date.new(2025, 6, 4), company_id:company.id)

      expect(described_class.get_fiscal_half_start_end_dates fm_2).to eq [nil, nil]
    end
  end

  describe "scheduling_type" do
    it "determines type to be biannually when matching property has true value" do
      expect(subject.scheduling_type({ "biannually" => "true", "quarterly" => "true" })).to eq described_class::BIANNUAL_SCHEDULING
      expect(subject.scheduling_type({ "biannually" => "1" })).to eq described_class::BIANNUAL_SCHEDULING
      expect(subject.scheduling_type({ "biannually" => "false" })).to eq described_class::MONTHLY_SCHEDULING
      expect(subject.scheduling_type({ "biannually" => "something else" })).to eq described_class::MONTHLY_SCHEDULING
    end

    it "determines type to be quarterly when matching property has true value" do
      expect(subject.scheduling_type({ "quarterly" => "true" })).to eq described_class::QUARTERLY_SCHEDULING
      expect(subject.scheduling_type({ "quarterly" => "1" })).to eq described_class::QUARTERLY_SCHEDULING
      expect(subject.scheduling_type({ "quarterly" => "false" })).to eq described_class::MONTHLY_SCHEDULING
      expect(subject.scheduling_type({ "quarterly" => "something else" })).to eq described_class::MONTHLY_SCHEDULING
    end

    it "determines type to be monthly when quarterly and biannually properties are not provided" do
      expect(subject.scheduling_type({ })).to eq described_class::MONTHLY_SCHEDULING
    end
  end
end
