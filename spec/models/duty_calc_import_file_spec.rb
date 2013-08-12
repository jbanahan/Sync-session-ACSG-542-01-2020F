require 'spec_helper'

describe DutyCalcImportFile do
  before :each do
    @importer = Factory(:company,:importer=>true)
    @product = Factory(:product)
    2.times {DrawbackImportLine.create!(importer_id:@importer.id,
      product:@product,quantity:10
    )}
    DrawbackImportLine.any_instance.stub(:duty_calc_line_array).and_return(["a","b"])
    @zip_path = 'spec/support/tmp/dci.zip'
    File.delete(@zip_path) if File.exist?(@zip_path)
    @to_del = [@zip_path]
    @user = Factory(:user)
  end
  after :each do
    @to_del.each {|x| File.unlink(x) if File.exist?(x)}
  end
  describe :generate_for_importer do
    it "should generate excel zip and attach" do
      zip = mock('outputzip')
      zip.should_receive(:original_filename=).with('abc.txt')
      dcif = DutyCalcImportFile.create!(importer_id:@importer.id)
      att = mock('attachment')
      Attachment.should_receive(:add_original_filename_method).with(zip)
      DutyCalcImportFile.should_receive(:generate_excel_zip).with(@importer,@user,'tmp/abc.txt').and_return([dcif,zip])
      dcif.should_receive(:build_attachment).and_return att
      att.should_receive(:attached=).with(zip)
      att.should_receive(:save!).and_return(true)
      out_obj, out_file = DutyCalcImportFile.generate_for_importer @importer, @user, 'tmp/abc.txt'
      out_obj.should == dcif
      out_file.should == zip
      @user.reload
      @user.should have(1).messages
    end
  end
  describe :generate_excel_zip do
    it "should generate a single zipped excel file" do
      d, f = DutyCalcImportFile.generate_excel_zip @importer, @user, @zip_path
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
      d.duty_calc_import_file_lines.pluck(:drawback_import_line_id).sort.should == DrawbackImportLine.scoped.pluck(:id).sort
    end
    it "should generate multiple when the number of lines is over the max_lines_per_file" do
      d, f = DutyCalcImportFile.generate_excel_zip @importer, @user, @zip_path, 1
      Zip::ZipFile.open(f.path) do |zipfile|
        zipfile.dir.entries("/").should == ["File 1.xls","File 2.xls"]
      end
    end
  end
end
