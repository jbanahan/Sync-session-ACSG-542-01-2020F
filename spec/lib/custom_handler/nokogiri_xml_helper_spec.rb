describe OpenChain::CustomHandler::NokogiriXmlHelper do

  def base_object
    k = Class.new do
      include OpenChain::CustomHandler::NokogiriXmlHelper
    end
    k.new
  end

  describe "est_time_str" do
    it "formats time to eastern" do
      t = ActiveSupport::TimeZone["GMT"].parse("2019-04-23 15:09:42")
      expect(base_object.est_time_str t).to eq "2019-04-23 11:09 EDT"
    end
  end

  describe "et" do
    let (:upper_element) { Nokogiri::XML("<upper><middle><lower>wrong val</lower></middle><lower>val</lower></upper>").root }

    it "returns the child text" do
      expect(base_object.et upper_element, "lower").to eq "val"
    end

    it "returns nil for no matching child" do
      expect(base_object.et upper_element, "lurwer").to be_nil
    end

    it "returns empty string for no matching child when configured" do
      expect(base_object.et upper_element, "lurwer", true).to eq ""
    end

    it "returns nil if element is nil" do
      expect(base_object.et nil, "doesnt_matter").to be_nil
    end
  end

  describe "first_text" do
    let (:xml) { Nokogiri::XML("<upper><middle><lower>val</lower><lower>val2</lower></middle></upper>") }

    it "returns the first matching text" do
      expect(base_object.first_text xml, "upper/middle/lower").to eq "val"
    end

    # This will fail if the 'at' method is involved, because it is evidently not doing full xpath evaluation.
    it "returns the first matching text involving parameters" do
      xml = Nokogiri::XML("<outer><inner><key>Greeting</key><value>Hello</value></inner><inner><key>Dismissal</key><value>Take off!</value></inner></outer>")

      expect(base_object.first_text xml, "outer/inner[key='Dismissal']/value").to eq "Take off!"
    end

    it "returns nil for no xpath match" do
      expect(base_object.first_text xml, "upper/middle/lurwer").to be_nil
    end

    it "returns empty string for no xpath match when configured" do
      expect(base_object.first_text xml, "upper/middle/lurwer", true).to eq ""
    end
  end

  describe "unique_values" do
    let (:xml) { Nokogiri::XML("<upper><lower>B</lower><lower>A</lower><lower>   </lower><lower>B</lower><lower>a</lower></upper>") }

    it "gets unique values" do
      expect(base_object.unique_values xml, "upper/lower").to eq ["B","A","a"]
    end

    it "returns empty array for no xpath match" do
      expect(base_object.unique_values xml, "upper/lurwer").to eq []
    end

    it "returns empty string in results when configured" do
      expect(base_object.unique_values xml, "upper/lower", skip_blank_values:false).to eq ["B","A","   ","a"]
    end

    it "returns results as CSV when configured" do
      expect(base_object.unique_values xml, "upper/lower", as_csv:true).to eq "B,A,a"
    end

    it "returns results as CSV, including empty string, when configured" do
      expect(base_object.unique_values xml, "upper/lower", skip_blank_values:false, as_csv:true).to eq "B,A,   ,a"
    end

    it "returns results as CSV using alternate separator" do
      expect(base_object.unique_values xml, "upper/lower", as_csv:true, csv_separator:"|").to eq "B|A|a"
    end
  end

  describe "total_value" do
    let (:xml) { Nokogiri::XML("<upper><lower>1.5</lower><lower>2.25</lower><empty/></upper>") }

    it "totals amount with default decimal type" do
      expect(base_object.total_value xml, "upper/lower").to eq BigDecimal.new("3.75")
    end

    it "returns zero for no xpath match" do
      expect(base_object.total_value xml, "upper/lurwer").to eq BigDecimal.new(0)
    end

    it "returns zero for an empty element" do
      expect(base_object.total_value xml, "upper/empty").to eq BigDecimal.new(0)
    end

    it "totals amount with integer type" do
      expect(base_object.total_value xml, "upper/lower", total_type: :to_i).to eq 3
    end
  end
end