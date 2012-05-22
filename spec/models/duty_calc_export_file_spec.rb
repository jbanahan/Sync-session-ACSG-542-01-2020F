require 'spec_helper'

describe DutyCalcExportFile do
  describe :generate_csv do
    it "should output csv for all lines" do
      2.times {DutyCalcExportFileLine.create!}
      DutyCalcExportFileLine.any_instance.stub(:make_line_array).and_return(["a","b"])
      d, t = DutyCalcExportFile.generate_csv
      d.should have(2).duty_calc_export_file_lines
      CSV.read(t.path).should have(2).rows
      
    end
  end
end
