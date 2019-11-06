describe OpenChain::CustomHandler::NokogiriXmlHelper do

  subject { 
    Class.new do
      include OpenChain::CustomHandler::NokogiriXmlHelper
    end.new
  }
  
  describe "est_time_str" do
    it "formats time to eastern" do
      t = ActiveSupport::TimeZone["GMT"].parse("2019-04-23 15:09:42")
      expect(subject.est_time_str t).to eq "2019-04-23 11:09 EDT"
    end
  end

  describe "et" do
    let (:upper_element) { Nokogiri::XML("<upper><middle><lower>wrong val</lower></middle><lower>val</lower></upper>").root }

    it "returns the child text" do
      expect(subject.et upper_element, "lower").to eq "val"
    end

    it "returns nil for no matching child" do
      expect(subject.et upper_element, "lurwer").to be_nil
    end

    it "returns empty string for no matching child when configured" do
      expect(subject.et upper_element, "lurwer", true).to eq ""
    end

    it "returns nil if element is nil" do
      expect(subject.et nil, "doesnt_matter").to be_nil
    end
  end

  describe "first_text" do
    let (:xml) { Nokogiri::XML("<upper><middle><lower>val</lower><lower>val2</lower></middle></upper>") }

    it "returns the first matching text" do
      expect(subject.first_text xml, "upper/middle/lower").to eq "val"
    end

    # This will fail if the 'at' method is involved, because it is evidently not doing full xpath evaluation.
    it "returns the first matching text involving parameters" do
      xml = Nokogiri::XML("<outer><inner><key>Greeting</key><value>Hello</value></inner><inner><key>Dismissal</key><value>Take off!</value></inner></outer>")

      expect(subject.first_text xml, "outer/inner[key='Dismissal']/value").to eq "Take off!"
    end

    it "returns nil for no xpath match" do
      expect(subject.first_text xml, "upper/middle/lurwer").to be_nil
    end

    it "returns empty string for no xpath match when configured" do
      expect(subject.first_text xml, "upper/middle/lurwer", true).to eq ""
    end
  end

  describe "unique_values" do
    let (:xml) { Nokogiri::XML("<upper><lower>B</lower><lower>A</lower><lower>   </lower><lower>B</lower><lower>a</lower></upper>") }

    it "gets unique values" do
      expect(subject.unique_values xml, "upper/lower").to eq ["B","A","a"]
    end

    it "returns empty array for no xpath match" do
      expect(subject.unique_values xml, "upper/lurwer").to eq []
    end

    it "returns empty string in results when configured" do
      expect(subject.unique_values xml, "upper/lower", skip_blank_values:false).to eq ["B","A","   ","a"]
    end

    it "returns results as CSV when configured" do
      expect(subject.unique_values xml, "upper/lower", as_csv:true).to eq "B,A,a"
    end

    it "returns results as CSV, including empty string, when configured" do
      expect(subject.unique_values xml, "upper/lower", skip_blank_values:false, as_csv:true).to eq "B,A,   ,a"
    end

    it "returns results as CSV using alternate separator" do
      expect(subject.unique_values xml, "upper/lower", as_csv:true, csv_separator:"|").to eq "B|A|a"
    end
  end

  describe "total_value" do
    let (:xml) { Nokogiri::XML("<upper><lower>1.5</lower><lower>2.25</lower><empty/></upper>") }

    it "totals amount with default decimal type" do
      expect(subject.total_value xml, "upper/lower").to eq BigDecimal.new("3.75")
    end

    it "returns zero for no xpath match" do
      expect(subject.total_value xml, "upper/lurwer").to eq BigDecimal.new(0)
    end

    it "returns zero for an empty element" do
      expect(subject.total_value xml, "upper/empty").to eq BigDecimal.new(0)
    end

    it "totals amount with integer type" do
      expect(subject.total_value xml, "upper/lower", total_type: :to_i).to eq 3
    end
  end

  describe "xml_document" do
    it "builds a Nokogiri::XML object" do
      doc = subject.xml_document("<document><child>Value</child></document>")
      expect(doc).to be_instance_of Nokogiri::XML::Document
      expect(doc.root.name).to eq "document"
    end

    it "strips namespaces by default" do
      doc = subject.xml_document("<document xmlns='http://www.namespace.com/namespace'><child>Value</child></document>")
      expect(doc.namespaces).to be_blank
    end

    it "does not strip namespaces if instructed" do
      doc = subject.xml_document("<document xmlns='http://www.namespace.com/namespace'><child>Value</child></document>", remove_namespaces: false)
      expect(doc.namespaces).to eq({"xmlns" => "http://www.namespace.com/namespace"})
    end
  end

  describe "xpath" do
    let (:element) { subject.xml_document("<document><child>Value1</child><child>Value2</child></document>").root }
    let (:namespaced_element) { subject.xml_document("<document xmlns='http://www.namespace.com/namespace'><child test='testing'>Value1</child><child>Value2</child></document>", remove_namespaces: false)}

    it "returns all matched xpath elements" do
      children = subject.xpath(element, "/document/child")
      expect(children).to be_instance_of(Array)

      expect(children.length).to eq 2
      child = children.first

      expect(child).to be_instance_of(Nokogiri::XML::Element)
      expect(child.text).to eq "Value1"

      child = children.second

      expect(child).to be_instance_of(Nokogiri::XML::Element)
      expect(child.text).to eq "Value2"
    end

    it "yields each xpath result" do
      children = []
      subject.xpath(element, "/document/child") do |element|
        children << element
      end

      expect(children.length).to eq 2
      child = children.first

      expect(child).to be_instance_of(Nokogiri::XML::Element)
      expect(child.text).to eq "Value1"

      child = children.second

      expect(child).to be_instance_of(Nokogiri::XML::Element)
      expect(child.text).to eq "Value2"
    end

    it "utilizes namespace bindings" do
      children = subject.xpath(namespaced_element, "/ns:document/ns:child", namespace_bindings: {"ns" => "http://www.namespace.com/namespace"})
      expect(children.length).to eq 2
    end

    it "utilizes variable bindings" do
      children = subject.xpath(namespaced_element, "//ns:child[@test=$var]", namespace_bindings: {"ns" => "http://www.namespace.com/namespace"}, variable_bindings: {var: "testing"})
      expect(children.length).to eq 1
    end
  end
end