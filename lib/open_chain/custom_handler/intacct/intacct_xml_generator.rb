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

  def generate_check_gl_entry_xml payable
    first_line = payable.intacct_payable_lines.first

    build_function do |func|
      req = add_element func, "create_gltransaction"
      # This is the GL Journal for Alliance checks - the only system we actually send checks for
      # so this should be fine hardcoded here.
      add_element req, "journalid", "GLAC"
      add_date req, "datecreated", first_line.check_date
      add_element req, "description", first_line.check_number
      add_element req, "referenceno", payable.bill_number

      items = add_element req, "gltransactionentries"
      payable.intacct_payable_lines.each do |l|
        # Each entry is a credit to the bank's cash account and a debit to the payable gl account
        append_gl_entry items, "credit", payable, l
        append_gl_entry items, "debit", payable, l
      end
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

    def append_gl_entry parent, gl_entry_type, payable, payable_line
      gl = add_element parent, "glentry"

      add_element gl, "trtype", gl_entry_type
      add_element gl, "amount", payable_line.amount
      gl_account = (gl_entry_type == "credit" ? payable_line.bank_cash_gl_account : payable_line.gl_account)
      add_element gl, "glaccountno", gl_account
      add_element gl, "document", payable_line.check_number
      add_date gl, "datecreated", payable_line.check_date
      add_element gl, "memo", "#{payable.vendor_number} - #{payable_line.charge_description}"
      add_element gl, "locationid", payable_line.location
      add_element gl, "departmentid", payable_line.line_of_business
      add_element gl, "customerid", payable_line.customer_number
      add_element gl, "vendorid", payable.vendor_number
      add_element gl, "projectid", payable_line.freight_file, allow_blank: false
      add_element gl, "itemid", payable_line.charge_code, allow_blank: false
      add_element gl, "classid", payable_line.broker_file, allow_blank: false
      add_element gl, "currency", payable.currency
      add_date gl, "exchratedate", payable_line.check_date
      add_element gl, "exchratetype", "Intacct Daily Rate"

      gl
    end

end; end; end; end