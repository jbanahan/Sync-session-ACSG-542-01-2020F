require 'spec_helper'

describe OpenChain::Report::DrawbackExportsWithoutImports do
  describe :run_report do
    before :each do
      @c = Factory(:company)
      @u = Factory(:user)
      described_class.stub(:can_run?).and_return(true)
      @exp = DutyCalcExportFileLine.create!(:part_number=>'ABC',:export_date=>1.day.ago,:quantity=>100,:ref_1=>'r1',:ref_2=>'r2',:importer_id=>@c.id)
    end
    after :each do
      @tmp.unlink if @tmp
    end
    it "should write worksheet" do
      @tmp = described_class.run_report @u, {:start_date=>1.month.ago,:end_date=>1.month.from_now}
      wb = Spreadsheet.open @tmp
      s = wb.worksheet 0
      r = s.row(1)
      r[0].strftime("%Y%m%d").should == @exp.export_date.strftime("%Y%m%d")
      r[1].should == @exp.part_number
      r[2].should == @exp.ref_1
      r[3].should == @exp.ref_2
      r[4].should == @exp.quantity
    end
    it "should write headings" do
      @tmp = described_class.run_report @u, {:start_date=>1.month.ago,:end_date=>1.month.from_now}
      wb = Spreadsheet.open @tmp
      s = wb.worksheet 0
      r = s.row(0)
      ["Export Date","Part Number","Ref 1","Ref 2","Quantity"].should == (0..4).collect {|i| r[i]}
    end
    it "should only include exports within date range" do
      @tmp = described_class.run_report @u, {:start_date=>1.month.ago,:end_date=>1.week.ago}
      wb = Spreadsheet.open @tmp
      s = wb.worksheet 0
      r = s.row(1)
      r.should be_empty
    end
    it "should only include exports within 'not_in_imports' scope" do
      dont_find = DutyCalcExportFileLine.create!(:part_number=>'DEF',:export_date=>1.day.ago,:quantity=>100,:ref_1=>'r1',:ref_2=>'r2',:importer_id=>@c.id)
      DrawbackImportLine.create!(:part_number=>dont_find.part_number,:import_date=>1.month.ago,:product=>Factory(:product),:importer_id=>@c.id)
      @tmp = described_class.run_report @u, {:start_date=>1.month.ago,:end_date=>1.month.from_now}
      wb = Spreadsheet.open @tmp
      s = wb.worksheet 0
      r = s.row(1)
      r[1].should == @exp.part_number
      s.row(2).should be_empty
    end
    it "should fail if user cannot run report" do
      described_class.stub(:can_run?).and_return(false)
      lambda {described_class.run_report @user}.should raise_error "You do not have permission to run this report." 
    end
  end
  describe :can_run? do
    it "should not run if user not from master company" do
      u = Factory(:user)
      u.stub(:view_drawback?).and_return(true)
      described_class.can_run?(u).should be_false
    end
    it "should not run if user cannot view drawback" do
      u = Factory(:master_user)
      u.stub(:view_drawback?).and_return(false)
      described_class.can_run?(u).should be_false
    end
    it "should run if user has permission" do
      u = Factory(:master_user)
      u.stub(:view_drawback?).and_return(true)
      described_class.can_run?(u).should be_true
    end
  end
end
