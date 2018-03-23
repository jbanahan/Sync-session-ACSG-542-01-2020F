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

    let! (:receivable_line) {
      receivable.intacct_receivable_lines.build charge_code: '123', charge_description: 'desc', amount: BigDecimal("12.50"), location: "loc", 
                                  line_of_business: "lob", freight_file: "f123", vendor_number: "ven", broker_file: "b123"
    }

    let (:receivable) {
      IntacctReceivable.new receivable_type: "type", invoice_date: Date.new(2014, 11, 1), customer_number: "cust", invoice_number: "inv", currency: "USD", customer_reference: "REFERENCE", created_at: Time.zone.now
    }

    it "makes a function element with a create_sotransaction element" do
      control_id, xml = subject.generate_receivable_xml receivable
      expect(xml).to_not be_nil

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      t = REXML::XPath.first root, "/function/create_sotransaction"

      expect(t.text "transactiontype").to eq receivable.receivable_type
      expect(t.text "datecreated/year").to eq receivable.invoice_date.strftime "%Y"
      expect(t.text "datecreated/month").to eq receivable.invoice_date.strftime "%m"
      expect(t.text "datecreated/day").to eq receivable.invoice_date.strftime "%d"
      expect(t.text "dateposted/year").to eq receivable.invoice_date.strftime "%Y"
      expect(t.text "dateposted/month").to eq receivable.invoice_date.strftime "%m"
      expect(t.text "dateposted/day").to eq receivable.invoice_date.strftime "%d"
      expect(t.text "customerid").to eq receivable.customer_number
      expect(t.text "referenceno").to eq receivable.customer_reference
      expect(t.text "documentno").to eq receivable.invoice_number
      expect(t.text "currency").to eq receivable.currency
      expect(t.text "exchratedate/year").to eq receivable.invoice_date.strftime "%Y"
      expect(t.text "exchratedate/month").to eq receivable.invoice_date.strftime "%m"
      expect(t.text "exchratedate/day").to eq receivable.invoice_date.strftime "%d"
      expect(t.text "exchratetype").to eq "Intacct Daily Rate"

      expect(REXML::XPath.each(t, "sotransitems/sotransitem").size).to eq(1)

      i = REXML::XPath.first t, "sotransitems/sotransitem"
      expect(i.text "itemid").to eq receivable_line.charge_code
      expect(i.text "memo").to eq receivable_line.charge_description
      expect(i.text "quantity").to eq "1"
      expect(i.text "unit").to eq "Each"
      expect(i.text "price").to eq receivable_line.amount.to_s
      expect(i.text "locationid").to eq receivable_line.location
      expect(i.text "departmentid").to eq receivable_line.line_of_business
      expect(i.text "projectid").to eq receivable_line.freight_file
      expect(i.text "customerid").to eq receivable.customer_number
      expect(i.text "vendorid").to eq receivable_line.vendor_number
      expect(i.text "classid").to eq receivable_line.broker_file
    end

    it "skips dimension elements without any values" do
      receivable_line.freight_file = nil
      receivable_line.broker_file = nil
      receivable_line.vendor_number = nil

      content_id, xml = subject.generate_receivable_xml receivable
      i = REXML::XPath.first REXML::Document.new(xml).root, "/function/create_sotransaction/sotransitems/sotransitem"

      expect(i.text 'projectid').to be_nil
      expect(i.text 'vendorid').to be_nil
      expect(i.text 'classid').to be_nil
    end

    it "uses create date for posing date on Canadian receivables" do
      receivable.company = 'vcu'
      control_id, xml = subject.generate_receivable_xml receivable
      expect(xml).to_not be_nil

      root = REXML::Document.new(xml).root

      t = REXML::XPath.first root, "/function/create_sotransaction"
      
      posted = receivable.created_at.in_time_zone "Eastern Time (US & Canada)"
      expect(t.text "dateposted/year").to eq posted.strftime "%Y"
      expect(t.text "dateposted/month").to eq posted.strftime "%m"
      expect(t.text "dateposted/day").to eq posted.strftime "%d"
    end
  end

  describe "generate_payable_xml" do
    let (:payable) {
      IntacctPayable.new vendor_number: "v", bill_date: Date.new(2014, 12, 1), bill_number: "b", vendor_reference: "ref", currency: "cur", created_at: Time.zone.now
    }
    let! (:payable_line) {
      payable.intacct_payable_lines.build gl_account: "a", amount: BigDecimal.new("12"), charge_description: "desc", location: "loc",
                    line_of_business: "lob", freight_file: "f", customer_number: "c", charge_code: "cc", broker_file: "brok"
    }

    it "makes a function element with a create_bill element child" do
      control_id, xml = subject.generate_payable_xml payable, "terms"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      b = REXML::XPath.first root, "/function/create_bill"

      posted = payable.bill_date

      expect(b.text "vendorid").to eq payable.vendor_number
      expect(b.text "datecreated/year").to eq payable.bill_date.strftime "%Y"
      expect(b.text "datecreated/month").to eq payable.bill_date.strftime "%m"
      expect(b.text "datecreated/day").to eq payable.bill_date.strftime "%d"
      expect(b.text "dateposted/year").to eq posted.strftime "%Y"
      expect(b.text "dateposted/month").to eq posted.strftime "%m"
      expect(b.text "dateposted/day").to eq posted.strftime "%d"
      expect(b.text "termname").to eq "terms"
      expect(b.text "billno").to eq payable.bill_number
      expect(b.text "externalid").to eq payable.vendor_reference
      expect(b.text "currency").to eq payable.currency
      expect(b.text "exchratedate/year").to eq payable.bill_date.strftime "%Y"
      expect(b.text "exchratedate/month").to eq payable.bill_date.strftime "%m"
      expect(b.text "exchratedate/day").to eq payable.bill_date.strftime "%d"
      expect(b.text "exchratetype").to eq "Intacct Daily Rate"

      expect(REXML::XPath.each(b, "billitems/lineitem").size).to eq(1)

      i = REXML::XPath.first b, "billitems/lineitem"

      expect(i.text "glaccountno").to eq payable_line.gl_account
      expect(i.text "amount").to eq payable_line.amount.to_s
      expect(i.text "memo").to eq payable_line.charge_description
      expect(i.text "locationid").to eq payable_line.location
      expect(i.text "departmentid").to eq payable_line.line_of_business
      expect(i.text "projectid").to eq payable_line.freight_file
      expect(i.text "customerid").to eq payable_line.customer_number
      expect(i.text "vendorid").to eq payable.vendor_number
      expect(i.text "itemid").to eq  payable_line.charge_code
      expect(i.text "classid").to eq payable_line.broker_file
    end

    it "skips unrequired elements wihtout any values" do
      payable.bill_number = nil
      payable.vendor_reference = nil
      payable_line.freight_file = nil
      payable_line.charge_code = nil
      payable_line.broker_file = nil

      content_id, xml = subject.generate_payable_xml payable, "t"
      b = REXML::XPath.first REXML::Document.new(xml).root, "/function/create_bill"

      expect(b.text "billno").to be_nil
      expect(b.text "externalid").to be_nil

      i = REXML::XPath.first b, "billitems/lineitem"
      expect(i.text "projectid").to be_nil
      expect(i.text "itemid").to be_nil
      expect(i.text "classid").to be_nil
    end

    it "uses created date as posting date for Canada" do
      payable.company = "vcu"
      control_id, xml = subject.generate_payable_xml payable, "terms"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      b = REXML::XPath.first root, "/function/create_bill"

      posted = payable.created_at.in_time_zone "Eastern Time (US & Canada)"

      expect(b.text "dateposted/year").to eq posted.strftime "%Y"
      expect(b.text "dateposted/month").to eq posted.strftime "%m"
      expect(b.text "dateposted/day").to eq posted.strftime "%d"
    end
  end

  describe "generate_dimension_get" do

    it "creates xml to retrieve a Broker File dimension value" do
      control_id, xml = subject.generate_dimension_get "Broker File", "val"

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
      control_id, xml = subject.generate_dimension_get "Freight File", "val"

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
      expect{ subject.generate_dimension_get "blah", "val"}.to raise_error "Unable to create request for unknown dimension type blah."
    end
  end

  describe "generate_dimension_create" do

    it "creates xml to create a Broker File" do
      control_id, xml = subject.generate_dimension_create "Broker File", "id", "val"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      create = REXML::XPath.first root, "create_class"

      expect(create.text "classid").to eq "id"
      expect(create.text "name").to eq "val"
    end

    it "creates xml to create a Freight File" do
      control_id, xml = subject.generate_dimension_create "Freight File", "id", "val"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      create = REXML::XPath.first root, "create_project"

      expect(create.text "projectid").to eq "id"
      expect(create.text "name").to eq "val"
      expect(create.text "projectcategory").to eq "Internal Billable"
    end

    it "raises an error if an unknown dimension_type is used" do
      expect{ subject.generate_dimension_create "blah", "id", "val"}.to raise_error "Unable to generate create request for unknown dimension type blah."
    end
  end

  describe "generate_get_object_fields" do

    it "creates xml to retrieve object fields" do
      control_id, xml = subject.generate_get_object_fields "MyObject", "MyKey", "field1", "field2"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      g = REXML::XPath.first root, "get"

      expect(g.attributes["object"]).to eq "MyObject"
      expect(g.attributes["key"]).to eq "MyKey"
      
      field_text = REXML::XPath.each(g, "fields/field").map {|e| e.text}

      expect(field_text.size).to eq(2)
      expect(field_text).to include "field1"
      expect(field_text).to include "field2"
    end

    it "gets objects with all fields" do
      control_id, xml = subject.generate_get_object_fields "MyObject", "MyKey"

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      g = REXML::XPath.first root, "get"

      expect(g.attributes["object"]).to eq "MyObject"
      expect(g.attributes["key"]).to eq "MyKey"

      expect(REXML::XPath.each(g, "fields/field").size).to eq(0)
    end
  end

  describe "generate_check_gl_entry_xml" do

    let (:check) {
      IntacctCheck.new vendor_number: "v", bill_number: "b", vendor_reference: "ref", currency: "cur", gl_account: "a", 
                    amount: BigDecimal.new("12"), location: "loc", line_of_business: "lob", freight_file: "f", customer_number: "c", 
                    broker_file: "brok", check_number: "123", bank_number: "bank", check_date: Date.new(2014, 4, 1), bank_cash_gl_account: "cash"
    }

    it "generates xml for check entries" do
      control_id, xml = subject.generate_check_gl_entry_xml check
      expect(xml).to_not be_nil

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      g = REXML::XPath.first root, "/function/create_gltransaction"

      expect(g.text "journalid").to eq "GLAC"
      expect(g.text "datecreated/year").to eq check.check_date.strftime "%Y"
      expect(g.text "datecreated/month").to eq check.check_date.strftime "%m"
      expect(g.text "datecreated/day").to eq check.check_date.strftime "%d"
      expect(g.text "description").to eq check.check_number
      expect(g.text "referenceno").to eq check.bill_number

      expect(REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements.size).to eq(2)

      e = REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements[1]
      expect(e.text "trtype").to eq "credit"
      expect(e.text "amount").to eq check.amount.to_s
      expect(e.text "glaccountno").to eq check.bank_cash_gl_account
      expect(e.text "document").to eq check.check_number
      expect(e.text "datecreated/year").to eq check.check_date.strftime "%Y"
      expect(e.text "datecreated/month").to eq check.check_date.strftime "%m"
      expect(e.text "datecreated/day").to eq check.check_date.strftime "%d"
      expect(e.text "memo").to eq check.vendor_number + " - " + check.vendor_reference
      expect(e.text "locationid").to eq check.location
      expect(e.text "departmentid").to eq check.line_of_business
      expect(e.text "customerid").to eq check.customer_number
      expect(e.text "vendorid").to eq check.vendor_number
      expect(e.text "projectid").to eq check.freight_file
      expect(e.text "classid").to eq check.broker_file
      expect(e.text "currency").to eq check.currency
      expect(e.text "exchratedate/year").to eq check.check_date.strftime "%Y"
      expect(e.text "exchratedate/month").to eq check.check_date.strftime "%m"
      expect(e.text "exchratedate/day").to eq check.check_date.strftime "%d"
      expect(e.text "exchratetype").to eq "Intacct Daily Rate"

      e = REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements[2]

      expect(e.text "trtype").to eq "debit"
      expect(e.text "amount").to eq check.amount.to_s
      expect(e.text "glaccountno").to eq check.gl_account
      expect(e.text "document").to eq check.check_number
      expect(e.text "datecreated/year").to eq check.check_date.strftime "%Y"
      expect(e.text "datecreated/month").to eq check.check_date.strftime "%m"
      expect(e.text "datecreated/day").to eq check.check_date.strftime "%d"
      expect(e.text "memo").to eq check.vendor_number + " - " + check.vendor_reference
      expect(e.text "locationid").to eq check.location
      expect(e.text "departmentid").to eq check.line_of_business
      expect(e.text "customerid").to eq check.customer_number
      expect(e.text "vendorid").to eq check.vendor_number
      expect(e.text "projectid").to eq check.freight_file
      expect(e.text "classid").to eq check.broker_file
      expect(e.text "currency").to eq check.currency
      expect(e.text "exchratedate/year").to eq check.check_date.strftime "%Y"
      expect(e.text "exchratedate/month").to eq check.check_date.strftime "%m"
      expect(e.text "exchratedate/day").to eq check.check_date.strftime "%d"
      expect(e.text "exchratetype").to eq "Intacct Daily Rate"
    end

    it "generates xml for voided check entries" do
      check.amount = -check.amount
      control_id, xml = subject.generate_check_gl_entry_xml check
      
      root = REXML::Document.new(xml).root
      expect(REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements.size).to eq(2)

      e = REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements[1]
      expect(e.text "trtype").to eq "credit"
      expect(e.text "amount").to eq check.amount.abs.to_s
      expect(e.text "glaccountno").to eq check.gl_account

      e = REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements[2]

      expect(e.text "trtype").to eq "debit"
      expect(e.text "amount").to eq check.amount.abs.to_s
      expect(e.text "glaccountno").to eq check.bank_cash_gl_account
    end

    it "excludes certain blank fields" do
      check.freight_file = nil
      check.broker_file = nil
      check.vendor_reference = nil

      control_id, xml = subject.generate_check_gl_entry_xml check
      expect(xml).to_not be_nil

      root = REXML::Document.new(xml).root
      e = REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements[1]
      expect(e.text "trtype").to eq "credit"
      expect(e.text "projectid").to be_nil
      expect(e.text "itemid").to be_nil
      expect(e.text "classid").to be_nil
      expect(e.text "memo").to be_nil

      e = REXML::XPath.first(root, "/function/create_gltransaction/gltransactionentries").elements[2]
      expect(e.text "trtype").to eq "debit"
      expect(e.text "projectid").to be_nil
      expect(e.text "itemid").to be_nil
      expect(e.text "classid").to be_nil
      expect(e.text "memo").to be_nil
    end
  end

  describe "generate_ap_adjustment" do
    let (:check) {
      IntacctCheck.new vendor_number: "v", bill_number: "b", vendor_reference: "ref", currency: "cur", gl_account: "a", 
        amount: BigDecimal.new("12"), location: "loc", line_of_business: "lob", freight_file: "f", customer_number: "c", 
        broker_file: "brok", check_number: "123", bank_number: "bank", check_date: Date.new(2014, 4, 1), bank_cash_gl_account: "cash"
    }

    it "generates adjustment xml for a check without a payable" do
      control_id, xml = subject.generate_ap_adjustment check, nil
      expect(xml).to_not be_nil

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      g = REXML::XPath.first root, "/function/create_apadjustment"

      expect(g.text "vendorid").to eq check.vendor_number
      expect(g.text "datecreated/year").to eq check.check_date.strftime "%Y"
      expect(g.text "datecreated/month").to eq check.check_date.strftime "%m"
      expect(g.text "datecreated/day").to eq check.check_date.strftime "%d"
      expect(g.text "dateposted/year").to eq check.check_date.strftime "%Y"
      expect(g.text "dateposted/month").to eq check.check_date.strftime "%m"
      expect(g.text "dateposted/day").to eq check.check_date.strftime "%d"
      expect(g.text "adjustmentno").to eq "#{check.bill_number}-#{check.check_number}"
      expect(g.text "billno").to eq check.bill_number
      expect(g.text "description").to eq "Check # #{check.check_number} / Check Date #{check.check_date.strftime("%Y-%m-%d")}"
      expect(g.text "basecurr").to eq check.currency
      expect(g.text "currency").to eq check.currency
      expect(g.text "exchratedate/year").to eq check.check_date.strftime "%Y"
      expect(g.text "exchratedate/month").to eq check.check_date.strftime "%m"
      expect(g.text "exchratedate/day").to eq check.check_date.strftime "%d"
      expect(g.text "exchratetype").to eq "Intacct Daily Rate"

      e = REXML::XPath.first(root, "/function/create_apadjustment/apadjustmentitems").elements[1]

      expect(e.text "glaccountno").to eq check.gl_account
      expect(e.text "amount").to eq (check.amount * -1).to_s
      expect(e.text "memo").to eq "Check Adjustment"
      expect(e.text "locationid").to eq check.location
      expect(e.text "departmentid").to eq check.line_of_business
      expect(e.text "projectid").to eq check.freight_file
      expect(e.text "customerid").to eq check.customer_number
      expect(e.text "vendorid").to eq check.vendor_number
      expect(e.text "classid").to eq check.broker_file
    end

    it "generates adjustment xml for a check with a payable" do
      payable = IntacctPayable.new bill_date: Date.new(2015, 1, 1)

      control_id, xml = subject.generate_ap_adjustment check, payable
      expect(xml).to_not be_nil

      root = REXML::Document.new(xml).root
      validate_control_id root, control_id

      g = REXML::XPath.first root, "/function/create_apadjustment"

      expect(g.text "vendorid").to eq check.vendor_number
      expect(g.text "datecreated/year").to eq "2015"
      expect(g.text "datecreated/month").to eq "01"
      expect(g.text "datecreated/day").to eq "01"
      expect(g.text "dateposted/year").to eq "2015"
      expect(g.text "dateposted/month").to eq "01"
      expect(g.text "dateposted/day").to eq "01"
      expect(g.text "adjustmentno").to eq "#{check.bill_number}-#{check.check_number}"
      expect(g.text "billno").to eq check.bill_number
      expect(g.text "description").to eq "Check # #{check.check_number} / Check Date #{check.check_date.strftime("%Y-%m-%d")}"
      expect(g.text "basecurr").to eq check.currency
      expect(g.text "currency").to eq check.currency
      expect(g.text "exchratedate/year").to eq check.check_date.strftime "%Y"
      expect(g.text "exchratedate/month").to eq check.check_date.strftime "%m"
      expect(g.text "exchratedate/day").to eq check.check_date.strftime "%d"
      expect(g.text "exchratetype").to eq "Intacct Daily Rate"

      e = REXML::XPath.first(root, "/function/create_apadjustment/apadjustmentitems").elements[1]

      expect(e.text "glaccountno").to eq check.gl_account
      expect(e.text "amount").to eq (check.amount * -1).to_s
      expect(e.text "memo").to eq "Advanced Check Adjustment"
      expect(e.text "locationid").to eq check.location
      expect(e.text "departmentid").to eq check.line_of_business
      expect(e.text "projectid").to eq check.freight_file
      expect(e.text "customerid").to eq check.customer_number
      expect(e.text "vendorid").to eq check.vendor_number
      expect(e.text "classid").to eq check.broker_file
    end

    it "appends a Void to adjustmentno for voided checks" do
      check.amount = -1

      control_id, xml = subject.generate_ap_adjustment check, nil
      root = REXML::Document.new(xml).root
      g = REXML::XPath.first root, "/function/create_apadjustment"
      expect(g.text "adjustmentno").to eq "#{check.bill_number}-#{check.check_number}-Void"
    end
  end

  describe "generate_read_query" do
    it "builds xml" do
      control_id, xml = subject.generate_read_query 'obj', 1
      root = REXML::Document.new(xml).root
      validate_control_id(root, control_id)
      expect(root.name).to eq "function"
      expect(root.text "read/object").to eq "obj"
      expect(root.text "read/keys").to eq "1"
    end

    it "handles fields" do
      control_id, xml = subject.generate_read_query 'obj', 1, fields: ["field1", "field2"]
      root = REXML::Document.new(xml).root
      expect(root.text "read/fields").to eq "field1,field2"
    end
  end

  describe "generate_read_by_query" do
    it "builds xml" do
      control_id, xml = subject.generate_read_by_query 'obj', "field = '1'"
      root = REXML::Document.new(xml).root
      validate_control_id(root, control_id)
      expect(root.name).to eq "function"
      expect(root.text "readByQuery/object").to eq "obj"
      expect(root.text "readByQuery/query").to eq "field = '1'"
    end

    it "handles fields and page_size" do
      control_id, xml = subject.generate_read_by_query 'obj', "field = '1'", fields: ["field1", "field2"], page_size: 20
      root = REXML::Document.new(xml).root
      expect(root.text "readByQuery/fields").to eq "field1,field2"
      expect(root.text "readByQuery/pagesize").to eq "20"
    end
  end

  describe "generate_read_more" do
    it "builds xml" do
      control_id, xml = subject.generate_read_more "result_id"
      root = REXML::Document.new(xml).root
      validate_control_id(root, control_id)
      expect(root.name).to eq "function"
      expect(root.text "readMore/resultId").to eq "result_id"
    end
  end

  describe "generate_ap_payment" do
    let (:payment) {
      described_class::IntacctApPayment.new("entity", "method", "request_method", "vendorid", "docno", "desc", Date.new(2018,12,30), "CUR", [])
    }

    let! (:payment_detail) {
      d = described_class::IntacctApPaymentDetail.new(1, 2, BigDecimal("50.00"))
      payment.payment_details << d
      d
    }

    it "builds xml" do
      control_id, xml = subject.generate_ap_payment payment
      root = REXML::Document.new(xml).root
      validate_control_id(root, control_id)
      expect(root.name).to eq "function"
      expect(root.text "create/APPYMT/FINANCIALENTITY").to eq "entity"
      expect(root.text "create/APPYMT/PAYMENTMETHOD").to eq "method"
      expect(root.text "create/APPYMT/PAYMENTREQUESTMETHOD").to eq "request_method"
      expect(root.text "create/APPYMT/VENDORID").to eq "vendorid"
      expect(root.text "create/APPYMT/DOCNUMBER").to eq "docno"
      expect(root.text "create/APPYMT/DESCRIPTION").to eq "desc"
      expect(root.text "create/APPYMT/PAYMENTDATE").to eq "12/30/2018"
      expect(root.text "create/APPYMT/CURRENCY").to eq "CUR"

      line = REXML::XPath.first root, "create/APPYMT/APPYMTDETAILS/appymtdetail"
      expect(line).not_to be_nil
      expect(line.text "RECORDKEY").to eq "1"
      expect(line.text "ENTRYKEY").to eq "2"
      expect(line.text "TRX_PAYMENTAMOUNT").to eq "50.0"
    end

    it "builds xml with credits" do
      payment_detail.bill_amount = nil
      payment_detail.credit_bill_record_no = 3
      payment_detail.credit_bill_line_id = 4
      payment_detail.credit_amount = BigDecimal("100")

      control_id, xml = subject.generate_ap_payment payment
      root = REXML::Document.new(xml).root
      line = REXML::XPath.first root, "create/APPYMT/APPYMTDETAILS/appymtdetail"
      expect(line).not_to be_nil
      expect(line.text "RECORDKEY").to eq "1"
      expect(line.text "ENTRYKEY").to eq "2"
      expect(line.text "TRX_PAYMENTAMOUNT").to be_nil
      expect(line.text "INLINEKEY").to eq "3"
      expect(line.text "INLINEENTRYKEY").to eq "4"
      expect(line.text "TRX_INLINEAMOUNT").to eq "100.0"
    end
  end
end