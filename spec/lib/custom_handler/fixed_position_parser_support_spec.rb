describe OpenChain::CustomHandler::FixedPositionParserSupport do

  subject {
    Class.new {
      include OpenChain::CustomHandler::FixedPositionParserSupport
    }.new
  }

  describe "extract_string" do

    it "extracts a string from another string using 1-index based range" do
      expect(subject.extract_string("ABCDEFGHIJK", (5..7))).to eq "EFG"
    end

    it "extracts a character from another string using 1-index based number" do
      expect(subject.extract_string("ABCDEFGHIJK", 5)).to eq "E"
    end

    it "trims whitespace by default from ranges" do
      expect(subject.extract_string("A   B   CDEF", (2..8))).to eq "B"
    end

    it "does not trim whitespace if instructed" do
      expect(subject.extract_string("A   B   CDEF", (2..8), trim_whitespace: false)).to eq "   B   "
    end

    it "handles ranges going beyond end of the line" do
      expect(subject.extract_string("AB", (2..8))).to eq "B"
    end

    it "handles values extracted from line starting beyond end of the line" do
      expect(subject.extract_string("", (1..10))).to eq ""
    end
  end

  describe "extract_integer" do
    it "extracts integer value from string" do
      expect(subject.extract_integer("12345", (2..4))).to eq 234
    end

    it "returns nil when no integer value is found" do
      expect(subject.extract_integer("      ", (2..4))).to eq nil
    end

    it "handles invalid integer values by returning nil" do
      expect(subject.extract_integer("ABCD", (2..3))).to eq nil
    end

    it "handles leading zeros" do
      expect(subject.extract_integer("00011", (1..5))).to eq 11
    end
  end

  describe "extract_date" do
    it "extracts date value from string with default format" do
      expect(subject.extract_date("AB20200203C", (3..11))).to eq Date.new(2020, 2, 3)
    end

    it "extracts date value from string using alternate format" do
      expect(subject.extract_date("AB020320C", (3..9), date_format: "%m%d%y")).to eq Date.new(2020, 2, 3)
    end

    it "returns nil for invalid dates" do
      expect(subject.extract_date("ABCDEFGHIJK", (3..9))).to eq nil
    end
  end

  describe "extract_datetime" do
    it "extracts datetime value from string with default format" do
      expect(subject.extract_datetime("AB202003181230ZZZ", (3..14))).to eq Time.zone.parse("2020-03-18 12:30")
    end

    it "extracts datetime value from string using given timezone" do
      expect(subject.extract_datetime("AB202003181230ZZZ", (3..14), time_zone: "America/New_York")).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-18 12:30")
    end

    it "extracts datetime value from string using given format" do
      expect(subject.extract_datetime("AB2020-03-18 12:30ZZZ", (3..18), datetime_format: "%Y-%m-%d %H:%M", time_zone: "America/New_York")).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-18 12:30")
    end
  end

  describe "extract_decimal" do
    it "extracts a decimal value from string" do
      expect(subject.extract_decimal("   123.45   ", (2..9), decimal_places: 2)).to eq BigDecimal("123.45")
    end

    it "extracts decimal value from string with leaing zeros" do
      expect(subject.extract_decimal("000123.45   ", (2..9), decimal_places: 2)).to eq BigDecimal("123.45")
    end

    it "allows for different decimal place values" do
      expect(subject.extract_decimal("   1.2345   ", (2..9), decimal_places: 3)).to eq BigDecimal("1.235")
    end

    it "allows for alternate rounding modes" do
      expect(subject.extract_decimal("   1.239   ", (2..9), decimal_places: 2, rounding_mode: BigDecimal::ROUND_DOWN)).to eq BigDecimal("1.23")
    end
  end

  describe "extract_implied_decimal" do
    it "extracts a decimal value from string" do
      expect(subject.extract_implied_decimal("   12345   ", (2..8), decimal_places: 2)).to eq BigDecimal("123.45")
    end

    it "extracts decimal value from string with leaing zeros" do
      expect(subject.extract_implied_decimal("00012345   ", (2..8), decimal_places: 2)).to eq BigDecimal("123.45")
    end

    it "allows for different decimal place values" do
      expect(subject.extract_implied_decimal("   12345   ", (2..8), decimal_places: 4)).to eq BigDecimal("1.2345")
    end
  end

  describe "extract_boolean" do
    ["Y", "YES", "1", "TRUE", "T"].each do |val|
      it "returns true true from '#{val}' value in string" do
        expect(subject.extract_boolean "  #{val}   ", (1..20)).to eq true
      end
    end

    it "returns false for non-truthy values" do
      expect(subject.extract_boolean "0", 1).to eq false
    end

    it "allows defining custom set of truthy values" do
      # This also ensures upcase is utilized by default
      expect(subject.extract_boolean "Sí", (1..2), truthy_values: ["SÍ"]).to eq true
    end

    it "does not upcase extracted value if instructed not to" do
      expect(subject.extract_boolean "Sí", (1..2), truthy_values: ["SÍ"], upcase_values: false).to eq false
    end

    it "returns false if string is blank" do
      expect(subject.extract_boolean "   ", (1..2)).to eq false
    end

    it "returns nil if string is blank and blank_string_returns_nil is set to true" do
      expect(subject.extract_boolean "   ", (1..2), blank_string_returns_nil: true).to be_nil
    end

  end
end