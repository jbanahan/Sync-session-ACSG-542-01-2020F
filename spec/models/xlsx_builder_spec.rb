describe XlsxBuilder do

  def reader
    @reader ||= begin
      io = StringIO.new
      subject.write io
      io.rewind

      XlsxTestReader.new io
    end

    @reader
  end

  def header_format? sheet, row, column
    cell = reader.cell(sheet, row, column)
    cell.try(:fill_color) == "FF62BCF3"
  end

  describe "create_sheet" do
    it "creates a new worksheet" do 
      sheet = subject.create_sheet "Test"
      expect(sheet).to be_a XlsxBuilder::XlsxSheet
      expect(sheet.name).to eq "Test"
      expect(sheet.raw_sheet).to be_a Axlsx::Worksheet
    end

    it "handles sheet names longer than 31 characters" do
      sheet = subject.create_sheet "Unmatched 03-23-19 thru 06-21-19"
      expect(sheet).to be_a XlsxBuilder::XlsxSheet
      expect(sheet.name).to eq "Unmatched 03-23-19 thru 06-2..."
      expect(sheet.raw_sheet).to be_a Axlsx::Worksheet
    end

    it "creates a new worksheet with headers" do
      sheet = subject.create_sheet "Test", headers: ["Testing"]
      expect(reader.raw_data(sheet)[0]).to eq ["Testing"]
      # Make sure the header format was applied
      expect(header_format? sheet, 0, 0).to eq true
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

      expect(reader.raw_data(sheet)).to eq [["Test"], ["Test2"]]
    end

    it "calculates default widths" do
      subject.add_body_row sheet, ["This is a test column", Date.new(2018, 7, 16), DateTime.new(2018, 7, 16, 12, 25, 30), DateTime.new(2018, 7, 17, 12, 25, 30)], styles: [nil, nil, nil, :default_date]
      # The column widths are generated by axlsx automatically.
      expect(reader.width_at(sheet, 0)).to eq 14
      expect(reader.width_at(sheet, 1)).to eq 11
      expect(reader.width_at(sheet, 2)).to eq 17
      expect(reader.width_at(sheet, 3)).to eq 17
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
        expect(reader.number_format(sheet, 0, 0)).to eq "YYYY-MM-DD"
      end

      it "allows using default_date style directly" do
        subject.add_body_row sheet, [Date.new(2018, 7, 13)], styles: [:default_date]
        expect(reader.number_format(sheet, 0, 0)).to eq "YYYY-MM-DD"
      end

      it "applies default styles to DateTime" do
        subject.add_body_row sheet, [DateTime.new(2018, 7, 13, 12, 23, 30)]
        expect(reader.number_format(sheet, 0, 0)).to eq "YYYY-MM-DD HH:MM"
      end

      it "allows using default_datetime style directly" do
        subject.add_body_row sheet, [DateTime.new(2018, 7, 13, 12, 23, 30)], styles: [:default_datetime]
        expect(reader.number_format(sheet, 0, 0)).to eq "YYYY-MM-DD HH:MM"
      end

      it "applies default style to ActiveSupport::TimeWithZone" do 
        subject.add_body_row sheet, [Time.zone.parse("2018-07-13 12:23")]
        expect(reader.number_format(sheet, 0, 0)).to eq "YYYY-MM-DD HH:MM"
      end

      it "handles mixed default and parameter styles" do
        subject.add_body_row sheet, [DateTime.new(2018, 7, 13, 12, 23, 30), Date.new(2018, 7, 13)], styles: [:default_date, nil]
        expect(reader.number_format(sheet, 0, 0)).to eq "YYYY-MM-DD"
        expect(reader.number_format(sheet, 0, 1)).to eq "YYYY-MM-DD"
      end

      it "allows using default currency style directly" do
        subject.add_body_row sheet, [BigDecimal("1.23")], styles: [:default_currency]
        expect(reader.number_format(sheet, 0, 0)).to eq "#,##0.00"
      end
    end

    context "merged ranges" do
      it "applies merged range, if specified" do
        subject.add_body_row sheet, ["Nigel", "Tufnel", "was", "here!"], merged_cell_ranges: [(0..1),(2..3)]
        expect(reader.merged_cell_ranges(sheet)).to eq([{row: 0, cols: (0..1)}, {row: 0, cols: (2..3)}])
      end
    end

    it "forces strings that might use numeric constant 'e' as strings" do
      vals = ["1e2", "624e1", "e", "1e", "1e12345"]
      subject.add_body_row sheet, vals

      expect(reader.raw_data(sheet)).to eq [vals]
    end
  end

  describe "add_header_row" do
    let (:sheet) {
      s = subject.create_sheet "Test"
    }

    it "adds a header row" do
      expect(subject.add_header_row sheet, ["Header"]).to be_nil
      expect(reader.raw_data(sheet)).to eq [["Header"]]
      expect(header_format? sheet, 0, 0).to eq true
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

      RubyXL::Parser.parse_buffer io
    end

    it "writes data to given file path" do
      Tempfile.open(["test", ".xlsx"]) do |file|
        subject.write file.path

        file.rewind
        # If this method passes without raising, then we're ok..it means the workbook was written to the
        # IO object and could be read
        RubyXL::Parser.parse file
      end
    end
  end

  describe "create_style" do 
    let (:sheet) {
      subject.create_sheet "Sheet"
    }

    it "creates a new style" do
      style = subject.create_style "test", {bg_color: "123456"}
      # use the style to make sure it is applied
      subject.add_body_row sheet, ["Test"], styles: [style]
      expect(reader.background_color(sheet, 0, 0)).to eq "FF123456"
    end
  end

  describe "create_link_cell" do
    let (:sheet) {
      subject.create_sheet "Sheet"
    }

    it "creates a link cell" do 
      link = subject.create_link_cell "www.google.com"
      expect(link[:type]).to eq :hyperlink
      expect(link[:location]).to eq "www.google.com"
      expect(link[:link_text]).to eq "Web View"
    end

    it "allows using different text" do
      link = subject.create_link_cell "www.google.com", link_text: "Google"
      expect(link[:link_text]).to eq "Google"
    end

    it "can be passed to add body row" do
      link = subject.create_link_cell "www.google.com"
      subject.add_body_row sheet, [link]
      expect(reader.raw_data sheet).to eq [["Web View"]]
    end
  end

  describe "freeze_horizontal_rows" do
    let (:sheet) {
      subject.create_sheet "Sheet", headers: ["Header"]
    }

    it "freezes sheet at given row" do
      subject.freeze_horizontal_rows sheet, 1
      
      reader.sheet(sheet) do |s|
        pane = s.sheet_views.first.pane
        expect(pane).not_to be_nil
        expect(pane.x_split).to eq 0
        expect(pane.y_split).to eq 1
        expect(pane.active_pane).to eq "bottomLeft"
        expect(pane.state).to eq "frozen"
      end
    end
  end

  describe "set_column_widths" do
    let (:sheet) {
      subject.create_sheet "Sheet", headers: ["Header", "Header 2", "Header 3"]
    }

    it "sets column widths given" do
      subject.set_column_widths sheet, 100, nil, 200

      expect(reader.width_at(sheet, 0)).to eq 100
      # By using nil above, we skip setting this width so 11 is the default width
      expect(reader.width_at(sheet, 1)).to eq 13.5
      expect(reader.width_at(sheet, 2)).to eq 200
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

      expect(reader.width_at(sheet, 0)).to eq 50
      expect(reader.width_at(sheet, 1)).to eq 8
      expect(reader.width_at(sheet, 2)).to eq 12
    end

    it "applies min/max widths using given values" do 
      subject.apply_min_max_width_to_columns sheet, min_width: 5, max_width: 10

      expect(reader.width_at(sheet, 0)).to eq 10
      expect(reader.width_at(sheet, 1)).to eq 5
      expect(reader.width_at(sheet, 2)).to eq 10
    end
  end

  describe "add_image" do
    let (:sheet) {
      sheet = subject.create_sheet "Sheet", headers: ["Header", "Header 2", "Header 3"]
      subject.set_column_widths sheet, 100, 1, 12

      sheet
    }

    it "assigns properties to image" do
      subject.add_image sheet, "spec/fixtures/files/attorney.png", 375, 360, 1, 0, hyperlink: "https://en.wikipedia.org/wiki/Better_Call_Saul", opts: { name: "Saul" }
      
      anchor = sheet.raw_sheet.drawing.anchors.last
      
      marker = anchor.from
      expect(marker.col).to eq 1
      expect(marker.row).to eq 0 
      
      pic = anchor.object
      expect(pic.name).to eq "Saul"
      expect(pic.image_src).to eq "spec/fixtures/files/attorney.png"
      expect(pic.hyperlink.href).to eq "https://en.wikipedia.org/wiki/Better_Call_Saul"
      expect(pic.width).to eq 375
      expect(pic.height).to eq 360
    end

  end

  describe "set_page_setup" do
    let (:sheet) {
      subject.create_sheet "Sheet", headers: ["Header", "Header 2", "Header 3"]
    }

    it "assigns setup values" do
      subject.set_page_setup sheet, orientation: :landscape, fit_to_width_pages: 10, fit_to_height_pages: 5, margins: {top: 1, bottom: 2, left: 3, right: 4}
      r = sheet.raw_sheet
      expect(r.page_setup.orientation).to eq :landscape
      expect(r.page_setup.fit_to_width).to eq 10
      expect(r.page_setup.fit_to_height).to eq 5
      expect(r.page_margins.top).to eq 1
      expect(r.page_margins.bottom).to eq 2
      expect(r.page_margins.left).to eq 3
      expect(r.page_margins.right).to eq 4
    end

    it "handles blank named params" do
      subject.set_page_setup sheet

      r = sheet.raw_sheet
      expect(r.page_setup.orientation).to be_nil
      expect(r.page_setup.fit_to_width).to be_nil
      expect(r.page_setup.fit_to_height).to be_nil
      expect(r.page_margins.top).to eq 1
      expect(r.page_margins.bottom).to eq 1
      expect(r.page_margins.left).to eq 0.75
      expect(r.page_margins.right).to eq 0.75
    end
  end

  describe "set_header_foot" do
    let (:sheet) {
      subject.create_sheet "Sheet", headers: ["Header", "Header 2", "Header 3"]
    }

    it "sets header and footer data" do
      subject.set_header_footer sheet, header: "HEADER", footer: "FOOTER"

      r = sheet.raw_sheet
      expect(r.header_footer.odd_header).to eq "HEADER"
      expect(r.header_footer.odd_footer).to eq "FOOTER"
    end
  end

  describe "alphabet_column_to_numeric_column" do
    subject { described_class }

    it "should return the correct values for Excel column headings" do
      expect(subject.alphabet_column_to_numeric_column("A")).to eq(0)
      expect(subject.alphabet_column_to_numeric_column("Z")).to eq(25)
      expect(subject.alphabet_column_to_numeric_column("AA")).to eq(26)
      expect(subject.alphabet_column_to_numeric_column("AZ")).to eq(51)
      expect(subject.alphabet_column_to_numeric_column("ZZZ")).to eq(18277)
    end
  end

  describe "numeric_column_to_alphabetic_column" do
    subject { described_class }

    it "should return the correct values for Excel column headings" do
      expect(subject.numeric_column_to_alphabetic_column(0)).to eq("A")
      expect(subject.numeric_column_to_alphabetic_column(25)).to eq("Z")
      expect(subject.numeric_column_to_alphabetic_column(26)).to eq("AA")
      expect(subject.numeric_column_to_alphabetic_column(51)).to eq("AZ")
      expect(subject.numeric_column_to_alphabetic_column(18277)).to eq("ZZZ")
    end
  end
end
