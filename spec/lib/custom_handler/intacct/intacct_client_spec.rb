require 'spec_helper'
require 'open_chain/custom_handler/intacct/intacct_client'

describe OpenChain::CustomHandler::Intacct::IntacctClient do

  def create_error_response error_no, description, description2, correction
    REXML::Document.new "<errormessage><error><errorno>#{error_no}</errorno><description>#{description}</description><description2>#{description2}</description2><correction>#{correction}</correction></error></errormessage>"
  end

  def create_failure_response controlid, function
    REXML::Document.new "<result><controlid>#{controlid}</controlid><status>error</status><function>#{function}</function>"
  end

  def create_result_key_response controlid, key
    REXML::Document.new("<result><status>success</status><controlid>#{controlid}</controlid><key>#{key}</key></result>")
  end

  before :each do
    @xml_gen = double("MockIntacctXmlGenerator")
    @c = described_class.new @xml_gen
  end

  describe "send_dimension" do

    it "checks for an existing dimension before creating a new one" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      @xml_gen.should_receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]

      dimension_response = REXML::Document.new "<notfound>false</notfound>"
      @c.should_receive(:post_xml).with("company", false, false, get_xml, control).and_return dimension_response

      create_xml = "<create>value</create>"
      control2 = "controlid2"
      @xml_gen.should_receive(:generate_dimension_create).with("type", "id", "value").and_return [control2, create_xml]

      create_response = REXML::Document.new "<key>New Dimension</key>"
      @c.should_receive(:post_xml).with("company", true, true, create_xml, control2).and_return create_response


      expect(@c.send_dimension "type", "id", "value", "company").to eq "New Dimension"
    end

    it "does not create a new dimnsion if one already exists" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      @xml_gen.should_receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]

      dimension_response = REXML::Document.new "<key>Existing</key>"
      @c.should_receive(:post_xml).with("company", false, false, get_xml, control).and_return dimension_response

      expect(@c.send_dimension "type", "id", "value", "company").to eq "Existing"
    end

    it "logs error responses" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      @xml_gen.should_receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]
      
      @c.should_receive(:post_xml).with("company", false, false, get_xml, control).and_raise OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, "Intacct Error"
      OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError.any_instance.should_receive(:log_me).with ["Failed to find and/or create dimension type id for location company."]

      expect(@c.send_dimension "type", "id", "value", "company").to be_nil
    end

    it "uses temp locks around dimension call to avoid race conditions" do
      # Don't have this return/yield anything, we then know this is the only real thing
      # of consequence done first in the method, which is what we want
      Lock.should_receive(:acquire).with("IntacctDimension-type-id", temp_lock: true)
      expect(@c.send_dimension "type", "id", "value").to be_nil
    end

    it "swallows errors returned by Intacct API related to duplicate create calls" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      @xml_gen.should_receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]
      @c.should_receive(:post_xml).with(nil, false, false, get_xml, control).and_raise OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, "A successful transaction has already been recorded with the control id #{control}"

      expect(@c.send_dimension "type", "id", "value").to eq "id"
    end

    it "swallows errors returned by Intacct API related to duplicate create calls" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      @xml_gen.should_receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]
      @c.should_receive(:post_xml).with(nil, false, false, get_xml, control).and_raise OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, "Another Class with the given value(s) already exists."

      expect(@c.send_dimension "type", "id", "value").to eq "id"
    end
  end

  describe "send_receivable" do

    it "sends receivable information and sets key and upload date back into receivable" do
      r = IntacctReceivable.new intacct_errors: "Error", company: "c"
      cid = "controlid"
      xml = "<recv>receivable</recv>"
      @xml_gen.should_receive(:generate_receivable_xml).with(r).and_return [cid, xml]

      @c.should_receive(:post_xml).with("c", true, true, xml, cid).and_return create_result_key_response(cid, "R-Key")

      @c.send_receivable r

      expect(r.persisted?).to be_true
      expect(r.intacct_key).to eq "R-Key"
      expect(r.intacct_upload_date.to_date).to eq Time.zone.now.to_date
      expect(r.intacct_errors).to be_nil
    end

    it "sends receivable information and handles errors" do
      r = IntacctReceivable.new company: "c"
      cid = "controlid"
      xml = "<recv>receivable</recv>"
      @xml_gen.should_receive(:generate_receivable_xml).with(r).and_return [cid, xml]

      @c.should_receive(:post_xml).with("c", true, true, xml, cid).and_raise "Error Message"

      @c.send_receivable r

      expect(r.persisted?).to be_true
      expect(r.intacct_errors).to eq "Error Message"
    end

    it "retries sending xml 3 times if retry error is raised" do
      r = IntacctReceivable.new company: "c"
      cid = "controlid"
      xml = "<recv>receivable</recv>"
      @xml_gen.should_receive(:generate_receivable_xml).with(r).exactly(3).times.and_return [cid, xml]
      @c.should_receive(:post_xml).with("c", true, true, xml, cid).exactly(3).and_raise OpenChain::CustomHandler::Intacct::IntacctClient::IntacctRetryError, "Error Message"
      @c.should_receive(:sleep).with(1)
      @c.should_receive(:sleep).with(2)

      @c.send_receivable r

      expect(r.persisted?).to be_true
      expect(r.intacct_errors).to eq "Error Message"
    end
  end

  describe "send_payable" do

    it "sends payable information and sets key and upload date back into payable" do
      p = IntacctPayable.new intacct_errors: "Error", company: "c", vendor_number: "v"
      cid = "controlid"
      xml = "<pay>payable</pay>"
    
      @c.should_receive(:get_object_fields).with("c", "vendor", "v", "termname").and_return({"termname" => "TERMS"})
      @xml_gen.should_receive(:generate_payable_xml).with(p, "TERMS").and_return [cid, xml]
      @c.should_receive(:post_xml).with("c", true, true, xml, cid).and_return create_result_key_response(cid, "P-Key")

      @c.send_payable p

      expect(p.persisted?).to be_true
      expect(p.intacct_key).to eq "P-Key"
      expect(p.intacct_upload_date.to_date).to eq Time.zone.now.to_date
      expect(p.intacct_errors).to be_nil
    end

    it "handles missing terms for vendor" do
      p = IntacctPayable.new intacct_errors: "Error", company: "c", vendor_number: "v"
      @c.should_receive(:get_object_fields).with("c", "vendor", "v", "termname").and_return({})

      @c.send_payable p
      expect(p.persisted?).to be_true
      expect(p.intacct_errors).to eq "Failed to retrieve Terms for Vendor v.  Terms must be set up for all vendors."
    end

    it "handles errors creating payable" do
      p = IntacctPayable.new intacct_errors: "Error", company: "c", vendor_number: "v"
      cid = "controlid"
      xml = "<pay>payable</pay>"
      
      @c.should_receive(:get_object_fields).with("c", "vendor", "v", "termname").and_return({"termname" => "TERMS"})
      @xml_gen.should_receive(:generate_payable_xml).with(p, "TERMS").and_return [cid, xml]
      @c.should_receive(:post_xml).with("c", true, true, xml, cid).and_raise "Creation error."

      @c.send_payable p

      expect(p.persisted?).to be_true
      expect(p.intacct_errors).to eq "Creation error."
    end

    it "sends checks using check xml" do
      p = IntacctPayable.new company: "c", payable_type: IntacctPayable::PAYABLE_TYPE_CHECK

      cid = "controlid"
      xml = "<check>check</check>"
      @xml_gen.should_receive(:generate_check_gl_entry_xml).with(p).and_return [cid, xml]
      @c.should_receive(:post_xml).with("c", true, true, xml, cid).and_return create_result_key_response(cid, "GL-Account-Key")

      @c.send_payable p

      expect(p.persisted?).to be_true
      expect(p.intacct_key).to eq "GL-Account-Key"
      expect(p.intacct_upload_date.to_date).to eq Time.zone.now.to_date
    end

    it "sends advanced checks using check xml" do
      p = IntacctPayable.new company: "c", payable_type: IntacctPayable::PAYABLE_TYPE_ADVANCED

      cid = "controlid"
      xml = "<check>check</check>"
      @xml_gen.should_receive(:generate_check_gl_entry_xml).with(p).and_return [cid, xml]
      @c.should_receive(:post_xml).with("c", true, true, xml, cid).and_return create_result_key_response(cid, "GL-Account-Key")

      @c.send_payable p

      expect(p.persisted?).to be_true
      expect(p.intacct_key).to eq "GL-Account-Key"
      expect(p.intacct_upload_date.to_date).to eq Time.zone.now.to_date
    end
  end

  describe "get_object_fields" do
    it "retrieves specific fields for an object" do
      cid = "controlid"
      xml = "<fields>f</fields>"
      @xml_gen.should_receive(:generate_get_object_fields).with("object", "key", "field1", "field2").and_return [cid, xml]

      fields_xml = "<result><controlid>#{cid}</controlid><data><object><field1>value1</field1><field2>value2</field2></object></data></result>"
      @c.should_receive(:post_xml).with("c", false, false, xml, cid).and_return REXML::Document.new(fields_xml)

      expect(@c.get_object_fields "c", "object", "key", "field1", "field2").to eq({"field1" => "value1", "field2" => "value2"})
    end

    it "raises an error if it can't find object fields" do
      cid = "controlid"
      xml = "<fields>f</fields>"
      @xml_gen.should_receive(:generate_get_object_fields).with("object", "key", "field1", "field2").and_return [cid, xml]
      @c.should_receive(:post_xml).with("c", false, false, xml, cid).and_return REXML::Document.new("<result />")

      expect {@c.get_object_fields "c", "object", "key", "field1", "field2"}.to raise_error "Failed to find object object with key key."
    end
  end

  describe "post_xml" do

    before :each do
      @resp = REXML::Document.new "<result><controlid>controlid</controlid><status>success</status></result>"
      @c.stub(:http_request) do |uri, post|
        @uri = uri
        @post = post

        @resp
      end
    end

    it "posts xml to the intacct API" do
      function_content = "<content>function</content>"
      outer_control_id = Digest::SHA1.hexdigest function_content
      expect(@c.post_xml "location", true, true, function_content, "controlid").to eq @resp

      # We're primarily concerned with what we're actually posting here, so check out the URI and post values
      # we've captured.
      expect(@uri.to_s).to eq "https://www.intacct.com/ia/xml/xmlgw.phtml"
      expect(@post.uri).to eq @uri
      expect(@post['content-type']).to eq "x-intacct-xml-request"

      x = REXML::Document.new(@post.body)

      expect(x.text "/request/control/senderid").to eq "vandegriftinc"
      expect(x.text "/request/control/password").to eq "9gUMGbFIMy"
      expect(x.text "/request/control/dtdversion").to eq "2.1"
      expect(x.text "/request/control/controlid").to eq outer_control_id
      # In non-production env. don't ever set this value to true.
      expect(x.text "/request/control/uniqueid").to eq "false"

      expect(REXML::XPath.first(x, "/request/operation").attributes["transaction"]).to eq "true"
      expect(x.text "/request/operation/authentication/login/userid").to eq "integration"
      expect(x.text "/request/operation/authentication/login/companyid").to eq "vfi"
      expect(x.text "/request/operation/authentication/login/password").to eq "b,Z+&W>6dFR:"
      expect(x.text "/request/operation/authentication/login/locationid").to eq "location"
      
      expect(REXML::XPath.first(x, "/request/operation/content").elements[1].to_s).to eq function_content
    end

    it "sets unique id to true in production env if specified" do
      @c.should_receive(:production?).and_return true
      function_content = "<content>function</content>"
      outer_control_id = Digest::SHA1.hexdigest function_content
      expect(@c.post_xml "location", true, true, function_content, "controlid").to eq @resp

      x = REXML::Document.new(@post.body)
      expect(x.text "/request/control/uniqueid").to eq "true"
    end

    it "allows overriding default values" do
      @c.should_receive(:production?).and_return true
      overrides = {sender_id: "sid", sender_password: "spwd", api_version: "3", user_id: "uid", company_id: "cid", user_password: "upwd", url: "http://www.test.com/"}

      function_content = "<content>function</content>"
      outer_control_id = Digest::SHA1.hexdigest function_content
      expect(@c.post_xml nil, false, false, function_content, "controlid", overrides).to eq @resp


      expect(@uri.to_s).to eq overrides[:url]
      expect(@post.uri).to eq @uri
      expect(@post['content-type']).to eq "x-intacct-xml-request"

      x = REXML::Document.new(@post.body)

      expect(x.text "/request/control/senderid").to eq overrides[:sender_id]
      expect(x.text "/request/control/password").to eq overrides[:sender_password]
      expect(x.text "/request/control/dtdversion").to eq overrides[:api_version]
      expect(x.text "/request/control/controlid").to eq outer_control_id
      expect(x.text "/request/control/uniqueid").to eq "false"

      expect(REXML::XPath.first(x, "/request/operation").attributes["transaction"]).to be_nil
      expect(x.text "/request/operation/authentication/login/userid").to eq overrides[:user_id]
      expect(x.text "/request/operation/authentication/login/companyid").to eq overrides[:company_id]
      expect(x.text "/request/operation/authentication/login/password").to eq overrides[:user_password]
      expect(x.text "/request/operation/authentication/login/locationid").to be_nil
      
      expect(REXML::XPath.first(x, "/request/operation/content").elements[1].to_s).to eq function_content
    end

    it "transparently handles responses with error messages" do
      error_no = "123"
      description = "Desc1"
      description2 = "Desc2"
      correction = "Correction"

      @resp = REXML::Document.new "<errormessage><error><errorno>#{error_no}</errorno><description>#{description}</description><description2>#{description2}</description2><correction>#{correction}</correction></error></errormessage>"

      error_message = "Intacct API call failed with errors:\nError No: #{error_no}\nDescription: #{description}\nDescription 2: #{description2}\nCorrection: #{correction}"
      expect{@c.post_xml nil, false, false, "<f>content</f>", "controlid"}.to raise_error OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, error_message
    end

    it "transparently handles responses with non-success statuses" do
      @resp =  REXML::Document.new "<result><controlid>id</controlid><status>error</status><function>func</function></result>"
      error_message = "Intacct API Function call func failed with status error."
      expect{@c.post_xml nil, false, false, "<f>content</f>", "id"}.to raise_error OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, error_message
    end

    it "raises retry error for errors with only 'Could not create Document record!' errors" do
      error_response = "<errormessage>
      <error><errorno>BL01001973</errorno><description></description><description2>Desc 1</description2><correction></correction></error>
      <error><errorno>XL03000009</errorno><description></description><description2>Desc 2</description2><correction></correction></error>
      </errormessage>"
      @resp = REXML::Document.new error_response
      error_message = "Intacct API call failed with errors:\nError No: BL01001973\nDescription: \nDescription 2: Desc 1\nCorrection: \nError No: XL03000009\nDescription: \nDescription 2: Desc 2\nCorrection: "

      expect{@c.post_xml nil, false, false, "<f>content</f>", "controlid"}.to raise_error OpenChain::CustomHandler::Intacct::IntacctClient::IntacctRetryError, error_message
    end

    it "does not raise retry error when other BL01001973 errors are present" do
      error_no = "BL01001973"
      description = "Desc1"
      description2 = "Could not create Document record!"
      correction = "Correction"

      error_response = "<errormessage>
      <error><errorno>BL01001973</errorno><description></description><description2>Other Error</description2><correction></correction></error>
      <error><errorno>BL01001973</errorno><description></description><description2>Desc 1</description2><correction></correction></error>
      <error><errorno>XL03000009</errorno><description></description><description2>Desc 2</description2><correction></correction></error>
      </errormessage>"
      @resp = REXML::Document.new error_response
      error_message = "Intacct API call failed with errors:\nError No: BL01001973\nDescription: \nDescription 2: Other Error\nCorrection: \nError No: BL01001973\nDescription: \nDescription 2: Desc 1\nCorrection: \nError No: XL03000009\nDescription: \nDescription 2: Desc 2\nCorrection: "

      expect{@c.post_xml nil, false, false, "<f>content</f>", "controlid"}.to raise_error OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, error_message
    end
  end

  describe "process_response" do
    it "wraps the response body in a REXML::Document" do
      # This test is just to ensure we're fulfilling the HttpClient contract to turn the response into an XML document
      resp = double("MockHttpReponse")
      resp.should_receive(:body).and_return "<xml>Test</xml>"

      r = @c.send(:process_response, resp)
      expect(r.is_a? REXML::Document).to be_true
      expect(r.to_s).to eq REXML::Document.new("<xml>Test</xml>").to_s
    end
  end
end