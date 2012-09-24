require 'spec_helper'

describe DutyCalcExportFile do
  describe :generate_csv do
    before :each do
      @importer = Factory(:company,:importer=>true)
      2.times {DutyCalcExportFileLine.create!(:importer_id=>@importer.id)}
      DutyCalcExportFileLine.any_instance.stub(:make_line_array).and_return(["a","b"])
    end
    it "should output csv for all lines" do
      d, t = DutyCalcExportFile.generate_csv @importer
      d.should have(2).duty_calc_export_file_lines
      d.importer.should == @importer
      CSV.read(t.path).should have(2).rows
      
    end
    it "should not output csv for different importer" do
      other_company = Factory(:company,:importer=>true)
      d, t = DutyCalcExportFile.generate_csv @importer
      d.should have(2).duty_calc_export_file_lines
      CSV.read(t.path).should have(2).rows
      DutyCalcExportFileLine.create!(:importer_id=>other_company.id)
    end
  end
end
