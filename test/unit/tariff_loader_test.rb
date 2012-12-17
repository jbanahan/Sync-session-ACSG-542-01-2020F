require 'test_helper'
require 'spreadsheet'
require 'zip/zip'

class TariffLoaderTest < ActiveSupport::TestCase

  cols = ["HSCODE","FULL_DESC","SPC_RATES","UNITCODE","GENERAL","CHAPTER","HEADING","SUBHEADING","REST_DESC","ADDVALOREMRATE","PERUNIT","MFN","GPT","ERGA_OMNES","COL2_RATE",
      "Import Reg 1","Import Reg 2","Import Reg 3","Import Reg 4","Export Reg 1","Export Reg 2","Export Reg 3","Export Reg 4"]
  
  def create_tariff_file excel, filename_prefix, starting_header_row, headers, number_of_rows, &block
    t = Tempfile.new(["#{filename_prefix}_tariffloadertest-general", excel ? ".xls" : ".csv"])
    if excel 
      wb = Spreadsheet::Workbook.new
      sheet = wb.create_worksheet
      sheet.row(starting_header_row).replace headers
      row_number = 0
      begin
        row = []
        headers.each_index do |i|
          row << "row-#{row_number} col-#{i}"
        end
        
        block_row = yield row, row_number if block_given?
        row = block_row unless block_row.nil?

        sheet.row(starting_header_row + (row_number += 1)).replace row
          
      end while row_number < number_of_rows
      wb.write t.path
    else 
      CSV.open(t.path, "wb") do |csv|
        row_num = 0
        begin
          csv << []
        end while (row_num += 1) < starting_header_row
        csv << headers
        row_number = 0
        
        begin
          row = []
          headers.each_index do |i|
            row << "row-#{row_number} col-#{i}"
          end
          block_row = yield row, row_number if block_given?
          row = block_row unless block_row.nil?

          csv << row
        end while (row_number += 1) < number_of_rows
      end
    end

    t
  end
  private

  test "s3 auto activate" do
    # asserts that we're pulling files from S3, processing them, and then activating the tariff set
    t = create_tariff_file true, '', 0, cols, 2

    country = Country.first
    label = "ABCDEFS3A"

    #PUT THE FILE TO S3
    s3 = AWS::S3.new AWS_CREDENTIALS
    begin
      key = "#{Rails.env.to_s}/TariffStore/#{File.basename(t)}"
      s3.buckets['chain-io'].objects[key].write(:file=>t.path)
      TariffLoader.process_s3 key, country, label, true
    ensure
      s3.buckets['chain-io'].objects[key].delete
    end

    ts = TariffSet.where(:label=>label).first
    assert_equal country, ts.country
    assert_equal 2, ts.tariff_set_records.size
    
    ot = OfficialTariff.where(:country_id=>country.id)
    assert_equal 2, ot.size
    expected_hts = ts.tariff_set_records.collect {|tsr| tsr.hts_code}
    ot.each {|o| expected_hts.delete o.hts_code}
    assert expected_hts.empty?
  end

  test "s3" do 
    # asserts that we're pulling files from S3 and processing them, but not activating them
    t = create_tariff_file true, '', 0, cols, 2

    country = Country.first
    label = "ABCDEFS3"

    #PUT THE FILE TO S3
    s3 = AWS::S3.new AWS_CREDENTIALS
    begin
      key = "#{Rails.env.to_s}/TariffStore/#{t.path.split('/').last}"
      s3.buckets['chain-io'].objects[key].write(:file=>t.path)
      TariffLoader.process_s3 key, country, label, false
    ensure
      s3.buckets['chain-io'].objects[key].delete
    end
    ts = TariffSet.where(:label=>label).first
    assert_equal country, ts.country
    assert_equal 2, ts.tariff_set_records.size

    assert_equal 0, OfficialTariff.where(:country_id=>country.id).size
  end

  test "activate" do 
    # Tests that we're processing a standard tariff file from the local filesystem and activating it
    rows = []
    t = create_tariff_file true, 'us', 0, cols, 2 do |row| 
      rows << row
      row
    end

    label = "ABCDEF"
    country = Country.where(:iso_code=>'US').first

    TariffLoader.process_file t.path, label, true

    ts = OfficialTariff.where(:country_id=>country.id) 
    assert_equal 2, ts.size

    result1 = ts.where(:country_id=>country.id,:hts_code=>rows[0][cols.index("HSCODE")]).first
    result2 = ts.where(:country_id=>country.id,:hts_code=>rows[1][cols.index("HSCODE")]).first
    validate_hts_data cols, result1, rows[0]
    validate_hts_data cols, result2, rows[1]
  end

  def validate_hts_data cols, r, data_row
    assert r.full_description==data_row[cols.index("FULL_DESC")]
    assert r.special_rates==data_row[cols.index("SPC_RATES")]
    assert r.unit_of_measure==data_row[cols.index("UNITCODE")]
    assert r.general_rate==data_row[cols.index("GENERAL")]
    assert r.chapter==data_row[cols.index("CHAPTER")]
    assert r.heading==data_row[cols.index("HEADING")]
    assert r.sub_heading==data_row[cols.index("SUBHEADING")]
    assert r.remaining_description==data_row[cols.index("REST_DESC")]
    assert r.add_valorem_rate==data_row[cols.index("ADDVALOREMRATE")]
    assert r.per_unit_rate==data_row[cols.index("PERUNIT")]
    assert r.most_favored_nation_rate==data_row[cols.index("MFN")]
    assert r.general_preferential_tariff_rate==data_row[cols.index("GPT")]
    assert r.erga_omnes_rate==data_row[cols.index("ERGA_OMNES")]
    assert r.column_2_rate==data_row[cols.index("COL2_RATE")]
    assert r.import_regulations == "#{data_row[cols.index("Import Reg 1")]} #{data_row[cols.index("Import Reg 2")]} #{data_row[cols.index("Import Reg 3")]} #{data_row[cols.index("Import Reg 4")]}"
    assert r.export_regulations == "#{data_row[cols.index("Export Reg 1")]} #{data_row[cols.index("Export Reg 2")]} #{data_row[cols.index("Export Reg 3")]} #{data_row[cols.index("Export Reg 4")]}"
  end

  test "general" do
    # Tests that we're processing a standard tariff file from the local filesystem and activating it
    rows = []
    t = create_tariff_file true, '', 0, cols, 2 do |row| 
      rows << row
      row
    end

    label = "ABCDEF"
    country = Country.where(:iso_code=>'US').first
    loader = TariffLoader.new(country,t.path,label)
    
    loader.process

    ts = TariffSet.where(:label=>label).first
    assert_equal label, ts.label
    assert_equal country, ts.country
    assert_equal 2, ts.tariff_set_records.size
    result1 = ts.tariff_set_records.where(:country_id=>country.id,:hts_code=>rows[0][cols.index("HSCODE")]).first
    result2 = ts.tariff_set_records.where(:country_id=>country.id,:hts_code=>rows[1][cols.index("HSCODE")]).first
    validate_hts_data cols, result1, rows[0]
    validate_hts_data cols, result2, rows[1]
  end

  test "headers not at beginning of file" do 
    # Tests that we skip all file lines that appear prior to the actual column headers
    t = create_tariff_file true, '', 2, cols, 2

    label = "with blank rows"
    country = Country.where(:iso_code=>'US').first
    TariffLoader.new(country, t.path, label).process

    ts = TariffSet.where(:label=>label).first
    assert_equal 2, ts.tariff_set_records.size
  end

  test 'process csv file with headers not at the beginning of the file' do
    rows = []
    t = create_tariff_file false, '', 2, cols, 2 do |row|
      rows << row
      row
    end

    label = "csv with blank rows"
    country = Country.where(:iso_code=>'US').first
    TariffLoader.new(country, t.path, label).process

    ts = TariffSet.where(:label=>label).first
    assert_equal 2, ts.tariff_set_records.size
    result1 = ts.tariff_set_records.where(:country_id=>country.id,:hts_code=>rows[0][cols.index("HSCODE")]).first
    result2 = ts.tariff_set_records.where(:country_id=>country.id,:hts_code=>rows[1][cols.index("HSCODE")]).first
    validate_hts_data cols, result1, rows[0]
    validate_hts_data cols, result2, rows[1]
  end

  test 'excel file with blank line between data fields and after data' do
    rows = []
    # Create a worksheet with a blank line between the two data rows and one after the data rows
    t = create_tariff_file true, '', 1, cols, 4 do |row, row_number|
      rows << row if row_number % 2 == 0
      row_number % 2 == 0 ? row : [' ', '    ', '']
    end

    label = 'excel with blanks'
    country = Country.where(:iso_code=>'US').first
    TariffLoader.new(country, t.path, label).process

    ts = TariffSet.where(:label=> label).first
    assert_equal 2, ts.tariff_set_records.size
    result1 = ts.tariff_set_records.where(:country_id=>country.id,:hts_code=>rows[0][cols.index("HSCODE")]).first
    result2 = ts.tariff_set_records.where(:country_id=>country.id,:hts_code=>rows[1][cols.index("HSCODE")]).first
    validate_hts_data cols, result1, rows[0]
    validate_hts_data cols, result2, rows[1]
  end

  test 'csv file with blank line between data fields and after data' do
    rows = []
    # Create a worksheet with a blank line between the two data rows and one after the data rows
    t = create_tariff_file false, '', 1, cols, 4 do |row, row_number|
      rows << row if row_number % 2 == 0
      row_number % 2 == 0 ? row : [' ', '    ', '']
    end

    label = 'excel with blanks'
    country = Country.where(:iso_code=>'US').first
    TariffLoader.new(country, t.path, label).process

    ts = TariffSet.where(:label=> label).first
    assert_equal 2, ts.tariff_set_records.size
    result1 = ts.tariff_set_records.where(:country_id=>country.id,:hts_code=>rows[0][cols.index("HSCODE")]).first
    result2 = ts.tariff_set_records.where(:country_id=>country.id,:hts_code=>rows[1][cols.index("HSCODE")]).first
    validate_hts_data cols, result1, rows[0]
    validate_hts_data cols, result2, rows[1]
    
  end

  test 'unzips and processes zip files with tariff sets in them' do
    t = create_tariff_file true, '', 2, cols, 2

    # Zip the file, ideally I'd have created a tempfile and then written the
    # zip output into it, but the zip create failed whenever I tried that due
    # to the file already existing.  Rather than overwriting, it just failed.
    # So, I just rolled my own temp file here.
  
    zip_path = File.dirname(t) + "/zip-" + File.basename(t.path) + ".zip"
    begin

      tz = Zip::ZipFile.open(zip_path, Zip::ZipFile::CREATE) do |zf|
        zf.add(File.basename(t.path), t.path)
      end

      label = "with blank rows"
      country = Country.where(:iso_code=>'US').first
      TariffLoader.new(country, zip_path, label).process
      ts = TariffSet.where(:label=>label).first
      assert_equal 2, ts.tariff_set_records.size
    ensure
      File.delete(zip_path) if File.file?(zip_path)  
    end 
  end

  test 'raises an error if no headers are found in an excel file' do
    t = Tempfile.new ['test', '.xls']
    
    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet
    sheet.row(5).replace %w{"this is a test row"}
    sheet.row(7).replace %w{"this is a second test row"}

    wb.write t.path

    label = "test no headers"
    country = Country.where(:iso_code=>'US').first
    ex = assert_raise(RuntimeError) { 
      TariffLoader.new(country, t.path, label).process
    }
    assert_equal("No header row found in spreadsheet #{File.basename(t)}.", ex.message)

  end

  test 'raises an error if no headers are found in a csv file' do
    t = Tempfile.new ['test', '.txt']
    
    CSV.open(t.path, "wb") do |csv|
      csv << ['', '']
      csv << %w{"this is a test row"}
      csv << %w{"this is a test row"}
    end

    label = "test no headers"
    country = Country.where(:iso_code=>'US').first
    ex = assert_raise(RuntimeError) { 
      TariffLoader.new(country, t.path, label).process
    }
    assert_equal("No header row found in file #{File.basename(t)}.", ex.message)
  end

end
