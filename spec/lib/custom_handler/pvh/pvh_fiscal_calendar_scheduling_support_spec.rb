describe OpenChain::CustomHandler::Pvh::PvhFiscalCalendarSchedulingSupport do

  subject do
    Class.new do
      include OpenChain::CustomHandler::Pvh::PvhFiscalCalendarSchedulingSupport
    end.new
  end

  let (:monthly) { OpenChain::FiscalCalendarSchedulingSupport::MONTHLY_SCHEDULING }
  let (:quarterly) { OpenChain::FiscalCalendarSchedulingSupport::QUARTERLY_SCHEDULING }
  let (:biannually) { OpenChain::FiscalCalendarSchedulingSupport::BIANNUAL_SCHEDULING }

  describe "get_fiscal_period_dates" do
    let! (:importer) { Factory(:company, system_code: "ARF") }

    it "raises error if importer record can't be found" do
      expect { subject.get_fiscal_period_dates("2020-05", nil, monthly, "SNARF") }.to raise_error "SNARF company account could not be found."
    end

    context "monthly" do
      it "computes date range from user-provided base value" do
        FiscalMonth.create! company_id: importer.id, year: 2020, month_number: 5, start_date: Date.new(2020, 3, 15), end_date: Date.new(2020, 4, 14)

        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect(subject.get_fiscal_period_dates("2020-05", nil, monthly, "ARF")).to eq ["2020-03-15", "2020-04-14", 5, 2020]
        end
      end

      it "handles malformed month choice" do
        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect { subject.get_fiscal_period_dates("202005", nil, monthly, "ARF") }.to raise_error "Fiscal month 202005 not found."
        end
      end

      it "raises error if selected fiscal month doesn't exist" do
        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect { subject.get_fiscal_period_dates("2020-05", nil, monthly, "ARF") }.to raise_error "Fiscal month 2020-05 not found."
        end
      end

      it "defaults date range when user has not selected a base month, starting month is known" do
        FiscalMonth.create! company_id: importer.id, year: 2020, month_number: 3, start_date: Date.new(2020, 4, 15), end_date: Date.new(2020, 5, 14)
        fm_2 = FiscalMonth.create! company_id: importer.id, year: 2020, month_number: 4, start_date: Date.new(2020, 5, 15), end_date: Date.new(2020, 6, 14)

        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect(subject.get_fiscal_period_dates(nil, fm_2, monthly, "ARF")).to eq ["2020-04-15", "2020-05-14", 3, 2020]
        end
      end

      it "defaults date range when user has not selected a base month, starting month is unknown" do
        FiscalMonth.create! company_id: importer.id, year: 2021, month_number: 4, start_date: Date.new(2021, 4, 15), end_date: Date.new(2021, 5, 14)
        FiscalMonth.create! company_id: importer.id, year: 2021, month_number: 5, start_date: Date.new(2021, 5, 15), end_date: Date.new(2021, 6, 14)

        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect(subject.get_fiscal_period_dates(nil, nil, monthly, "ARF")).to eq ["2021-04-15", "2021-05-14", 4, 2021]
        end
      end

      it "raises error when previous fiscal month cannot be found when defaulting" do
        # This is the current month (based on current/timecop date).  Previous month record doesn't exist.
        FiscalMonth.create! company_id: importer.id, year: 2021, month_number: 5, start_date: Date.new(2021, 5, 15), end_date: Date.new(2021, 6, 14)

        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect { subject.get_fiscal_period_dates(nil, nil, monthly, "ARF") }.to raise_error "Fiscal month to use could not be determined."
        end
      end

      it "raises error when current fiscal month cannot be found when defaulting" do
        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect { subject.get_fiscal_period_dates(nil, nil, monthly, "ARF") }.to raise_error "Fiscal month to use could not be determined."
        end
      end
    end

    context "quarterly" do
      it "computes date range from user-provided base value" do
        fm = FiscalMonth.create! company_id: importer.id, year: 2020, month_number: 5
        expect(OpenChain::FiscalCalendarSchedulingSupport).to receive(:get_fiscal_quarter_start_end_dates).with(fm).and_return [Date.new(2020, 3, 15), Date.new(2020, 4, 14)]

        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect(subject.get_fiscal_period_dates("2020-05", nil, quarterly, "ARF")).to eq ["2020-03-15", "2020-04-14", 5, 2020]
        end
      end

      it "defaults date range when user has not selected a base month, starting month is known" do
        fm_1 = FiscalMonth.create! company_id: importer.id, year: 2020, month_number: 3
        fm_2 = FiscalMonth.create! company_id: importer.id, year: 2020, month_number: 4, start_date: Date.new(2020, 5, 15), end_date: Date.new(2020, 6, 14)
        expect(OpenChain::FiscalCalendarSchedulingSupport).to receive(:get_fiscal_quarter_start_end_dates).with(fm_1).and_return [Date.new(2020, 4, 15), Date.new(2020, 5, 14)]

        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect(subject.get_fiscal_period_dates(nil, fm_2, quarterly, "ARF")).to eq ["2020-04-15", "2020-05-14", 3, 2020]
        end
      end

      it "defaults date range when user has not selected a base month, starting month is unknown" do
        fm_1 = FiscalMonth.create! company_id: importer.id, year: 2021, month_number: 4
        FiscalMonth.create! company_id: importer.id, year: 2021, month_number: 5, start_date: Date.new(2021, 5, 15), end_date: Date.new(2021, 6, 14)
        expect(OpenChain::FiscalCalendarSchedulingSupport).to receive(:get_fiscal_quarter_start_end_dates).with(fm_1).and_return [Date.new(2021, 4, 15), Date.new(2021, 5, 14)]

        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect(subject.get_fiscal_period_dates(nil, nil, quarterly, "ARF")).to eq ["2021-04-15", "2021-05-14", 4, 2021]
        end
      end
    end

    context "biannually" do
      it "computes date range from user-provided base value" do
        fm = FiscalMonth.create! company_id: importer.id, year: 2020, month_number: 5
        expect(OpenChain::FiscalCalendarSchedulingSupport).to receive(:get_fiscal_half_start_end_dates).with(fm).and_return [Date.new(2020, 3, 15), Date.new(2020, 4, 14)]

        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect(subject.get_fiscal_period_dates("2020-05", nil, biannually, "ARF")).to eq ["2020-03-15", "2020-04-14", 5, 2020]
        end
      end

      it "defaults date range when user has not selected a base month, starting month is known" do
        fm_1 = FiscalMonth.create! company_id: importer.id, year: 2020, month_number: 3
        fm_2 = FiscalMonth.create! company_id: importer.id, year: 2020, month_number: 4, start_date: Date.new(2020, 5, 15), end_date: Date.new(2020, 6, 14)
        expect(OpenChain::FiscalCalendarSchedulingSupport).to receive(:get_fiscal_half_start_end_dates).with(fm_1).and_return [Date.new(2020, 4, 15), Date.new(2020, 5, 14)]

        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect(subject.get_fiscal_period_dates(nil, fm_2, biannually, "ARF")).to eq ["2020-04-15", "2020-05-14", 3, 2020]
        end
      end

      it "defaults date range when user has not selected a base month, starting month is unknown" do
        fm_1 = FiscalMonth.create! company_id: importer.id, year: 2021, month_number: 4
        FiscalMonth.create! company_id: importer.id, year: 2021, month_number: 5, start_date: Date.new(2021, 5, 15), end_date: Date.new(2021, 6, 14)
        expect(OpenChain::FiscalCalendarSchedulingSupport).to receive(:get_fiscal_half_start_end_dates).with(fm_1).and_return [Date.new(2021, 4, 15), Date.new(2021, 5, 14)]

        Timecop.freeze(Date.new(2021, 6, 3)) do
          expect(subject.get_fiscal_period_dates(nil, nil, biannually, "ARF")).to eq ["2021-04-15", "2021-05-14", 4, 2021]
        end
      end
    end
  end

  describe "filename_fiscal_descriptor" do
    it "assembles biannual descriptor" do
      (1..6).each do |month|
        expect(subject.filename_fiscal_descriptor(2020, month, biannually)).to eq "Fiscal_2020-Half-1"
      end
      # Quarterly being true still returns biannual description.  Biannual flag bests it.
      expect(subject.filename_fiscal_descriptor(2019, 1, biannually)).to eq "Fiscal_2019-Half-1"
      (7..12).each do |month|
        expect(subject.filename_fiscal_descriptor(2020, month, biannually)).to eq "Fiscal_2020-Half-2"
      end
    end

    it "assembles quarterly descriptor" do
      (1..3).each do |month|
        expect(subject.filename_fiscal_descriptor(2020, month, quarterly)).to eq "Fiscal_2020-Quarter-1"
      end
      (4..6).each do |month|
        expect(subject.filename_fiscal_descriptor(2020, month, quarterly)).to eq "Fiscal_2020-Quarter-2"
      end
      (7..9).each do |month|
        expect(subject.filename_fiscal_descriptor(2020, month, quarterly)).to eq "Fiscal_2020-Quarter-3"
      end
      (10..12).each do |month|
        expect(subject.filename_fiscal_descriptor(2019, month, quarterly)).to eq "Fiscal_2019-Quarter-4"
      end
    end

    it "assembles monthly descriptor" do
      (1..9).each do |month|
        expect(subject.filename_fiscal_descriptor(2020, month, monthly)).to eq "Fiscal_2020-0#{month}"
      end
      (10..12).each do |month|
        expect(subject.filename_fiscal_descriptor(2019, month, monthly)).to eq "Fiscal_2019-#{month}"
      end
    end
  end

end