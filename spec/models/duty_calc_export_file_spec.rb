require 'fileutils'
require 'zip/zipfilesystem'
require 'spreadsheet'
require 'spec_helper'

describe DutyCalcExportFile do
  before :each do
    @importer = Factory(:company,:importer=>true)
    2.times {DutyCalcExportFileLine.create!(importer_id:@importer.id,export_date:Date.new(2013,9,10))}
    DutyCalcExportFileLine.any_instance.stub(:make_line_array).and_return(["a","b"])
    FileUtils::mkdir_p 'spec/support/tmp' #make sure directory is there
    @zip_path = 'spec/support/tmp/dce.zip'
    File.delete(@zip_path) if File.exist?(@zip_path)
    @to_del = [@zip_path]
  end

  after :each do
    @to_del.each {|x| File.unlink(x) if File.exist?(x)}
  end

  describe :generate_for_importer do
    it "should generate excel zip and attach" do
      u = Factory(:master_user)
      expect{DutyCalcExportFile.generate_for_importer @importer, u}.to change(DutyCalcExportFile,:count).from(0).to(1)
      d = DutyCalcExportFile.first
      expect(d.attachment).not_to be_nil
      u.reload
      u.should have(1).messages
    end
    it "should generate multiple zips" do
      expect{DutyCalcExportFile.generate_for_importer(@importer, nil, nil, nil, 1, 1)}.to change(DutyCalcExportFile,:count).from(0).to(2)
    end
  end
  describe :generate_excel_zip do
    it "should cap at max files" do
      2.times {DutyCalcExportFileLine.create!(importer_id:@importer.id,export_date:Date.new(2013,9,10))} #makes 4 total because of before each
      d, f = DutyCalcExportFile.generate_excel_zip @importer, @zip_path, 1, nil, 2
      Zip::ZipFile.open(f.path) do |zipfile|
        zipfile.dir.entries("/").should have(2).items
      end
      #should have 2 files not included because past the max size
      expect(DutyCalcExportFileLine.where(duty_calc_export_file_id:nil).count).to eq 2
    end
    it "should generate a single zipped excel file" do
      d, f = DutyCalcExportFile.generate_excel_zip @importer, @zip_path
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
      d, f = DutyCalcExportFile.generate_excel_zip @importer, @zip_path, 1
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
      DutyCalcExportFileLine.create!(:importer_id=>other_company.id)
      d, t = DutyCalcExportFile.generate_csv @importer
      d.should have(2).duty_calc_export_file_lines
      CSV.read(t.path).should have(2).rows
    end
    it "should restrict by extra where clause" do
      w = "duty_calc_export_file_lines.export_date between '2013-01-01' AND '2013-01-05'"
      l = DutyCalcExportFileLine.create!(importer_id:@importer.id,export_date:Date.new(2013,1,2))
      d, t = DutyCalcExportFile.generate_csv @importer, Tempfile.new(['dcef','.csv']), w
      d.duty_calc_export_file_lines.to_a.should == [l]
      CSV.read(t.path).should have(1).rows
    end
  end
end
