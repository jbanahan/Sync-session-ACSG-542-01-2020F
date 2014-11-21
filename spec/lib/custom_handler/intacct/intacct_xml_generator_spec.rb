require 'spec_helper'
require 'open_chain/custom_handler/intacct/intacct_xml_generator'

describe OpenChain::CustomHandler::Intacct::IntacctXmlGenerator do

  def validate_control_id function_element, controlid
    expect(function_element.name).to eq "function"

    # The controlid attribute is a SHA1 digest of its child elements
    expect(function_element.attributes['controlid']).to eq controlid
    expect(function_element.attributes['controlid']).to eq Digest::SHA1.hexdigest(function_element.elements[1].to_s)
  end

  describe "generate_receivable_xml" do
    before :each do 
      @recv = IntacctReceivable.new receivable_type: "type", invoice_date: Date.new(2014, 11, 1), customer_number: "cust", invoice_number: "inv", currency: "USD", customer_reference: "REFERENCE", created_at: Time.zone.now
      @rl = @recv.intacct_receivable_lines.build charge_code: '123', charge_description: 'desc', amount: BigDecimal("12.50"), location: "loc", 
                                  line_of_business: "lob", freight_file: "f123", vendor_number: "ven", broker_file: "b123"
    end

    it "makes a function element with a create_sotransaction element" do
      control_id, xml = described_class.new.generate_receivable_xml @recv
      expect(xml).to_not be_nil

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      t = REXML::XPath.first root, "/function/create_sotransaction"

      expect(t.text "transactiontype").to eq @recv.receivable_type
      expect(t.text "datecreated/year").to eq @recv.invoice_date.strftime "%Y"
      expect(t.text "datecreated/month").to eq @recv.invoice_date.strftime "%m"
      expect(t.text "datecreated/day").to eq @recv.invoice_date.strftime "%d"
      expect(t.text "dateposted/year").to eq @recv.invoice_date.strftime "%Y"
      expect(t.text "dateposted/month").to eq @recv.invoice_date.strftime "%m"
      expect(t.text "dateposted/day").to eq @recv.invoice_date.strftime "%d"
      expect(t.text "customerid").to eq @recv.customer_number
      expect(t.text "referenceno").to eq @recv.customer_reference
      expect(t.text "documentno").to eq @recv.invoice_number
      expect(t.text "currency").to eq @recv.currency
      expect(t.text "exchratedate/year").to eq @recv.invoice_date.strftime "%Y"
      expect(t.text "exchratedate/month").to eq @recv.invoice_date.strftime "%m"
      expect(t.text "exchratedate/day").to eq @recv.invoice_date.strftime "%d"
      expect(t.text "exchratetype").to eq "Intacct Daily Rate"

      expect(REXML::XPath.each t, "sotransitems/sotransitem").to have(1).item

      i = REXML::XPath.first t, "sotransitems/sotransitem"
      expect(i.text "itemid").to eq @rl.charge_code
      expect(i.text "memo").to eq @rl.charge_description
      expect(i.text "quantity").to eq "1"
      expect(i.text "unit").to eq "Each"
      expect(i.text "price").to eq @rl.amount.to_s
      expect(i.text "locationid").to eq @rl.location
      expect(i.text "departmentid").to eq @rl.line_of_business
      expect(i.text "projectid").to eq @rl.freight_file
      expect(i.text "customerid").to eq @recv.customer_number
      expect(i.text "vendorid").to eq @rl.vendor_number
      expect(i.text "classid").to eq @rl.broker_file
    end

    it "skips dimension elements without any values" do
      @rl.freight_file = nil
      @rl.broker_file = nil
      @rl.vendor_number = nil

      content_id, xml = described_class.new.generate_receivable_xml @recv
      i = REXML::XPath.first REXML::Document.new(xml).root, "/function/create_sotransaction/sotransitems/sotransitem"

      expect(i.text 'projectid').to be_nil
      expect(i.text 'vendorid').to be_nil
      expect(i.text 'classid').to be_nil
    end

    it "uses create date for posing date on Canadian receivables" do
      @recv.company = 'vcu'
      control_id, xml = described_class.new.generate_receivable_xml @recv
      expect(xml).to_not be_nil

      root = REXML::Document.new(xml).root

      t = REXML::XPath.first root, "/function/create_sotransaction"
      
      posted = @recv.created_at.in_time_zone "Eastern Time (US & Canada)"
      expect(t.text "dateposted/year").to eq posted.strftime "%Y"
      expect(t.text "dateposted/month").to eq posted.strftime "%m"
      expect(t.text "dateposted/day").to eq posted.strftime "%d"
    end
  end

  describe "generate_payable_xml" do
    before :each do 
      @p = IntacctPayable.new vendor_number: "v", bill_date: Time.zone.now.to_date, bill_number: "b", vendor_reference: "ref", currency: "cur", created_at: Time.zone.now
      @l = @p.intacct_payable_lines.build gl_account: "a", amount: BigDecimal.new("12"), charge_description: "desc", location: "loc",
                    line_of_business: "lob", freight_file: "f", customer_number: "c", charge_code: "cc", broker_file: "brok"
    end

    it "makes a function element with a create_bill element child" do
      control_id, xml = described_class.new.generate_payable_xml @p, "terms"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      b = REXML::XPath.first root, "/function/create_bill"

      posted = @p.created_at.in_time_zone "Eastern Time (US & Canada)"

      expect(b.text "vendorid").to eq @p.vendor_number
      expect(b.text "datecreated/year").to eq @p.bill_date.strftime "%Y"
      expect(b.text "datecreated/month").to eq @p.bill_date.strftime "%m"
      expect(b.text "datecreated/day").to eq @p.bill_date.strftime "%d"
      expect(b.text "dateposted/year").to eq posted.strftime "%Y"
      expect(b.text "dateposted/month").to eq posted.strftime "%m"
      expect(b.text "dateposted/day").to eq posted.strftime "%d"
      expect(b.text "termname").to eq "terms"
      expect(b.text "billno").to eq @p.bill_number
      expect(b.text "externalid").to eq @p.vendor_reference
      expect(b.text "currency").to eq @p.currency
      expect(b.text "exchratedate/year").to eq @p.bill_date.strftime "%Y"
      expect(b.text "exchratedate/month").to eq @p.bill_date.strftime "%m"
      expect(b.text "exchratedate/day").to eq @p.bill_date.strftime "%d"
      expect(b.text "exchratetype").to eq "Intacct Daily Rate"

      expect(REXML::XPath.each b, "billitems/lineitem").to have(1).item

      i = REXML::XPath.first b, "billitems/lineitem"

      expect(i.text "glaccountno").to eq @l.gl_account
      expect(i.text "amount").to eq @l.amount.to_s
      expect(i.text "memo").to eq @l.charge_description
      expect(i.text "locationid").to eq @l.location
      expect(i.text "departmentid").to eq @l.line_of_business
      expect(i.text "projectid").to eq @l.freight_file
      expect(i.text "customerid").to eq @l.customer_number
      expect(i.text "vendorid").to eq @p.vendor_number
      expect(i.text "itemid").to eq  @l.charge_code
      expect(i.text "classid").to eq @l.broker_file
    end

    it "skips unrequired elements wihtout any values" do
      @p.bill_number = nil
      @p.vendor_reference = nil
      @l.freight_file = nil
      @l.charge_code = nil
      @l.broker_file = nil

      content_id, xml = described_class.new.generate_payable_xml @p, "t"
      b = REXML::XPath.first REXML::Document.new(xml).root, "/function/create_bill"

      expect(b.text "billno").to be_nil
      expect(b.text "externalid").to be_nil

      i = REXML::XPath.first b, "billitems/lineitem"
      expect(i.text "projectid").to be_nil
      expect(i.text "itemid").to be_nil
      expect(i.text "classid").to be_nil
    end
  end

  describe "generate_dimension_get" do

    it "creates xml to retrieve a Broker File dimension value" do
      control_id, xml = described_class.new.generate_dimension_get "Broker File", "val"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      list = REXML::XPath.first root, "get_list"

      expect(list.attributes["object"]).to eq "class"
      expect(list.attributes["maxitems"]).to eq "1"

      expect(list.text "filter/expression/field").to eq "classid"
      expect(list.text "filter/expression/operator").to eq "="
      expect(list.text "filter/expression/value").to eq "val"
    end

    it "creates xml to retrieve a Freight File dimension value" do
      control_id, xml = described_class.new.generate_dimension_get "Freight File", "val"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      list = REXML::XPath.first root, "get_list"

      expect(list.attributes["object"]).to eq "project"
      expect(list.attributes["maxitems"]).to eq "1"

      expect(list.text "filter/expression/field").to eq "projectid"
      expect(list.text "filter/expression/operator").to eq "="
      expect(list.text "filter/expression/value").to eq "val"
    end

    it "raises an error if an unexpected dimension_type is utilized" do
      expect{ described_class.new.generate_dimension_get "blah", "val"}.to raise_error "Unable to create request for unknown dimension type blah."
    end
  end

  describe "generate_dimension_create" do

    it "creates xml to create a Broker File" do
      control_id, xml = described_class.new.generate_dimension_create "Broker File", "id", "val"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      create = REXML::XPath.first root, "create_class"

      expect(create.text "classid").to eq "id"
      expect(create.text "name").to eq "val"
    end

    it "creates xml to create a Freight File" do
      control_id, xml = described_class.new.generate_dimension_create "Freight File", "id", "val"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      create = REXML::XPath.first root, "create_project"

      expect(create.text "projectid").to eq "id"
      expect(create.text "name").to eq "val"
      expect(create.text "projectcategory").to eq "Internal Billable"
    end

    it "raises an error if an unknown dimension_type is used" do
      expect{ described_class.new.generate_dimension_create "blah", "id", "val"}.to raise_error "Unable to generate create request for unknown dimension type blah."
    end
  end

  describe "generate_get_object_fields" do

    it "creates xml to retrieve object fields" do
      control_id, xml = described_class.new.generate_get_object_fields "MyObject", "MyKey", "field1", "field2"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      g = REXML::XPath.first root, "get"

      expect(g.attributes["object"]).to eq "MyObject"
      expect(g.attributes["key"]).to eq "MyKey"
      
      field_text = REXML::XPath.each(g, "fields/field").map {|e| e.text}

      expect(field_text).to have(2).items
      expect(field_text).to include "field1"
      expect(field_text).to include "field2"
    end

    it "gets objects with all fields" do
      control_id, xml = described_class.new.generate_get_object_fields "MyObject", "MyKey"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      g = REXML::XPath.first root, "get"

      expect(g.attributes["object"]).to eq "MyObject"
      expect(g.attributes["key"]).to eq "MyKey"

      expect(REXML::XPath.each(g, "fields/field")).to have(0).items
    end
  end

  describe "generate_check_gl_entry_xml" do

    before :each do
      @p = IntacctPayable.new vendor_number: "v", bill_date: Time.zone.now.to_date, bill_number: "b", vendor_reference: "ref", currency: "cur"
      @l = @p.intacct_payable_lines.build gl_account: "a", amount: BigDecimal.new("12"), charge_description: "desc", location: "loc",
                    line_of_business: "lob", freight_file: "f", customer_number: "c", charge_code: "cc", broker_file: "brok", check_number: "123",
                    bank_number: "bank", check_date: Date.new(2014, 4, 1), bank_cash_gl_account: "cash"
    end

    it "generates xml for check entries" do
      control_id, xml = described_class.new.generate_check_gl_entry_xml @p
      expect(xml).to_not be_nil

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      g = REXML::XPath.first root, "/function/create_gltransaction"

      expect(g.text "journalid").to eq "GLAC"
      expect(g.text "datecreated/year").to eq @l.check_date.strftime "%Y"
      expect(g.text "datecreated/month").to eq @l.check_date.strftime "%m"
      expect(g.text "datecreated/day").to eq @l.check_date.strftime "%d"
      expect(g.text "description").to eq @l.check_number
      expect(g.text "referenceno").to eq @p.bill_number

      expect(REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements).to have(2).items

      e = REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements[1]
      expect(e.text "trtype").to eq "credit"
      expect(e.text "amount").to eq @l.amount.to_s
      expect(e.text "glaccountno").to eq @l.bank_cash_gl_account
      expect(e.text "document").to eq @l.check_number
      expect(e.text "datecreated/year").to eq @l.check_date.strftime "%Y"
      expect(e.text "datecreated/month").to eq @l.check_date.strftime "%m"
      expect(e.text "datecreated/day").to eq @l.check_date.strftime "%d"
      expect(e.text "memo").to eq @p.vendor_number + " - " + @l.charge_description
      expect(e.text "locationid").to eq @l.location
      expect(e.text "departmentid").to eq @l.line_of_business
      expect(e.text "customerid").to eq @l.customer_number
      expect(e.text "vendorid").to eq @p.vendor_number
      expect(e.text "projectid").to eq @l.freight_file
      expect(e.text "itemid").to eq @l.charge_code
      expect(e.text "classid").to eq @l.broker_file
      expect(e.text "currency").to eq @p.currency
      expect(e.text "exchratedate/year").to eq @l.check_date.strftime "%Y"
      expect(e.text "exchratedate/month").to eq @l.check_date.strftime "%m"
      expect(e.text "exchratedate/day").to eq @l.check_date.strftime "%d"
      expect(e.text "exchratetype").to eq "Intacct Daily Rate"

      e = REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements[2]

      expect(e.text "trtype").to eq "debit"
      expect(e.text "amount").to eq @l.amount.to_s
      expect(e.text "glaccountno").to eq @l.gl_account
      expect(e.text "document").to eq @l.check_number
      expect(e.text "datecreated/year").to eq @l.check_date.strftime "%Y"
      expect(e.text "datecreated/month").to eq @l.check_date.strftime "%m"
      expect(e.text "datecreated/day").to eq @l.check_date.strftime "%d"
      expect(e.text "memo").to eq @p.vendor_number + " - " + @l.charge_description
      expect(e.text "locationid").to eq @l.location
      expect(e.text "departmentid").to eq @l.line_of_business
      expect(e.text "customerid").to eq @l.customer_number
      expect(e.text "vendorid").to eq @p.vendor_number
      expect(e.text "projectid").to eq @l.freight_file
      expect(e.text "itemid").to eq @l.charge_code
      expect(e.text "classid").to eq @l.broker_file
      expect(e.text "currency").to eq @p.currency
      expect(e.text "exchratedate/year").to eq @l.check_date.strftime "%Y"
      expect(e.text "exchratedate/month").to eq @l.check_date.strftime "%m"
      expect(e.text "exchratedate/day").to eq @l.check_date.strftime "%d"
      expect(e.text "exchratetype").to eq "Intacct Daily Rate"
    end

    it "excludes certain blank fields" do
      @l.update_attributes! freight_file: nil, charge_code: nil, broker_file: nil

      control_id, xml = described_class.new.generate_check_gl_entry_xml @p
      expect(xml).to_not be_nil

      root = REXML::Document.new(xml).root
      e = REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements[1]
      expect(e.text "trtype").to eq "credit"
      expect(e.text "projectid").to be_nil
      expect(e.text "itemid").to be_nil
      expect(e.text "classid").to be_nil

      e = REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements[2]
      expect(e.text "trtype").to eq "debit"
      expect(e.text "projectid").to be_nil
      expect(e.text "itemid").to be_nil
      expect(e.text "classid").to be_nil
    end
  end
end