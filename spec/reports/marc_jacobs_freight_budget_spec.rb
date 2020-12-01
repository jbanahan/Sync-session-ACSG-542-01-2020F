describe OpenChain::Report::MarcJacobsFreightBudget do
  before :each do
    @u = FactoryBot(:user)
    @good_entry = FactoryBot(:entry, :release_date=>0.seconds.ago, :house_bills_of_lading=>'HBOL',
      :broker_invoice_total=>90, :total_duty=>80, :total_fees=>50, :master_bills_of_lading=>'MBOL',
      :importer=>with_customs_management_id(FactoryBot(:company), "MARJAC"))
    allow_any_instance_of(Entry).to receive(:can_view?).and_return(true)
  end
  after :each do
    @tmp.unlink if @tmp
  end

  describe "permission?" do
    let!(:ms) { stub_master_setup_for_reports }

    it "should reject if user cannot view an entry" do
      allow_any_instance_of(Entry).to receive(:can_view?).and_return(false)
      expect {described_class.run_report @u}.to raise_error "You do not have permission to view the entries on this report."
    end

    it "should allow Marc Jacobs users access to the report" do
      @u.update_attributes! company_id: @good_entry.importer_id
      expect(described_class.permission?(@u)).to be_truthy
    end
  end

  describe "run_report" do
    it "should default to current year if not set" do
      mr = double('report')
      allow(mr).to receive(:run).and_return('x')
      expect(described_class).to receive(:new).with(@u, Time.now.year, 5).and_return(mr)
      expect(described_class.run_report(@u, 'month'=>5)).to eq('x')
    end
    it "should default to current month if not set" do
      mr = double('report')
      allow(mr).to receive(:run).and_return('x')
      expect(described_class).to receive(:new).with(@u, 2010, Time.now.month).and_return(mr)
      expect(described_class.run_report(@u, 'year'=>2010)).to eq('x')
    end
    it "should filter on proper year / month parameters" do
      mr = double('report')
      allow(mr).to receive(:run).and_return('x')
      expect(described_class).to receive(:new).with(@u, 2010, 5).and_return(mr)
      expect(described_class.run_report(@u, 'year'=>2010, 'month'=>5)).to eq('x')
    end

    it "should write headings" do
      @tmp = described_class.run_report @u
      r = Spreadsheet.open(@tmp).worksheet(0).row(0)
      ["Broker", "Month", "HAWB", "Brokerage Fee", "Duty",
        "Total Fees", "Master", "Forwarder"].each_with_index do |h, i|
        expect(r[i]).to eq(h)
      end
    end
    it "should write full row" do
      @good_entry.update_attributes(:release_date=>Date.new(2004, 7, 10))
      @tmp = described_class.run_report @u, 'year'=>2004, 'month'=>7
      r = Spreadsheet.open(@tmp).worksheet(0).row(1)
      ["Vandegrift", "July", "HBOL", 90, 80, 50, "MBOL"].each_with_index do |v, i|
        expect(r[i]).to eq(v)
      end
    end
    it "should include entries in given month" do
      @good_entry.update_attributes(:release_date=>Date.new(2004, 7, 10))
      @tmp = described_class.run_report @u, 'year'=>2004, 'month'=>7
      r = Spreadsheet.open(@tmp).worksheet(0).row(1)
      expect(r[2]).to eq(@good_entry.house_bills_of_lading)
    end
    it "should not include entries outside of given month" do
      @good_entry.update_attributes(:release_date=>Date.new(2004, 7, 10))
      @tmp = described_class.run_report @u, 'year'=>2004, 'month'=>5
      r = Spreadsheet.open(@tmp).worksheet(0).row(1)
      expect(r.size).to eq 0
    end

    it "should only include entries for customer MARJAC" do
      @good_entry.importer.system_identifiers.destroy_all
      @tmp = described_class.run_report @u
      r = Spreadsheet.open(@tmp).worksheet(0).row(1)
      expect(r.size).to eq 0
    end

    it "should prorate charges using simple proration by HAWB count" do
      @good_entry.update_attributes(:house_bills_of_lading=>"1\n2")
      @tmp = described_class.run_report @u
      s = Spreadsheet.open(@tmp).worksheet(0)
      [["Vandegrift", Time.now.strftime("%B"), "1", 45, 40, 25, "MBOL"],
      ["Vandegrift", Time.now.strftime("%B"), "2", 45, 40, 25, "MBOL"]].each_with_index do |vs, rc|
        r = s.row(rc+1)
        vs.each_with_index {|v, i| expect(r[i]).to eq(v)}
      end
    end
    it "should add/remove odd pennies on last prorated value" do
      @good_entry.update_attributes(:house_bills_of_lading=>"1\n2\n3")
      @tmp = described_class.run_report @u
      s = Spreadsheet.open(@tmp).worksheet(0)
      [["Vandegrift", Time.now.strftime("%B"), "1", 30, 26.67, 16.67, "MBOL"],
      ["Vandegrift", Time.now.strftime("%B"), "2", 30, 26.67, 16.67, "MBOL"],
      ["Vandegrift", Time.now.strftime("%B"), "3", 30, 26.66, 16.66, "MBOL"]].each_with_index do |vs, rc|
        r = s.row(rc+1)
        vs.each_with_index {|v, i| expect(r[i]).to eq(v)}
      end
    end

    it "should write row if no hbol" do
      @good_entry.update_attributes(:house_bills_of_lading=>nil)
      @tmp = described_class.run_report @u
      r = Spreadsheet.open(@tmp).worksheet(0).row(1)
      ["Vandegrift", Time.now.strftime("%B"), " ", 90, 80, 50, "MBOL"].each_with_index do |v, i|
        expect(r[i]).to eq(v)
      end
    end
  end
end
