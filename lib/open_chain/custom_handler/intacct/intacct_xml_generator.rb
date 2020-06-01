require 'open_chain/xml_builder'
require 'digest/sha1'

module OpenChain; module CustomHandler; module Intacct; class IntacctXmlGenerator
  include OpenChain::XmlBuilder

  INTACCT_DIMENSION_XREF ||= {
    'Broker File' => 'class',
    'Freight File' => 'project'
  }.freeze

  # See https://developer.intacct.com/api/accounts-payable/ap-payments/#create-ap-payment
  IntacctApPayment ||= Struct.new(:financial_entity, :payment_method, :payment_request_method, :vendor_id, :document_number, :description, :payment_date, :currency, :payment_details)
  # If you want to add a "credit" to a payment (essentially mark a credit bill as being paid), then put the intacct apbill recordno in the credit_bill_record_no attribute
  # Otherwise, just put the apbill's intacct recordno as the bill_record_no and set the payment amount
  IntacctApPaymentDetail ||= Struct.new(:bill_record_no, :bill_line_id, :bill_amount, :credit_bill_record_no, :credit_bill_line_id, :credit_amount)

  def generate_receivable_xml receivable
    build_function("create_sotransaction") do |trans|
      add_element trans, "transactiontype", receivable.receivable_type
      add_date trans, "datecreated", receivable.invoice_date
      add_date trans, "dateposted", (receivable.canada? ? receivable.created_at.in_time_zone("Eastern Time (US & Canada)") : receivable.invoice_date)
      add_element trans, "customerid", receivable.customer_number
      add_element trans, "documentno", receivable.invoice_number
      add_element trans, "referenceno", receivable.customer_reference
      add_element trans, "currency", receivable.currency
      add_date trans, "exchratedate", receivable.invoice_date
      add_element trans, "exchratetype", "Intacct Daily Rate"

      if receivable.intacct_receivable_lines.size > 0
        lines = add_element trans, "sotransitems"

        receivable.intacct_receivable_lines.each do |l|
          xl = add_element lines, "sotransitem"

          add_element xl, "itemid", l.charge_code
          add_element xl, "quantity", 1
          add_element xl, "unit", "Each"
          add_element xl, "price", l.amount
          add_element xl, "locationid", l.location
          add_element xl, "departmentid", l.line_of_business
          add_element xl, "memo", l.charge_description
          add_element xl, "projectid", l.freight_file, allow_blank: false
          add_element xl, "customerid", receivable.customer_number
          add_element xl, "vendorid", l.vendor_number, allow_blank: false
          add_element xl, "classid", l.broker_file, allow_blank: false
        end
      end
    end
  end

  def generate_payable_xml payable, termname
    build_function("create_bill") do |bill|
      add_element bill, "vendorid", payable.vendor_number
      add_date bill, "datecreated", payable.bill_date
      add_date bill, "dateposted", (payable.canada? ? payable.created_at.in_time_zone("Eastern Time (US & Canada)") : payable.bill_date)
      add_element bill, "termname", termname
      add_element bill, "billno", payable.bill_number, allow_blank: false
      add_element bill, "externalid", payable.vendor_reference, allow_blank: false
      add_element bill, "currency", payable.currency
      add_date bill, "exchratedate", payable.bill_date
      add_element bill, "exchratetype", "Intacct Daily Rate"

      if payable.intacct_payable_lines.size > 0
        lines = add_element bill, "billitems"

        payable.intacct_payable_lines.each do |l|
          xl = add_element lines, "lineitem"

          add_element xl, "glaccountno", l.gl_account
          add_element xl, "amount", l.amount
          add_element xl, "memo", l.charge_description
          add_element xl, "locationid", l.location
          add_element xl, "departmentid", l.line_of_business
          add_element xl, "projectid", l.freight_file, allow_blank: false
          add_element xl, "customerid", l.customer_number
          add_element xl, "vendorid", payable.vendor_number
          add_element xl, "itemid", l.charge_code, allow_blank: false
          add_element xl, "classid", l.broker_file, allow_blank: false
        end
      end
    end
  end

  def generate_ap_adjustment check, payable
    build_function("create_apadjustment") do |adj|
      add_element adj, "vendorid", check.vendor_number
      add_date adj, "datecreated", (payable ? payable.bill_date : check.check_date)
      add_date adj, "dateposted", (payable ? payable.bill_date : check.check_date)
      # The Void is added to the adjustment number on voided checks (which come through as checks w/ a negative amount)
      # This is because there will already be an adjustment with the same number from when the check was initially cut
      add_element adj, "adjustmentno", "#{check.bill_number}-#{check.check_number}#{check.amount < 0 ? "-Void" : ""}"
      add_element adj, "billno", check.bill_number
      add_element adj, "description", "Check # #{check.check_number} / Check Date #{check.check_date.strftime("%Y-%m-%d")}"
      add_element adj, "basecurr", check.currency
      add_element adj, "currency", check.currency
      add_date adj, "exchratedate", check.check_date
      add_element adj, "exchratetype", "Intacct Daily Rate"

      adjustment = add_element adj, "apadjustmentitems"
      line = add_element adjustment, "lineitem"
      add_element line, "glaccountno", check.gl_account
      add_element line, "amount", (check.amount * -1)
      add_element line, "memo", "#{(payable ? "Advanced " : "")}Check Adjustment"
      add_element line, "locationid", check.location
      add_element line, "departmentid", check.line_of_business
      add_element line, "projectid", check.freight_file, allow_blank: false
      add_element line, "customerid", check.customer_number
      add_element line, "vendorid", check.vendor_number
      add_element line, "classid", check.broker_file, allow_blank: false
    end
  end

  def generate_check_gl_entry_xml check
    build_function("create_gltransaction") do |req|
      # This is the GL Journal for Alliance checks - the only system we actually send checks for
      # so this should be fine hardcoded here.
      add_element req, "journalid", "GLAC"
      add_date req, "datecreated", check.check_date
      add_element req, "description", check.check_number
      add_element req, "referenceno", check.bill_number

      items = add_element req, "gltransactionentries"

      append_gl_entry items, "credit", check
      append_gl_entry items, "debit", check
    end
  end

  def generate_dimension_get dimension_type, id
    build_function do |func|
      object_type = INTACCT_DIMENSION_XREF[dimension_type]
      raise "Unable to create request for unknown dimension type #{dimension_type}." unless object_type

      get_list = add_element func, "get_list"
      get_list.attributes["object"] = object_type
      get_list.attributes["maxitems"] = "1"

      filt = add_element get_list, "filter"
      expression = add_element filt, "expression"
      add_element expression, "field", "#{object_type}id"
      add_element expression, "operator", "="
      add_element expression, "value", id
    end
  end

  def generate_dimension_create dimension_type, id, value
    build_function do |func|
      object_type = INTACCT_DIMENSION_XREF[dimension_type]
      raise "Unable to generate create request for unknown dimension type #{dimension_type}." unless object_type

      create_dimension = add_element func, "create_#{object_type}"
      add_element create_dimension, "#{object_type}id", id
      add_element create_dimension, "name", value

      # The project dimension isn't just a simple xref in Intacct, although that's how we're currently using it
      if object_type == "project"
        add_element create_dimension, "projectcategory", "Internal Billable"
      end
    end
  end

  def generate_get_object_fields object_type, key, *fields
    build_function("get") do |get_obj|
      get_obj.attributes["object"] = object_type
      get_obj.attributes["key"] = key

      if fields.size > 0
        field_el = add_element get_obj, "fields"
        fields.each {|f| add_element field_el, "field", f}
      end
    end
  end

  # This method returns a full API object (.ie a single APBILL, APPayable, etc) from intacct
  # If you need more than one object, you need to utilize the #generate_read_by_query method and then
  # you can generate a read for each result returned.  See IntacctClient's #read_object method which
  # implements this pattern for reading muliple objects.
  def generate_read_query object_type, key, fields: nil
    build_function("read") do |query_element|
      add_element query_element, "object", object_type
      add_element query_element, "keys", key
      add_element(query_element, "fields", Array.wrap(fields).join(",")) if !fields.blank?
    end
  end

  # This is essentially a search function, returning only top level data for the object (no detail field)
  # Query is a SQL-like string # https://developer.intacct.com/web-services/queries/
  def generate_read_by_query object_type, query, fields: nil, page_size: nil
    build_function("readByQuery") do |query_element|
      add_element query_element, "object", object_type
      add_element(query_element, "fields", Array.wrap(fields).join(",")) if !fields.blank?
      add_element query_element, "query", query
      add_element(query_element, "pagesize", page_size) if page_size.to_i > 0
    end
  end

  def generate_read_more result_id
    build_function("readMore") do |more_element|
      add_element more_element, "resultId", result_id
    end
  end

  # ap_payment is expected to be an IntacctApPayment (see struct above)
  def generate_ap_payment ap_payment
    build_function("create") do |create|
      appmt = add_element create, "APPYMT"
      add_element(appmt, "FINANCIALENTITY", ap_payment.financial_entity)
      add_element(appmt, "PAYMENTMETHOD", ap_payment.payment_method)
      add_element(appmt, "PAYMENTREQUESTMETHOD", ap_payment.payment_request_method, allow_blank: false)
      add_element(appmt, "VENDORID", ap_payment.vendor_id)
      add_element(appmt, "DOCNUMBER", ap_payment.document_number)
      add_element(appmt, "DESCRIPTION", ap_payment.description)
      add_element(appmt, "PAYMENTDATE", ap_payment.payment_date.strftime("%m/%d/%Y"))
      add_element(appmt, "CURRENCY", ap_payment.currency)

      # Details are required, so I'm not even going to check if they're present, if there's
      # no details, this can fail hard.
      appmt_details = add_element(appmt, "APPYMTDETAILS")

      ap_payment.payment_details.each do |detail|
        d = add_element(appmt_details, "appymtdetail")
        if detail.bill_record_no
          add_element(d, "RECORDKEY", detail.bill_record_no)
          add_element(d, "ENTRYKEY", detail.bill_line_id)
          # Anything with a credit should never use the TRX_PAYMENTAMOUNT, but I actually want
          # this to bomb hard w/ an error from intacct if that happens, rather than protect it here
          # since it's possible the caller has the wrong expectation about how to credit a bill line
          # and the Intacct error will dispell that.
          add_element(d, "TRX_PAYMENTAMOUNT", detail.bill_amount, allow_blank: false)
        end

        if detail.credit_bill_record_no
          add_element(d, "INLINEKEY", detail.credit_bill_record_no)
          add_element(d, "INLINEENTRYKEY", detail.credit_bill_line_id)
          add_element(d, "TRX_INLINEAMOUNT", detail.credit_amount)
        end
      end
    end
  end

  private

    def build_function function_child_name = nil
      root = function_element
      if function_child_name
        child = add_element root, function_child_name
        yield child
      else
        yield root
      end

      control_id = nil
      if root.elements.size == 1
        # We're going to use the SHA-1 hash of the function contents to be able to seemlessly provide
        # indempotency on the function.
        control_id = add_control_id root, root.elements[1]
      end

      [control_id, stringify(root)]
    end

    def function_element
      doc, root = build_xml_document "function"
      root
    end

    def add_date parent_el, child_name, date
      child = add_element parent_el, child_name
      add_element child, "year", date.strftime("%Y")
      add_element child, "month", date.strftime("%m")
      add_element child, "day", date.strftime("%d")

      child
    end

    def add_control_id function_element, child_content
      control_id = Digest::SHA1.hexdigest(stringify(child_content))
      function_element.attributes["controlid"] = control_id
      control_id
    end

    def stringify element
      s = StringIO.new
      REXML::Formatters::Default.new.write(element, s)
      s.rewind
      s.read
    end

    def append_gl_entry parent, gl_entry_type, check
      gl = add_element parent, "glentry"

      add_element gl, "trtype", gl_entry_type
      # Writing directly to General Ledger...doesn't like negative amounts
      add_element gl, "amount", check.amount.abs

      # Credits need to go into the cash account when we're cutting a check. When voiding a check (.ie the amount is negative)
      # we need to put the cash back into the GL account it came from and debit it back out of the cash account.
      # The process is revserse for debit entry types
      if gl_entry_type == "credit"
        gl_account = ((check.amount >= 0) ? check.bank_cash_gl_account : check.gl_account)
      else
        gl_account = ((check.amount >= 0) ? check.gl_account : check.bank_cash_gl_account)
      end

      add_element gl, "glaccountno", gl_account
      add_element gl, "document", check.check_number
      add_date gl, "datecreated", check.check_date
      if !check.vendor_reference.blank?
        add_element gl, "memo", "#{check.vendor_number} - #{check.vendor_reference}"
      end
      add_element gl, "locationid", check.location
      add_element gl, "departmentid", check.line_of_business
      add_element gl, "customerid", check.customer_number
      add_element gl, "vendorid", check.vendor_number
      add_element gl, "projectid", check.freight_file, allow_blank: false
      add_element gl, "classid", check.broker_file, allow_blank: false
      add_element gl, "currency", check.currency
      add_date gl, "exchratedate", check.check_date
      add_element gl, "exchratetype", "Intacct Daily Rate"

      gl
    end

end; end; end; end