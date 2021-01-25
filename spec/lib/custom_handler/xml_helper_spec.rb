describe OpenChain::CustomHandler::XmlHelper do

  subject do
    Class.new do
      include OpenChain::CustomHandler::XmlHelper
    end.new
  end

  describe "est_time_str" do
    it "formats time to eastern" do
      t = ActiveSupport::TimeZone["GMT"].parse("2019-04-23 15:09:42")
      expect(subject.est_time_str(t)).to eq "2019-04-23 11:09 EDT"
    end
  end

  describe "et" do
    let (:upper_element) { REXML::Document.new("<upper><lower>val</lower></upper>").root }

    it "returns the child text" do
      expect(subject.et(upper_element, "lower")).to eq "val"
    end

    it "returns nil for no matching child" do
      expect(subject.et(upper_element, "lurwer")).to be_nil
    end

    it "returns empty string for no matching child when configured" do
      expect(subject.et(upper_element, "lurwer", true)).to eq ""
    end

    it "returns nil if element is nil" do
      expect(subject.et(nil, "doesnt_matter")).to be_nil
    end
  end

  describe "first_text" do
    let (:xml) { REXML::Document.new("<upper><middle><lower>val</lower><lower>val2</lower></middle></upper>") }

    it "returns the first matching text" do
      expect(subject.first_text(xml, "upper/middle/lower")).to eq "val"
    end

    it "returns nil for no xpath match" do
      expect(subject.first_text(xml, "upper/middle/lurwer")).to be_nil
    end

    it "returns empty string for no xpath match when configured" do
      expect(subject.first_text(xml, "upper/middle/lurwer", true)).to eq ""
    end
  end

  describe "unique_values" do
    let (:xml) { REXML::Document.new("<upper><lower>B</lower><lower>A</lower><lower>   </lower><lower>B</lower><lower>a</lower></upper>") }

    it "gets unique values" do
      expect(subject.unique_values(xml, "upper/lower")).to eq ["B", "A", "a"]
    end

    it "returns empty array for no xpath match" do
      expect(subject.unique_values(xml, "upper/lurwer")).to eq []
    end

    it "returns empty string in results when configured" do
      expect(subject.unique_values(xml, "upper/lower", skip_blank_values: false)).to eq ["B", "A", "   ", "a"]
    end

    it "returns results as CSV when configured" do
      expect(subject.unique_values(xml, "upper/lower", as_csv: true)).to eq "B,A,a"
    end

    it "returns results as CSV, including empty string, when configured" do
      expect(subject.unique_values(xml, "upper/lower", skip_blank_values: false, as_csv: true)).to eq "B,A,   ,a"
    end

    it "returns results as CSV using alternate separator" do
      expect(subject.unique_values(xml, "upper/lower", as_csv: true, csv_separator: "|")).to eq "B|A|a"
    end
  end

  describe "total_value" do
    let (:xml) { REXML::Document.new("<upper><lower>1.5</lower><lower>2.25</lower><empty/></upper>") }

    it "totals amount with default decimal type" do
      expect(subject.total_value(xml, "upper/lower")).to eq BigDecimal("3.75")
    end

    it "returns zero for no xpath match" do
      expect(subject.total_value(xml, "upper/lurwer")).to eq BigDecimal(0)
    end

    it "returns zero for an empty element" do
      expect(subject.total_value(xml, "upper/empty")).to eq BigDecimal(0)
    end

    it "totals amount with integer type" do
      expect(subject.total_value(xml, "upper/lower", total_type: :to_i)).to eq 3
    end
  end

  describe "xml_document" do
    it "builds an xml document from a String" do
      doc = subject.xml_document("<xml><child>Value</child></xml>")
      expect(doc.root.name).to eq "xml"
    end

    it "handles xml documents with duplicate root elements" do
      doc = subject.xml_document("<xml><child>Value</child></xml><xml><child>Value2</child></xml>")
      expect(doc.root.name).to eq "xml"
      expect(doc.root.text("child")).to eq "Value"
    end

    it "raises REXML::ParseException when bad XML and including class doesn't include InboundFile" do
      expect { subject.xml_document("<xml><child>Value</child></") }.to raise_error REXML::ParseException
    end

    it "raises a LoggedParserRejectionError when bad XML and includes InboundFile " do
      parser = Class.new do
        include OpenChain::CustomHandler::XmlHelper
        include OpenChain::IntegrationClientParser
      end

      expect(parser).to receive(:inbound_file).and_return InboundFile.new

      expect { parser.xml_document("<xml><child>Value</child></") }.to raise_error LoggedParserRejectionError
    end
  end
end
