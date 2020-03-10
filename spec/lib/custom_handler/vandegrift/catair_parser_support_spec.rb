describe OpenChain::CustomHandler::Vandegrift::CatairParserSupport do

  subject { 
    Class.new {
      include OpenChain::CustomHandler::Vandegrift::CatairParserSupport

      def inbound_file
        nil
      end
    }.new
  }

  describe "record_type" do
    ["A", "B", "Y", "Z"].each do |record_type|
      it "identifies single character record type '#{record_type}'" do
        expect(subject.record_type "#{record_type}BCDEFG").to eq record_type
      end
    end

    it "identifies other record types" do
      expect(subject.record_type "XX10123457890712309").to eq "XX10"
    end

    it "identifies numeric only record types" do
      expect(subject.record_type "1010").to eq "10"
    end
  end

  describe "extract_string" do

    it "extracts a string from another string using given range - adjusted to match Catair indices" do
      expect(subject.extract_string("ABCDEFGHIJK", (5..7))).to eq "EFG"
    end

    it "extracts a character from another string using index - adjusted to match Catair index" do
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
      expect(subject.extract_date("AB020320C", (3..9))).to eq Date.new(2020, 2, 3)
    end

    it "extracts date value from string using alternate format" do
      expect(subject.extract_date("AB20200203C", (3..11), date_format: "%Y%m%d")).to eq Date.new(2020, 2, 3)
    end

    it "returns nil for invalid dates" do
      expect(subject.extract_date("ABCDEFGHIJK", (3..9))).to eq nil
    end
  end

  describe "extract_decimal" do
    it "extracts a decimal value from string" do
      expect(subject.extract_decimal("   12345   ", (2..8))).to eq BigDecimal("123.45")
    end

    it "extracts decimal value from string with leaing zeros" do
      expect(subject.extract_decimal("00012345   ", (2..8))).to eq BigDecimal("123.45")
    end

    it "allows for different decimal place values" do
      expect(subject.extract_decimal("   12345   ", (2..8), decimal_places: 4)).to eq BigDecimal("1.2345")
    end
  end

  describe "find_customer_number" do
    let! (:importer) { with_customs_management_id(Factory(:importer, irs_number: "XX-XXXXXXX"), "CMUS")}
    let! (:inbound_file) { 
      i = InboundFile.new
      allow(subject).to receive(:inbound_file).and_return i
      i
    }

    it "finds importer with given IRS number and CMUS customer number" do
      expect(subject.find_customer_number "EI", "XX-XXXXXXX").to eq "CMUS"
    end

    it "logs and raises an error if non-EI CATAIR Importer identifier types are utilized" do
      expect { subject.find_customer_number "XX", nil}.to raise_error "Importer Record Types of 'XX' are not supported at this time."
      expect(inbound_file).to have_reject_message("Importer Record Types of 'XX' are not supported at this time.")
    end

    it "logs and raises an error if no Importer is found with the given EIN #" do 
      expect { subject.find_customer_number "EI", "YY-YYYYYYY"}.to raise_error "Failed to find any importer account associated with EIN # 'YY-YYYYYYY' that has a CMUS Customer Number."
      expect(inbound_file).to have_reject_message("Failed to find any importer account associated with EIN # 'YY-YYYYYYY' that has a CMUS Customer Number.")
    end

    it "logs and raises an error if Importer found does not have a CMUS number" do
      importer.system_identifiers.delete_all

      expect { subject.find_customer_number "EI", "XX-XXXXXXX"}.to raise_error "Failed to find any importer account associated with EIN # 'XX-XXXXXXX' that has a CMUS Customer Number."
      expect(inbound_file).to have_reject_message("Failed to find any importer account associated with EIN # 'XX-XXXXXXX' that has a CMUS Customer Number.")
    end    
  end

  describe "gpg_secrets_key" do
    it "uses open_chain secrets key" do
      expect(subject.class.gpg_secrets_key({})).to eq "open_chain"
    end
  end
end