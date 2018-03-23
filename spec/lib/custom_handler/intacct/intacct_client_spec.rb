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
    xml = "<result><status>success</status><controlid>#{controlid}</controlid><key>#{key}</key></result>"
    if block_given?
      yield xml
    else
      REXML::Document.new xml
    end
  end

  def create_multi_result_key_response ids
    xml = ""
    ids.each_pair do |key, value|
      create_result_key_response(key, value) {|result| xml << result}
    end

    REXML::Document.new "<response>#{xml}</response>"
  end

  let (:xml_gen) {
    double("MockIntacctXmlGenerator")
  }

  subject {
    described_class.new xml_gen
  }


  describe "send_dimension" do

    it "checks for an existing dimension before creating a new one" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      expect(xml_gen).to receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]

      dimension_response = REXML::Document.new "<notfound>false</notfound>"
      expect(subject).to receive(:post_xml).with("company", false, false, get_xml, control).and_return dimension_response

      create_xml = "<create>value</create>"
      control2 = "controlid2"
      expect(xml_gen).to receive(:generate_dimension_create).with("type", "id", "value").and_return [control2, create_xml]

      create_response = REXML::Document.new "<key>New Dimension</key>"
      expect(subject).to receive(:post_xml).with("company", true, true, create_xml, control2).and_return create_response


      expect(subject.send_dimension "type", "id", "value", "company").to eq "New Dimension"
    end

    it "does not create a new dimnsion if one already exists" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      expect(xml_gen).to receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]

      dimension_response = REXML::Document.new "<key>Existing</key>"
      expect(subject).to receive(:post_xml).with("company", false, false, get_xml, control).and_return dimension_response

      expect(subject.send_dimension "type", "id", "value", "company").to eq "Existing"
    end

    it "logs error responses" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      expect(xml_gen).to receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]

      expect(subject).to receive(:post_xml).with("company", false, false, get_xml, control).and_raise OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, "Intacct Error"

      expect(subject.send_dimension "type", "id", "value", "company").to be_nil
      expect(ErrorLogEntry.last.additional_messages_json).to match(/Failed to find and\/or create dimension type id for location company/)
    end

    it "swallows errors returned by Intacct API related to duplicate create calls" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      expect(xml_gen).to receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]
      expect(subject).to receive(:post_xml).with(nil, false, false, get_xml, control).and_raise OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, "A successful transaction has already been recorded with the control id #{control}"

      expect(subject.send_dimension "type", "id", "value").to eq "id"
    end

    it "swallows errors returned by Intacct API related to duplicate Class create calls" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      expect(xml_gen).to receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]
      expect(subject).to receive(:post_xml).with(nil, false, false, get_xml, control).and_raise OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, "Another Class with the given value(s) 12345 already exists."

      expect(subject.send_dimension "type", "id", "value").to eq "id"
    end

    it "swallows errors returned by Intacct API related to duplicate Project create calls" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      expect(xml_gen).to receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]
      expect(subject).to receive(:post_xml).with(nil, false, false, get_xml, control).and_raise OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, "Another Project with the given value(s) 12345 already exists."

      expect(subject.send_dimension "type", "id", "value").to eq "id"
    end

    it "retries sending dimension if a retry error is raised" do
      get_xml = "<xml>test</xml>"
      control = "controlid"
      allow(xml_gen).to receive(:generate_dimension_get).with("type", "id").and_return [control, get_xml]
      expect(subject).to receive(:post_xml).exactly(5).times.and_raise described_class::IntacctRetryError
      expect(subject).to receive(:sleep).with(1)
      expect(subject).to receive(:sleep).with(2)
      expect(subject).to receive(:sleep).with(3)
      expect(subject).to receive(:sleep).with(4)

      subject.send_dimension "type", "id", "value"
    end
  end

  describe "send_receivable" do

    it "sends receivable information and sets key and upload date back into receivable" do
      r = IntacctReceivable.new intacct_errors: "Error", company: "c"
      cid = "controlid"
      xml = "<recv>receivable</recv>"
      expect(xml_gen).to receive(:generate_receivable_xml).with(r).and_return [cid, xml]

      expect(subject).to receive(:post_xml).with("c", true, true, xml, cid).and_return create_result_key_response(cid, "R-Key")

      subject.send_receivable r

      expect(r.persisted?).to be_truthy
      expect(r.intacct_key).to eq "R-Key"
      expect(r.intacct_upload_date.to_date).to eq Time.zone.now.to_date
      expect(r.intacct_errors).to be_nil
    end

    it "sends receivable information and handles errors" do
      r = IntacctReceivable.new company: "c"
      cid = "controlid"
      xml = "<recv>receivable</recv>"
      expect(xml_gen).to receive(:generate_receivable_xml).with(r).and_return [cid, xml]

      expect(subject).to receive(:post_xml).with("c", true, true, xml, cid).and_raise "Error Message"

      subject.send_receivable r

      expect(r.persisted?).to be_truthy
      expect(r.intacct_errors).to eq "Error Message"
    end

    it "retries sending xml 3 times if retry error is raised" do
      r = IntacctReceivable.new company: "c"
      cid = "controlid"
      xml = "<recv>receivable</recv>"
      expect(xml_gen).to receive(:generate_receivable_xml).with(r).exactly(3).times.and_return [cid, xml]
      expect(subject).to receive(:post_xml).with("c", true, true, xml, cid).exactly(3).and_raise OpenChain::CustomHandler::Intacct::IntacctClient::IntacctRetryError, "Error Message"
      expect(subject).to receive(:sleep).with(1)
      expect(subject).to receive(:sleep).with(2)

      subject.send_receivable r

      expect(r.persisted?).to be_truthy
      expect(r.intacct_errors).to eq "Error Message"
    end
  end

  describe "send_payable" do

    it "sends payable information and sets key and upload date back into payable" do
      p = IntacctPayable.new intacct_errors: "Error", company: "c", vendor_number: "v"
      c = IntacctCheck.new intacct_errors: "Error", company: "c", vendor_number: "v"
      checks = [c]
      cid = "controlid"
      xml = "<pay>payable</pay>"
      check_cid = "checkid"
      check_xml = "<check>check</check>"

      expect(subject).to receive(:get_object_fields).with("c", "vendor", "v", "termname").and_return({"termname" => "TERMS"})
      expect(xml_gen).to receive(:generate_payable_xml).with(p, "TERMS").and_return [cid, xml]
      expect(xml_gen).to receive(:generate_ap_adjustment).with(c, p).and_return [check_cid, check_xml]
      expect(subject).to receive(:post_xml).with("c", true, true, xml + check_xml, [cid, check_cid]).and_return create_multi_result_key_response({cid => "P-Key", check_cid => "C-Key"})

      subject.send_payable p, checks

      expect(p.persisted?).to be_truthy
      expect(p.intacct_key).to eq "P-Key"
      expect(p.intacct_upload_date.to_date).to eq Time.zone.now.to_date
      expect(p.intacct_errors).to be_nil

      expect(c).to be_persisted
      expect(c.intacct_adjustment_key).to eq "C-Key"
    end

    it "handles missing terms for vendor" do
      p = IntacctPayable.new intacct_errors: "Error", company: "c", vendor_number: "v"
      expect(subject).to receive(:get_object_fields).with("c", "vendor", "v", "termname").and_return({})

      subject.send_payable p, []
      expect(p.persisted?).to be_truthy
      expect(p.intacct_errors).to eq "Failed to retrieve Terms for Vendor v.  Terms must be set up for all vendors."
    end

    it "handles errors creating payable" do
      p = IntacctPayable.new intacct_errors: "Error", company: "c", vendor_number: "v"
      c = IntacctCheck.new intacct_errors: "Error", company: "c", vendor_number: "v"
      checks = [c]
      cid = "controlid"
      xml = "<pay>payable</pay>"
      check_cid = "checkid"
      check_xml = "<check>check</check>"

      expect(subject).to receive(:get_object_fields).with("c", "vendor", "v", "termname").and_return({"termname" => "TERMS"})
      expect(xml_gen).to receive(:generate_payable_xml).with(p, "TERMS").and_return [cid, xml]
      expect(xml_gen).to receive(:generate_ap_adjustment).with(c, p).and_return [check_cid, check_xml]
      expect(subject).to receive(:post_xml).with("c", true, true, (xml + check_xml), [cid, check_cid]).and_raise "Creation error."

      subject.send_payable p, checks

      expect(p.persisted?).to be_truthy
      expect(p.intacct_errors).to eq "Creation error."

      expect(c).not_to be_persisted
    end
  end

  describe "send_check" do
    it "sends checks using check xml" do
      check = IntacctCheck.new company: "c"

      cid = "controlid"
      xml = "<check>check</check>"
      expect(xml_gen).to receive(:generate_check_gl_entry_xml).with(check).and_return [cid, xml]
      expect(subject).to receive(:post_xml).with("c", true, true, xml, [cid]).and_return create_result_key_response(cid, "GL-Account-Key")

      subject.send_check check, false

      expect(check.persisted?).to be_truthy
      expect(check.intacct_key).to eq "GL-Account-Key"
      expect(check.intacct_upload_date.to_date).to eq Time.zone.now.to_date
    end

    it "sends checks and adjustments" do
      check = IntacctCheck.new company: "c"

      cid = "controlid"
      xml = "<check>check</check>"
      adj_id = "adj_id"
      adj_xml = "<adjustment>adj</adjustment>"

      expect(xml_gen).to receive(:generate_check_gl_entry_xml).with(check).and_return [cid, xml]
      expect(xml_gen).to receive(:generate_ap_adjustment).with(check, nil).and_return [adj_id, adj_xml]

      expect(subject).to receive(:post_xml).with("c", true, true, (xml+adj_xml), [cid, adj_id]).and_return create_multi_result_key_response({cid => "GL-Account-Key", adj_id => "Adj-Key"})

      create_result_key_response(cid, "GL-Account-Key")

      subject.send_check check, true

      expect(check.persisted?).to be_truthy
      expect(check.intacct_key).to eq "GL-Account-Key"
      expect(check.intacct_adjustment_key).to eq "Adj-Key"
      expect(check.intacct_upload_date.to_date).to eq Time.zone.now.to_date

    end

    it "logs check send errors" do
      check = IntacctCheck.new company: "c"
      cid = "controlid"
      xml = "<check>check</check>"

      expect(xml_gen).to receive(:generate_check_gl_entry_xml).with(check).and_return [cid, xml]
      expect(subject).to receive(:post_xml).with("c", true, true, xml, [cid]).and_raise "Creation error."

      subject.send_check check, false

      expect(check.persisted?).to be_truthy
      expect(check.intacct_errors).to eq "Creation error."
    end
  end

  describe "get_object_fields" do
    it "retrieves specific fields for an object" do
      cid = "controlid"
      xml = "<fields>f</fields>"
      expect(xml_gen).to receive(:generate_get_object_fields).with("object", "key", "field1", "field2").and_return [cid, xml]

      fields_xml = "<result><controlid>#{cid}</controlid><data><object><field1>value1</field1><field2>value2</field2></object></data></result>"
      expect(subject).to receive(:post_xml).with("c", false, false, xml, cid, {read_only: true}).and_return REXML::Document.new(fields_xml)

      expect(subject.get_object_fields "c", "object", "key", "field1", "field2").to eq({"field1" => "value1", "field2" => "value2"})
    end

    it "raises an error if it can't find object fields" do
      cid = "controlid"
      xml = "<fields>f</fields>"
      expect(xml_gen).to receive(:generate_get_object_fields).with("object", "key", "field1", "field2").and_return [cid, xml]
      expect(subject).to receive(:post_xml).with("c", false, false, xml, cid, {read_only: true}).and_return REXML::Document.new("<result />")

      expect {subject.get_object_fields "c", "object", "key", "field1", "field2"}.to raise_error "Failed to find object object with key key."
    end
  end

  describe "post_xml" do

    let (:intacct_response) {
      REXML::Document.new "<result><controlid>controlid</controlid><status>success</status></result>"
    }

    context "in production" do
      let! (:master_setup) {
        ms = stub_master_setup
        allow(ms).to receive(:production?).and_return true
        ms
      }

      let! (:config) {
        conf = {
          sender_id: "vfi",
          sender_password: "vfi-password",
          company_id: "vfi",
          user_id: "user",
          user_password: "user-password"
        }
        allow(described_class).to receive(:intacct_config).and_return conf
        conf
      }

      before :each do 
        allow(subject).to receive(:production?).and_return true

        allow(subject).to receive(:http_request) do |uri, post|
          @uri = uri
          @post = post

          intacct_response
        end
      end

      it "posts xml to the intacct API" do
        function_content = "<content>function</content>"
        outer_control_id = Digest::SHA1.hexdigest function_content
        expect(subject.post_xml "location", true, true, function_content, "controlid").to eq intacct_response

        # We're primarily concerned with what we're actually posting here, so check out the URI and post values
        # we've captured.
        expect(@uri.to_s).to eq "https://api.intacct.com/ia/xml/xmlgw.phtml"
        expect(@post.uri).to eq @uri
        expect(@post['content-type']).to eq "x-intacct-xml-request"

        x = REXML::Document.new(@post.body)

        expect(x.text "/request/control/senderid").to eq "vfi"
        expect(x.text "/request/control/password").to eq "vfi-password"
        expect(x.text "/request/control/dtdversion").to eq "2.1"
        expect(x.text "/request/control/controlid").to eq outer_control_id
        expect(x.text "/request/control/uniqueid").to eq "true"

        expect(REXML::XPath.first(x, "/request/operation").attributes["transaction"]).to eq "true"
        expect(x.text "/request/operation/authentication/login/userid").to eq "user"
        expect(x.text "/request/operation/authentication/login/companyid").to eq "vfi"
        expect(x.text "/request/operation/authentication/login/password").to eq "user-password"
        expect(x.text "/request/operation/authentication/login/locationid").to eq "location"

        expect(REXML::XPath.first(x, "/request/operation/content").elements[1].to_s).to eq function_content
      end

      it "allows overriding some values" do
        overrides = {sender_id: "sid", sender_password: "spwd", api_version: "3", user_id: "uid", company_id: "cid", user_password: "upwd", url: "http://www.test.com/"}

        function_content = "<content>function</content>"
        outer_control_id = Digest::SHA1.hexdigest function_content
        expect(subject.post_xml nil, false, false, function_content, "controlid", request_options: overrides).to eq intacct_response


        expect(@uri.to_s).to eq overrides[:url]
        expect(@post.uri).to eq @uri
        expect(@post['content-type']).to eq "x-intacct-xml-request"

        x = REXML::Document.new(@post.body)

        expect(x.text "/request/control/senderid").to eq "vfi"
        expect(x.text "/request/control/password").to eq "vfi-password"
        expect(x.text "/request/control/dtdversion").to eq overrides[:api_version]
        expect(x.text "/request/control/controlid").to eq outer_control_id
        expect(x.text "/request/control/uniqueid").to eq "false"

        expect(REXML::XPath.first(x, "/request/operation").attributes["transaction"]).to be_nil
        expect(x.text "/request/operation/authentication/login/userid").to eq "user"
        expect(x.text "/request/operation/authentication/login/companyid").to eq "vfi"
        expect(x.text "/request/operation/authentication/login/password").to eq "user-password"
        expect(x.text "/request/operation/authentication/login/locationid").to be_nil

        expect(REXML::XPath.first(x, "/request/operation/content").elements[1].to_s).to eq function_content
      end

      it "transparently handles responses with error messages" do
        error_no = "123"
        description = "Desc1"
        description2 = "Desc2"
        correction = "Correction"

        error_response = REXML::Document.new "<errormessage><error><errorno>#{error_no}</errorno><description>#{description}</description><description2>#{description2}</description2><correction>#{correction}</correction></error></errormessage>"
        expect(subject).to receive(:http_request).and_return error_response

        error_message = "Intacct API call failed with errors:\nError No: #{error_no}\nDescription: #{description}\nDescription 2: #{description2}\nCorrection: #{correction}"
        expect{subject.post_xml nil, false, false, "<f>content</f>", "controlid"}.to raise_error OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, error_message
      end

      it "transparently handles responses with non-success statuses" do
        error_response = REXML::Document.new "<result><controlid>id</controlid><status>error</status><function>func</function></result>"
        expect(subject).to receive(:http_request).and_return error_response
        error_message = "Intacct API Function call func failed with status error."
        expect{subject.post_xml nil, false, false, "<f>content</f>", "id"}.to raise_error OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, error_message
      end

      it "raises retry error for errors with correction values of 'Check the transaction for errors or inconsistencies, then try again.'" do
        error = "<errormessage>
        <error><errorno>BL01001973</errorno><description></description><description2>Desc 1</description2><correction>Check the transaction for errors or inconsistencies, then try again.</correction></error>
        <error><errorno>XL03000009</errorno><description></description><description2>Desc 2</description2><correction></correction></error>
        </errormessage>"
        error_response = REXML::Document.new error
        expect(subject).to receive(:http_request).and_return error_response
        error_message = "Intacct API call failed with errors:\nError No: BL01001973\nDescription: \nDescription 2: Desc 1\nCorrection: Check the transaction for errors or inconsistencies, then try again.\nError No: XL03000009\nDescription: \nDescription 2: Desc 2\nCorrection: "

        expect{subject.post_xml nil, false, false, "<f>content</f>", "controlid"}.to raise_error OpenChain::CustomHandler::Intacct::IntacctClient::IntacctRetryError, error_message
      end

      it "does not raise retry error when other BL01001973 errors are present" do
        error_no = "BL01001973"
        description = "Desc1"
        description2 = "Could not create Document record!"
        correction = "Correction"

        error = "<errormessage>
        <error><errorno>BL01001973</errorno><description></description><description2>Other Error</description2><correction></correction></error>
        <error><errorno>BL01001973</errorno><description></description><description2>Desc 1</description2><correction></correction></error>
        <error><errorno>XL03000009</errorno><description></description><description2>Desc 2</description2><correction></correction></error>
        </errormessage>"
        error_response = REXML::Document.new error
        expect(subject).to receive(:http_request).and_return error_response
        error_message = "Intacct API call failed with errors:\nError No: BL01001973\nDescription: \nDescription 2: Other Error\nCorrection: \nError No: BL01001973\nDescription: \nDescription 2: Desc 1\nCorrection: \nError No: XL03000009\nDescription: \nDescription 2: Desc 2\nCorrection: "

        expect{subject.post_xml nil, false, false, "<f>content</f>", "controlid"}.to raise_error OpenChain::CustomHandler::Intacct::IntacctClient::IntacctClientError, error_message
      end

      context "with overriden unique flag" do
        let! (:starting_force_non_unique_intacct_request) { 
          Thread.current.thread_variable_get(:force_non_unique_intacct_request)
        }
        after :each do
          Thread.current.thread_variable_set(:force_non_unique_intacct_request, starting_force_non_unique_intacct_request)
        end

        it "allows overriding unique request option" do
          Thread.current.thread_variable_set(:force_non_unique_intacct_request, true)
          expect(subject.post_xml "location", true, true, "<content>function</content>", "controlid").to eq intacct_response
          x = REXML::Document.new(@post.body)
          expect(x.text "/request/control/uniqueid").to eq "false"
        end
      end
    end

    context "development environment posing as production" do
      let! (:config) {
        conf = {
          sender_id: "vfi",
          sender_password: "vfi-password",
          company_id: "vfi",
          user_id: "user",
          user_password: "user-password"
        }
        allow(described_class).to receive(:intacct_config).and_return conf
        conf
      }

      let! (:master_setup) {
        ms = stub_master_setup
        allow(ms).to receive(:production?).and_return true
        ms
      }

      before :each do 
        allow(subject).to receive(:production?).and_return false

        allow(subject).to receive(:http_request) do |uri, post|
          @uri = uri
          @post = post

          intacct_response
        end
      end

      it "errors if attempting to post non-readonly request to non-sandbox" do
        expect{ subject.post_xml "location", true, true, "<content>function</content>", "controlid"}.to raise_error "Cannot post to Intacct in development mode"
      end

      it "allows readonly request to production system" do
        expect{ subject.post_xml "location", true, true, "<content>function</content>", "controlid", read_only: true }.not_to raise_error
      end

      
    end

    context "development environment" do 
      let! (:config) {
        conf = {
          sender_id: "vfi",
          sender_password: "vfi-password",
          company_id: "vfi",
          user_id: "user",
          user_password: "user-password"
        }
        allow(described_class).to receive(:intacct_config).and_return conf
        conf
      }
      
      let! (:master_setup) {
        ms = stub_master_setup
        allow(ms).to receive(:production?).and_return false
        ms
      }

      before :each do 
        allow(subject).to receive(:production?).and_return false

        allow(subject).to receive(:http_request) do |uri, post|
          @uri = uri
          @post = post

          intacct_response
        end
      end

      it "allows post to sandbox" do
        expect{ subject.post_xml "location", true, true, "<content>function</content>", "controlid" }.not_to raise_error
        expect(@post).not_to be_nil
        expect(@post.body).to include "vfi-sandbox"
      end
    end
  end

  describe "process_response" do
    it "wraps the response body in a REXML::Document" do
      # This test is just to ensure we're fulfilling the HttpClient contract to turn the response into an XML document
      resp = double("MockHttpReponse")
      expect(resp).to receive(:body).and_return "<xml>Test</xml>"

      r = subject.send(:process_response, resp)
      expect(r.is_a? REXML::Document).to be_truthy
      expect(r.to_s).to eq REXML::Document.new("<xml>Test</xml>").to_s
    end
  end

  describe "intacct_config" do
    subject { described_class }

    after :each do 
      subject.remove_instance_variable :@intacct_config
    end

    let! (:config) {
      {
        "sender_id" => "vfi",
        "sender_password" => "<vfi-password>",
        "company_id" => "vfi",
        "user_id" => "user",
        "user_password" => "<user-password>"
      }
    }

    it "parses yaml file contents, symbolizes keys, and xml encodes values" do
      expect(YAML).to receive(:load_file).with(Rails.root.join("config", "intacct.yml")).and_return config
      conf = subject.intacct_config

      expect(conf[:sender_id]).to eq "vfi"
      expect(conf[:sender_password]).to eq "&lt;vfi-password&gt;"
      expect(conf[:company_id]).to eq "vfi"
      expect(conf[:user_id]).to eq "user"
      expect(conf[:user_password]).to eq "&lt;user-password&gt;"
    end

    it "handles missing config file" do
      expect(YAML).to receive(:load_file).and_raise Errno::ENOENT

      expect { subject.intacct_config }.to raise_error "No Intacct client configuration file found at 'config/intacct.yml'."
    end

    it "caches config lookup" do
      expect(YAML).to receive(:load_file).with(Rails.root.join("config", "intacct.yml")).and_return config
      conf = subject.intacct_config

      expect(subject.intacct_config.object_id).to eq conf.object_id
    end
  end

  describe "sanitize_query_parameter_value" do
    it "escapes apostrophes in values" do
      expect(subject.sanitize_query_parameter_value "test'ing").to eq "test\\'ing"
    end
  end

  describe "read_object" do

    def generate_intacct_read_response responses
      xml = "<root>"
      Array.wrap(responses).each do |r|
        xml << "<result><controlid>#{r[:control_id]}</controlid><data><#{r[:object_type]}><value>#{r[:value]}</value></#{r[:object_type]}></data></result>"
      end
      xml << "</root>"
      REXML::Document.new xml
    end

    it "generates and sends a read request" do
      expect(xml_gen).to receive(:generate_read_query).with('object', 'key', fields: nil).and_return ["control_id", "<read>object</read>"]
      response = generate_intacct_read_response({control_id: "control_id", object_type: "object", value: "value"})
      expect(subject).to receive(:post_xml).with("location", false, false, "<read>object</read>", ["control_id"], request_options: {api_version: "3.0"}, read_only:true).and_return response


      result = subject.read_object 'location', 'object', 'key'
      expect(result).not_to be_nil
      # This is just making sure the result is parsed and the object type is pulled out of the response
      expect(result.to_s).to eq "<object><value>value</value></object>"
    end

    it "generates a request for multiple results and returns multiple results if an array of keys is passed" do
      expect(xml_gen).to receive(:generate_read_query).with('object', 'key', fields: nil).and_return ["control_id", "<read>object</read>"]
      expect(xml_gen).to receive(:generate_read_query).with('object', 'key2', fields: nil).and_return ["control_id2", "<read>object2</read>"]

      response = generate_intacct_read_response([{control_id: "control_id", object_type: "object", value: "value"}, {control_id: "control_id2", object_type: "object", value: "value2"}])
      expect(subject).to receive(:post_xml).with("location", false, false, "<read>object</read><read>object2</read>", ["control_id", "control_id2"], request_options: {api_version: "3.0"}, read_only:true).and_return response


      result = subject.read_object 'location', 'object', ['key', 'key2']
      expect(result).to be_a Array
      expect(result.length).to eq 2
      expect(result[0].to_s).to eq "<object><value>value</value></object>"
      expect(result[1].to_s).to eq "<object><value>value2</value></object>"
    end

    it "passes through fields to request" do 
      expect(xml_gen).to receive(:generate_read_query).with('object', 'key', fields: ["field1", "field2"]).and_return ["control_id", "<read>object</read>"]
      response = generate_intacct_read_response({control_id: "control_id", object_type: "object", value: "value"})
      expect(subject).to receive(:post_xml).with("location", false, false, "<read>object</read>", ["control_id"], request_options: {api_version: "3.0"}, read_only:true).and_return response


      result = subject.read_object 'location', 'object', 'key', fields: ["field1", "field2"]
      expect(result).not_to be_nil
    end
  end

  describe "list_objects" do

    def generate_intacct_read_response responses
      xml = "<root>"
      Array.wrap(responses).each do |r|
        xml << "<result><controlid>#{r[:control_id]}</controlid><data"
        if r[:numremaining].to_i > 0
          xml << " numremaining='#{r[:numremaining]}'"
        end
        if r[:result_id]
          xml << " resultId='#{r[:result_id]}'"
        end
        xml << "><#{r[:object_type]}><value>#{r[:value]}</value></#{r[:object_type]}></data></result>"
      end
      xml << "</root>"
      REXML::Document.new xml
    end

    it "sends a list request" do
      expect(xml_gen).to receive(:generate_read_by_query).with("object", "query", fields: nil).and_return ["control_id", "<read>object</read>"]
      response = generate_intacct_read_response({control_id: "control_id", object_type: "object", value: "value"})
      expect(subject).to receive(:post_xml).with("location", false, false, "<read>object</read>", "control_id", request_options: {api_version: "3.0"}, read_only:true).and_return response

      result = subject.list_objects 'location', 'object', 'query'
      expect(result).to be_a Array
      expect(result.length).to eq 1
      expect(result[0].to_s).to eq "<object><value>value</value></object>"
    end

    it "executes a readMore if the response indicates there are more results to request" do
      expect(xml_gen).to receive(:generate_read_by_query).with("object", "query", fields: nil).and_return ["control_id", "<read>object</read>"]
      expect(xml_gen).to receive(:generate_read_more).with("resultId").and_return ["control_id2", "<readMore>resultId</readMore>"]

      response = generate_intacct_read_response([{control_id: "control_id", object_type: "object", value: "value", numremaining: 1, result_id: "resultId"}])
      expect(subject).to receive(:post_xml).with("location", false, false, "<read>object</read>", "control_id", request_options: {api_version: "3.0"}, read_only:true).and_return response

      response2 = generate_intacct_read_response({control_id: "control_id2", object_type: "object", value: "value2"})
      expect(subject).to receive(:post_xml).with("location", false, false, "<readMore>resultId</readMore>", "control_id2", request_options: {api_version: "3.0"}, read_only:true).and_return response2    

      result = subject.list_objects 'location', 'object', 'query'
      expect(result).to be_a Array
      expect(result.length).to eq 2
      expect(result[0].to_s).to eq "<object><value>value</value></object>"
      expect(result[1].to_s).to eq "<object><value>value2</value></object>"
    end

    it "does not execute a readMore if max results have already been found" do
      expect(xml_gen).to receive(:generate_read_by_query).with("object", "query", fields: nil).and_return ["control_id", "<read>object</read>"]
      expect(xml_gen).not_to receive(:generate_read_more)

      response = generate_intacct_read_response([{control_id: "control_id", object_type: "object", value: "value", numremaining: 1, result_id: "resultId"}])
      expect(subject).to receive(:post_xml).with("location", false, false, "<read>object</read>", "control_id", request_options: {api_version: "3.0"}, read_only:true).and_return response

      result = subject.list_objects 'location', 'object', 'query', max_results: 1
      expect(result).to be_a Array
      expect(result.length).to eq 1
    end
  end
end
