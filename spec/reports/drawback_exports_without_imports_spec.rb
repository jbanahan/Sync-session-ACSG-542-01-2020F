describe OpenChain::Report::DrawbackExportsWithoutImports do
  describe "run_report" do
    before :each do
      @c = FactoryBot(:company)
      @u = FactoryBot(:user)
      allow(described_class).to receive(:permission?).and_return(true)
      @exp = DutyCalcExportFileLine.create!(:part_number=>'ABC', :export_date=>1.day.ago, :quantity=>100, :ref_1=>'r1', :ref_2=>'r2', :importer_id=>@c.id)
    end
    after :each do
      @tmp.unlink if @tmp
    end
    it "should write worksheet" do
      @tmp = described_class.run_report @u, {'start_date'=>1.month.ago, 'end_date'=>1.month.from_now}
      wb = Spreadsheet.open @tmp
      s = wb.worksheet 0
      r = s.row(1)
      expect(r[0].strftime("%Y%m%d")).to eq(@exp.export_date.strftime("%Y%m%d"))
      expect(r[1]).to eq(@exp.part_number)
      expect(r[2]).to eq(@exp.ref_1)
      expect(r[3]).to eq(@exp.ref_2)
      expect(r[4]).to eq(@exp.quantity)
    end
    it "should write headings" do
      @tmp = described_class.run_report @u, {'start_date'=>1.month.ago, 'end_date'=>1.month.from_now}
      wb = Spreadsheet.open @tmp
      s = wb.worksheet 0
      r = s.row(0)
      expect(["Export Date", "Part Number", "Ref 1", "Ref 2", "Quantity"]).to eq((0..4).collect {|i| r[i]})
    end
    it "should only include exports within date range" do
      @tmp = described_class.run_report @u, {'start_date'=>1.month.ago, 'end_date'=>1.week.ago}
      wb = Spreadsheet.open @tmp
      s = wb.worksheet 0
      r = s.row(1)
      expect(r).to be_empty
    end
    it "should only include exports within 'not_in_imports' scope" do
      dont_find = DutyCalcExportFileLine.create!(:part_number=>'DEF', :export_date=>1.day.ago, :quantity=>100, :ref_1=>'r1', :ref_2=>'r2', :importer_id=>@c.id)
      DrawbackImportLine.create!(:part_number=>dont_find.part_number, :import_date=>1.month.ago, :product_id=>FactoryBot(:product).id, :importer_id=>@c.id)
      @tmp = described_class.run_report @u, {'start_date'=>1.month.ago, 'end_date'=>1.month.from_now}
      wb = Spreadsheet.open @tmp
      s = wb.worksheet 0
      r = s.row(1)
      expect(r[1]).to eq(@exp.part_number)
      expect(s.row(2)).to be_empty
    end
    it "should fail if user cannot run report" do
      allow(described_class).to receive(:permission?).and_return(false)
      expect {described_class.run_report @user}.to raise_error "You do not have permission to run this report."
    end
  end
  describe "permission?" do
    it "should not run if user not from master company" do
      u = FactoryBot(:user)
      allow(u).to receive(:view_drawback?).and_return(true)
      expect(described_class.permission?(u)).to be_falsey
    end
    it "should not run if user cannot view drawback" do
      u = FactoryBot(:master_user)
      allow(u).to receive(:view_drawback?).and_return(false)
      expect(described_class.permission?(u)).to be_falsey
    end
    it "should run if user has permission" do
      u = FactoryBot(:master_user)
      allow(u).to receive(:view_drawback?).and_return(true)
      expect(described_class.permission?(u)).to be_truthy
    end
  end
end
