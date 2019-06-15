describe FiscalMonth do
  let(:user) { Factory(:sys_admin_user) }
  let(:fm) { Factory(:fiscal_month)}
  let(:co) { Factory(:company) }
  let(:date1) { Date.new(2014,3,15) }
  let(:date2) { Date.new(2014,3,16) }
  let(:date3) { Date.new(2015,4,15) }
  let(:date4) { Date.new(2015,4,16) }

  describe "can_view?" do
    it "allows sys-admins" do
      expect(fm.can_view? user).to eq true
    end

    it "rejects non-sys-admins" do
      user.sys_admin = false; user.save!
      expect(fm.can_view? user).to eq false
    end
  end

  describe "can_edit?" do
    it "allows sys-admins" do
      expect(fm.can_edit? user).to eq true
    end

    it "rejects non-sys-admins" do
      user.sys_admin = false; user.save!
      expect(fm.can_edit? user).to eq false
    end
  end

  context "forward/back" do
    let!(:co) { Factory(:company) }
    let!(:fm_1) { Factory(:fiscal_month, company: co, month_number: 11, year: 2016, start_date: "2016-11-01", end_date: "2016-01-30") }
    let!(:fm_2) { Factory(:fiscal_month, company: co, month_number: 12, year: 2016, start_date: "2016-12-01", end_date: "2016-12-31") }
    let!(:fm_3) { Factory(:fiscal_month, company: co, month_number: 1, year: 2017, start_date: "2017-01-01", end_date: "2017-01-31") }
    let!(:fm_4) { Factory(:fiscal_month, company: co, month_number: 2, year: 2017, start_date: "2017-02-01", end_date: "2017-02-28") }
    
    describe "forward" do
      it "returns the nth future fiscal month" do
        expect(fm_1.forward 2).to eq fm_3
        expect(fm_3.forward 1).to eq fm_4
      end
    end

    describe "back" do
      it "returns the nth previous fiscal month" do
        expect(fm_4.back 2).to eq fm_2
        expect(fm_2.back 1).to eq fm_1
      end
    end
  end

  describe "get" do
    let!(:co) { Factory(:company) }
    let!(:fm) { Factory(:fiscal_month, company: co, year: 2017, month_number: 3, start_date: "2017-03-01", end_date: "2017-03-30") }
    
    it "returns fiscal month containing a given date. Also takes a company" do  
      expect(described_class.get(co, Date.new(2017,3,12))).to eq fm
    end

    it "returns fiscal month containing a given date. Also take a company id" do
      expect(described_class.get(co.id, Date.new(2017,3,12))).to eq fm
    end
  end

  describe "generate_csv" do

    it "returns 4 column CSV, including only fiscal months belonging to specified company" do
      Factory(:fiscal_month, company: co, year: 2015, month_number: 2, start_date: date3, end_date: date4)
      Factory(:fiscal_month, company: co, year: 2015, month_number: 1, start_date: date1, end_date: date2)
      Factory(:fiscal_month)

      csv = FiscalMonth.generate_csv(co.id).split("\n")
      expect(csv.count).to eq 3
      expect(csv[0].split(",")).to eq ["Fiscal Year", "Fiscal Month", "Actual Start Date", "Actual End Date"]
      expect(csv[1].split(",")).to eq ["2015", "1", date1.strftime("%Y-%m-%d"), date2.strftime("%Y-%m-%d")]
      expect(csv[2].split(",")).to eq ["2015", "2", date3.strftime("%Y-%m-%d"), date4.strftime("%Y-%m-%d")]
    end
  end
end
