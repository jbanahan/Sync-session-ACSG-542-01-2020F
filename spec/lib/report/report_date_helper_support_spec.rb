describe OpenChain::Report::ReportDateHelperSupport do

  subject { Class.new { include OpenChain::Report::ReportDateHelperSupport }.new }

  describe "parse_date_range_from_opts" do

    let (:basis_date) { Date.new(2020, 9, 1) }

    it "handles given start_date / end_date values" do
      start_date, end_date = subject.parse_date_range_from_opts({'start_date' => '2020-01-01', 'end_date' => '2020-02-01'}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2020, 1, 1)
      expect(end_date).to eq Date.new(2020, 2, 1)
    end

    it "handles previous day value without numeric value" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_day' => true}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2020, 8, 31)
      expect(end_date).to eq Date.new(2020, 8, 31)
    end

    it "handles previous day value with numeric value" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_day' => 2}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2020, 8, 30)
      expect(end_date).to eq Date.new(2020, 8, 30)
    end

    it "handles previous day value with numeric value, without inclusivity" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_day' => 2}, basis_date: basis_date, end_date_inclusive: false)
      expect(start_date).to eq Date.new(2020, 8, 30)
      expect(end_date).to eq Date.new(2020, 8, 31)
    end

    it "handles previous day value with end_date override" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_day' => 2, 'end_date' => '2020-09-01'}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2020, 8, 30)
      expect(end_date).to eq Date.new(2020, 9, 1)
    end

    it "handles previous week value without numeric value" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_week' => true}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2020, 8, 23)
      expect(end_date).to eq Date.new(2020, 8, 29)
    end

    it "handles previous week value with numeric value" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_week' => 2}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2020, 8, 16)
      expect(end_date).to eq Date.new(2020, 8, 22)
    end

    it "handles previous week value with numeric value, without inclusivity" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_week' => 2}, basis_date: basis_date, end_date_inclusive: false)
      expect(start_date).to eq Date.new(2020, 8, 16)
      expect(end_date).to eq Date.new(2020, 8, 23)
    end

    it "handles previous week value with end_date override" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_week' => 2, 'end_date' => '2020-09-01'}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2020, 8, 16)
      expect(end_date).to eq Date.new(2020, 9, 1)
    end

    it "handles previous month value without numeric value" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_month' => true}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2020, 8, 1)
      expect(end_date).to eq Date.new(2020, 8, 31)
    end

    it "handles previous month value with numeric value" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_month' => 2}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2020, 7, 1)
      expect(end_date).to eq Date.new(2020, 7, 31)
    end

    it "handles previous month value with numeric value, without inclusivity" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_month' => 2}, basis_date: basis_date, end_date_inclusive: false)
      expect(start_date).to eq Date.new(2020, 7, 1)
      expect(end_date).to eq Date.new(2020, 8, 1)
    end

    it "handles previous month value with end_date override" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_month' => 2, 'end_date' => '2020-09-01'}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2020, 7, 1)
      expect(end_date).to eq Date.new(2020, 9, 1)
    end

    it "handles previous year value without numeric value" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_year' => true}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2019, 1, 1)
      expect(end_date).to eq Date.new(2019, 12, 31)
    end

    it "handles previous year value with numeric value" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_year' => 2}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2018, 1, 1)
      expect(end_date).to eq Date.new(2018, 12, 31)
    end

    it "handles previous year value with numeric value, without inclusivity" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_year' => 2}, basis_date: basis_date, end_date_inclusive: false)
      expect(start_date).to eq Date.new(2018, 1, 1)
      expect(end_date).to eq Date.new(2019, 1, 1)
    end

    it "handles previous year value with end_date override" do
      start_date, end_date = subject.parse_date_range_from_opts({'previous_year' => 2, 'end_date' => '2020-09-01'}, basis_date: basis_date)
      expect(start_date).to eq Date.new(2018, 1, 1)
      expect(end_date).to eq Date.new(2020, 9, 1)
    end
  end
end