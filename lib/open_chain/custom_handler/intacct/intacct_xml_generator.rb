require 'open_chain/xml_builder'
require 'digest/sha1'

module OpenChain; module CustomHandler; module Intacct; class IntacctXmlGenerator
  include OpenChain::XmlBuilder

  INTACCT_DIMENSION_XREF ||= {
    'Broker File' => 'class',
    'Freight File' => 'project'
  }

  def generate_receivable_xml receivable
    build_function do |func|
      trans = add_element func, "create_sotransaction"
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
    build_function do |func|
      bill = add_element func, "create_bill"
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
    build_function do |func|
      adj = add_element func, "create_apadjustment"
      add_element adj, "vendorid", check.vendor_number
      add_date adj, "datecreated", payable.bill_date
      add_date adj, "dateposted", payable.created_at.in_time_zone("Eastern Time (US & Canada)")
      add_element adj, "adjustmentno", check.check_number
      add_element adj, "billno", check.bill_number
      add_element adj, "description", "Check # #{check.check_number} / Check Date #{check.check_date.strftime("%Y-%m-%d")}"
      add_element adj, "currency", check.currency
      add_date adj, "exchratedate", check.check_date
      add_element adj, "exchratetype", "Intacct Daily Rate"

      adjustment = add_element adj, "apadjustmentitems"
      line = add_element adjustment, "lineitem"
      add_element line, "glaccountno", check.gl_account
      add_element line, "amount", (check.amount * -1)
      add_element line, "memo", "Advanced check adjustment."
      add_element line, "locationid", check.location
      add_element line, "departmentid", check.line_of_business
      add_element line, "customerid", check.customer_number
      add_element line, "vendorid", check.vendor_number
      add_element line, "projectid", check.freight_file, allow_blank: false
      add_element line, "classid", check.broker_file, allow_blank: false
    end
  end

  def generate_check_gl_entry_xml check

    build_function do |func|
      req = add_element func, "create_gltransaction"
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
    build_function do |func|
      get_obj = add_element func, "get"
      get_obj.attributes["object"] = object_type
      get_obj.attributes["key"] = key

      if fields.size > 0
        field_el = add_element get_obj, "fields"
        fields.each {|f| add_element field_el, "field", f}
      end
    end
  end

  private

    def build_function 
      root = function_element
      yield root

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
      add_element gl, "amount", check.amount
      gl_account = (gl_entry_type == "credit" ? check.bank_cash_gl_account : check.gl_account)
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