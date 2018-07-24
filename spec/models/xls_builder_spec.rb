describe XlsBuilder do

  def raw_data sheet
    rows = []
    sheet.raw_sheet.each do |row|
      rows << row.to_a
    end
    rows
  end

  def format_at sheet, row, column
    sheet.raw_sheet.row(row).format(column)
  end

  describe "create_sheet" do
    it "creates a new worksheet" do 
      sheet = subject.create_sheet "Test"
      expect(sheet).to be_a XlsBuilder::XlsSheet
      expect(sheet.name).to eq "Test"
      expect(sheet.raw_sheet).to be_a Spreadsheet::Worksheet
    end

    it "creates a new worksheet with headers" do
      sheet = subject.create_sheet "Test", headers: ["Testing"]
      expect(sheet.raw_sheet.row(0).to_a).to eq ["Testing"]
      # Make sure the header format was applied
      expect(format_at(sheet, 0, 0).name).to eq "default_header"
    end
  end

  describe "add_body_row" do
    let (:sheet) {
      s = subject.create_sheet "Test"
    }

    it "adds new body rows" do
      # By adding two rows here we also test that an internal row counter is working
      expect(subject.add_body_row sheet, ["Test"]).to be_nil
      subject.add_body_row sheet, ["Test2"]

      expect(raw_data(sheet)).to eq [["Test"], ["Test2"]]
    end

    it "calculates default widths" do
      subject.add_body_row sheet, ["This is a test column", Date.new(2018, 7, 16), DateTime.new(2018, 7, 16, 12, 25, 30), DateTime.new(2018, 7, 17, 12, 25, 30)], styles: [nil, nil, nil, :default_date]
      # our string column width calculator is extremely basic, it's just the string size + 3 chars.
      expect(sheet.raw_sheet.column(0).width).to eq 24
      expect(sheet.raw_sheet.column(1).width).to eq 11
      expect(sheet.raw_sheet.column(2).width).to eq 16
      expect(sheet.raw_sheet.column(3).width).to eq 11
    end

    it "raises an error attempting to use a style that doesn't exist" do
      expect {subject.add_body_row sheet, ["Test"], styles: [:testing]}.to raise_error "No format named 'testing' has been created."
    end

    context "default styles" do
      let (:sheet) {
        s = subject.create_sheet "Test"
      }

      it "applies default styles to Date" do
        subject.add_body_row sheet, [Date.new(2018, 7, 13)]
        expect(format_at(sheet, 0, 0).name).to eq "default_date"
      end

      it "allows using default_date style directly" do
        subject.add_body_row sheet, [Date.new(2018, 7, 13)], styles: [:default_date]
        expect(format_at(sheet, 0, 0).name).to eq "default_date"
      end

      it "applies default styles to DateTime" do
        subject.add_body_row sheet, [DateTime.new(2018, 7, 13, 12, 23, 30)]
        expect(format_at(sheet, 0, 0).name).to eq "default_datetime"
      end

      it "allows using default_datetime style directly" do
        subject.add_body_row sheet, [DateTime.new(2018, 7, 13, 12, 23, 30)], styles: [:default_datetime]
        expect(format_at(sheet, 0, 0).name).to eq "default_datetime"
      end

      it "applies default style to ActiveSupport::TimeWithZone" do 
        subject.add_body_row sheet, [Time.zone.parse("2018-07-13 12:23")]
        expect(format_at(sheet, 0, 0).name).to eq "default_datetime"
      end

      it "handles mixed default and parameter styles" do
        subject.add_body_row sheet, [DateTime.new(2018, 7, 13, 12, 23, 30), Date.new(2018, 7, 13)], styles: [:default_date, nil]
        expect(format_at(sheet, 0, 0).name).to eq "default_date"
        expect(format_at(sheet, 0, 1).name).to eq "default_date"
      end

      it "allows using default currency style directly" do
        subject.add_body_row sheet, [BigDecimal("1.23")], styles: [:default_currency]
        expect(format_at(sheet, 0, 0).name).to eq "default_currency"
      end
    end
  end

  describe "add_header_row" do
    let (:sheet) {
      s = subject.create_sheet "Test"
    }

    it "adds a header row" do
      expect(subject.add_header_row sheet, ["Header"]).to be_nil
      expect(raw_data(sheet)).to eq [["Header"]]
      expect(format_at(sheet, 0, 0).name).to eq "default_header"
    end
  end

  describe "write" do
    let! (:sheet) { 
      subject.create_sheet "Sheet", headers: ["Testing"]
    }

    it "writes data to given IO object" do
      io = StringIO.new
      subject.write io
      io.rewind

      # If this method passes without raising, then we're ok..it means the workbook was written to the
      # IO object and could be read
      Spreadsheet.open(io)
    end

    it "writes data to given file path" do
      Tempfile.open(["test", ".xls"]) do |file|
        subject.write file.path

        file.rewind
        # If this method passes without raising, then we're ok..it means the workbook was written to the
        # IO object and could be read
        Spreadsheet.open(file) 
      end
    end
  end

  describe "create_style" do 
    let (:sheet) {
      subject.create_sheet "Sheet"
    }

    it "creates a new style" do
      style = subject.create_style "test", {color: :blue, weight: :bold}
      # use the style to make sure it is applied
      subject.add_body_row sheet, ["Test"], styles: [style]
      expect(format_at(sheet, 0, 0).name).to eq "test"
    end
  end

  describe "create_link_cell" do
    let (:sheet) {
      subject.create_sheet "Sheet"
    }

    it "creates a link cell" do 
      link = subject.create_link_cell "www.google.com"
      expect(link.url).to eq "www.google.com"
      expect(link).to eq "Web View"
    end

    it "allows using different text" do
      link = subject.create_link_cell "www.google.com", link_text: "Google"
      expect(link.url).to eq "www.google.com"
      expect(link).to eq "Google"
    end

    it "can be passed to add body row" do
      link = subject.create_link_cell "www.google.com"
      subject.add_body_row sheet, [link]
      expect(raw_data sheet).to eq [["Web View"]]
    end
  end

  describe "freeze_horizontal_rows" do
    let (:sheet) {
      subject.create_sheet "Sheet", headers: ["Header"]
    }

    it "freezes sheet at given row" do
      # no-ops due to Excel validation failures
      expect(subject.freeze_horizontal_rows sheet, 1).to be_nil
      expect(sheet.raw_sheet.froze_top).to eq 0
      expect(sheet.raw_sheet.froze_left).to eq 0
    end
  end

  describe "set_column_widths" do
    let (:sheet) {
      subject.create_sheet "Sheet", headers: ["Header", "Header 2", "Header 3"]
    }

    it "sets column widths given" do
      subject.set_column_widths sheet, 100, nil, 200

      expect(sheet.raw_sheet.column(0).width).to eq 100
      # By using nil above, we skip setting this width so 11 is the default width
      expect(sheet.raw_sheet.column(1).width).to eq 11
      expect(sheet.raw_sheet.column(2).width).to eq 200
    end
  end

  describe "apply_min_max_width_to_columns" do
    let (:sheet) {
      sheet = subject.create_sheet "Sheet", headers: ["Header", "Header 2", "Header 3"]
      subject.set_column_widths sheet, 100, 1, 12

      sheet
    }

    it "applies min/max widths using defaults" do 
      subject.apply_min_max_width_to_columns sheet

      expect(sheet.raw_sheet.column(0).width).to eq 50
      expect(sheet.raw_sheet.column(1).width).to eq 8
      expect(sheet.raw_sheet.column(2).width).to eq 12
    end

    it "applies min/max widths using given values" do 
      subject.apply_min_max_width_to_columns sheet, min_width: 5, max_width: 10

      expect(sheet.raw_sheet.column(0).width).to eq 10
      expect(sheet.raw_sheet.column(1).width).to eq 5
      expect(sheet.raw_sheet.column(2).width).to eq 10
    end
  end

end