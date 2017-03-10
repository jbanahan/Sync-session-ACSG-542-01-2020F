describe OpenChain::FiscalCalendarSchedulingSupport do 

  subject {
    Class.new {
      include OpenChain::FiscalCalendarSchedulingSupport
    }.new
  }

  let (:importer) { Factory(:importer, system_code: "IMP") }
  let! (:fiscal_month) { FiscalMonth.create! company_id: importer.id, year: 2017, month_number: 3, start_date: Date.new(2017, 3, 6), end_date: Date.new(2017, 4, 2) }

  describe "run_if_fiscal_day" do

    it "yields if the given date is on the Xth date of the importers fiscal calendar" do
      expect {|b| subject.run_if_fiscal_day(importer, 5, current_time: Date.new(2017, 3, 11), &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 11))
    end

    it "does not yield if the given date is not on the xth day of the fiscal month" do
      expect { |b| subject.run_if_fiscal_day(importer, 6, current_time: Date.new(2017, 3, 11), &b) }.not_to yield_control
    end

    it "yields based off the relation to the fiscal calendars end date" do
      expect {|b| subject.run_if_fiscal_day(importer, 2, current_time: Date.new(2017, 3, 31), relative_to_start: false, &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 31))
    end

    it "handles times with zones" do
      # Use a time that when translated to the default timezone (Eastern) that results in it being the 5th day fo the fiscal calendar
      time = ActiveSupport::TimeZone["UTC"].parse "2017-03-12 00:00"

      expect {|b| subject.run_if_fiscal_day(importer, 5, current_time: time, &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 11))
    end

    it "allows using an alternate timezone" do
      # Use a time that when translated to the default timezone (Eastern) that results in it being the 5th day fo the fiscal calendar
      time = ActiveSupport::TimeZone["UTC"].parse "2017-03-12 00:00"

      # Because we're doing the calculation based on UTC, 3-12 is not the 5th day of the fiscal month.
      expect { |b| subject.run_if_fiscal_day(importer, 5, current_time: time, relative_to_timezone: "UTC", &b) }.not_to yield_control
    end

    it "utilizes the current_time if not given" do
      # By default, the code will translate the frozen current_time to Eastern, so it'll be 3/11 and thus yielded
      Timecop.freeze(ActiveSupport::TimeZone["UTC"].parse "2017-03-12 00:00") do
        expect {|b| subject.run_if_fiscal_day(importer, 5, current_time: Date.new(2017, 3, 11), &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 11))
      end
    end

    it "allows passing importer id" do
      expect {|b| subject.run_if_fiscal_day(importer.id, 5, current_time: Date.new(2017, 3, 11), &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 11))
    end

    it "allows passing importer system code" do
      expect {|b| subject.run_if_fiscal_day(importer.system_code, 5, current_time: Date.new(2017, 3, 11), &b)}.to yield_with_args(fiscal_month, Date.new(2017, 3, 11))
    end
  end


  describe "run_if_configured" do
    let (:config) {
      {"company" => "ASCE", "fiscal_day" => "5"}
    }

    let (:fiscal_month) { FiscalMonth.new }
    let (:fiscal_date) { Date.new 2017, 3, 1 }

    it "uses configuration with default values" do
      expect(subject).to receive(:run_if_fiscal_day).with("ASCE", 5, relative_to_timezone: "America/New_York", relative_to_start: true).and_yield fiscal_month, fiscal_date

      expect {|b| subject.run_if_configured(config, &b) }.to yield_with_args fiscal_month, fiscal_date
    end

    it "passes alternate timezone and relative to start value" do
      config["relative_to_start"] = "false"
      config["relative_to_timezone"] = "UTC"

      expect(subject).to receive(:run_if_fiscal_day).with("ASCE", 5, relative_to_timezone: "UTC", relative_to_start: false)
      expect {|b| subject.run_if_configured(config, &b)}.not_to yield_control
    end
  end
end