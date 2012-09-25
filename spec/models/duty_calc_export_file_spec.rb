require 'zip/zipfilesystem'
require 'spreadsheet'
require 'spec_helper'

describe DutyCalcExportFile do
  before :each do
    @importer = Factory(:company,:importer=>true)
    2.times {DutyCalcExportFileLine.create!(:importer_id=>@importer.id)}
    DutyCalcExportFileLine.any_instance.stub(:make_line_array).and_return(["a","b"])
    @zip_path = 'spec/support/tmp/dce.zip'
    File.delete(@zip_path) if File.exist?(@zip_path)
    @to_del = [@zip_path]
  end

  after :each do
    @to_del.each {|x| File.unlink(x) if File.exist?(x)}
  end

  describe :generate_excel_zip do
    it "should generate a single zipped excel file" do
      f = DutyCalcExportFile.generate_excel_zip @importer, @zip_path
      Zip::ZipFile.open(f.path) do |zipfile|
        zipfile.dir.entries("/").should have(1).item
        z_out = 'spec/support/tmp/x.xls'
        @to_del << z_out
        zipfile.extract(zipfile.dir.entries("/").first, z_out)
        workbook = Spreadsheet.open(z_out)
        sheet = workbook.worksheet(0)
        sheet.name.should == "SHEET1"
        sheet.row(0)[0].should == "a"
        sheet.row(0)[1].should == "b"
        sheet.row(1)[0].should == "a"
        sheet.row(1)[1].should == "b"
      end
    end
    it "should generate multiple when the number of lines is over the max_lines_per_file" do
      f = DutyCalcExportFile.generate_excel_zip @importer, @zip_path, 1
      Zip::ZipFile.open(f.path) do |zipfile|
        zipfile.dir.entries("/").should == ["File 1.xls","File 2.xls"]
      end
    end
  end
  describe :generate_csv do
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
