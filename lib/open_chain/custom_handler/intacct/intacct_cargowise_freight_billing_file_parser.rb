require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vandegrift/cargowise_xml_support'
require 'open_chain/custom_handler/intacct/intacct_billing_parser_support.rb'

module OpenChain; module CustomHandler; module Intacct; class IntacctCargowiseFreightBillingFileParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::Vandegrift::CargowiseXmlSupport
  include OpenChain::CustomHandler::Intacct::IntacctBillingParserSupport

  def self.parse data, _opts = {}
    self.new.parse(data)
  end

  def parse data, _opts = {}
    # Due to the way we utilize the billing file broker, the data can come into this method already as
    # a nokogiri xml document - this is to avoid double parsing, since some of these documents can be massive.
    doc = make_document(data)

    job_number = job_number(doc)
    inv_number = invoice_number(doc)

    inbound_file.add_identifier(:invoice_number, inv_number)
    inbound_file.add_identifier(:broker_reference, job_number)

    # This is here solely for the period of time where this code is deployed but should not
    # yet actually be processing freight billing files from Cargowise.  It's just a
    # backstop in case something gets through that shouldn't have so that it's not processed
    # and not sent to Intacct.  This backstop can be removed once Cargowise Freight Billing
    # goes 100% live (which should be Nov 1, 2020)
    unless MasterSetup.get.custom_feature?("Cargowise Freight Billing")
      inbound_file.add_reject_message "Cargowise Freight Billing has not been enabled."
      return
    end

    finalized_export = find_intacct_export(inv_number) do |export|
      invoice_type = determine_invoice_type(doc)

      populate_export(doc, export)

      # Cargowise invoicing is done such that payables are emitted in their own distinct invoice -
      # unlike CMUS which mixes payables and receivables together into a single brokerage invoice.
      # This means that each XML file will contain exactly 1 payable or receivable (never both).

      if invoice_type == :ar
        receivable = process_receivable(doc, export)
      elsif invoice_type == :ap
        payable = process_payable(doc, export)
      end

      # Don't finalize anything on the export if receivable or payable aren't present.
      # It means that there were rejections handling the data, likely just that the file
      # has already been processed.

      # If we don't finalize anything, then don't save the export and also return nil so that the
      # finalized_export variable evaluates to nil and we don't attempt to push the export to Intacct
      if receivable.present? || payable.present?
        finalize_export(export, receivable, payable)
        export.save!
        export
      end
    end

    OpenChain::CustomHandler::Intacct::IntacctDataPusher.delay.push_billing_export_data(finalized_export.id) if finalized_export.present?

    nil
  end

  def make_document data
    document = data.is_a?(Nokogiri::XML::Document) ? data : xml_document(data)
    unwrap_document_root(document)
  end

  private

    def find_intacct_export invoice_number
      export = nil
      Lock.acquire("IntacctAllianceExport-#{invoice_number}") do
        export = IntacctAllianceExport.where(file_number: invoice_number, export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE)
                                      .first_or_create!(data_requested_date: Time.zone.now)
      end

      e = nil
      Lock.db_lock(export) do
        e = yield export
      end

      e
    end

    def populate_export xml, export
      export.division = translate_division_number(et(xml, "UniversalTransaction/TransactionInfo/Department/Code"))
      export.invoice_date = parse_date(et(xml, "UniversalTransaction/TransactionInfo/CreateTime"))
      # Customer Number in this case refers to the Bill To account...which in the case of AP invoices is really
      # the logistics department (since they owe the money).
      # For AR invoices, the bill to is the actual customer account
      export.customer_number = customer_number(ofc_address_org_code(xml))
      export.broker_reference = broker_reference_number(xml)
      export.shipment_number = job_number(xml)

      # Shipment customer number is the primary customer account number on the actual shipment.  This can differ
      # from the customer number (bill to) because we might bill different customer divisions for a shipment
      # all of which are associated with one main customer account.  Also, in the case of "integrated customers"
      # (where there is intercompany billing for freight [freight bills brokerage then brokerge bills the customer directory for the
      # freight and all brokerage fees]), the customer (bill to) is going to be the Brokerage account code and we
      # also want to then track the main customer account code on these because it helps accounting to audit the
      # bill.
      shipment_customer_number_xpaths = shipment_relative_xpath("OrganizationAddressCollection/OrganizationAddress[AddressType = 'ConsigneeDocumentaryAddress']/OrganizationCode") # rubocop:disable Layout/LineLength
      shipment_customer_number_xpaths.each do |xpath|
        cust_no = et(xml, xpath)
        if cust_no.present?
          export.shipment_customer_number = customer_number(cust_no)
          break
        end
      end

      nil
    end

    def translate_division_number department_code
      case department_code.to_s.upcase
      when "FEA"
        "14" # Export Air
      when /FE.+/
        "13" # Export All Others
      when "FIA"
        "12" # Import Air
      when /FI.+/
        "11" # Import All Others
      end
    end

    def process_receivable xml, export
      receivable = nil
      process_journal_lines(xml) do |lines|
        inv_number = invoice_number(xml)

        receivable = find_existing_receivable(export.intacct_receivables, inv_number)
        if uploaded_to_intacct?(receivable)
          inbound_file.add_reject_message "Receivable #{inv_number} has already been sent to Intacct."
          return nil
        end

        if receivable.nil?
          receivable = export.intacct_receivables.create! invoice_number: inv_number
        else
          receivable.intacct_receivable_lines.destroy_all
        end

        receivable = populate_receivable(xml, lines, export, receivable)
      end

      receivable
    end

    def populate_receivable xml, lines, export, receivable
      # If for some reason we're reprocessing a billing file, we can clear any intacct errors that were already there.
      receivable.intacct_errors = nil
      receivable.company = translate_division_number_to_company(export.division)
      receivable.invoice_date = export.invoice_date
      receivable.customer_number = export.customer_number
      receivable.shipment_customer_number = export.shipment_customer_number

      job_no = job_number(xml)

      first_line = lines.first
      receivable.currency = et(first_line, "OSCurrency/Code")

      actual_charge_sum = BigDecimal("0")
      lines.each do |line|
        rl = receivable.intacct_receivable_lines.build

        rl.amount = parse_decimal(et(line, "OSTotalAmount"))
        actual_charge_sum += rl.amount if rl.amount
        rl.location = export.division
        rl.charge_code = et(line, "ChargeCode/Code")
        rl.charge_description = et(line, "Description")
        rl.broker_file = broker_reference_number(xml)
        rl.freight_file = job_no
        rl.line_of_business = "Freight"
      end

      if actual_charge_sum >= 0
        receivable.receivable_type = IntacctReceivable.create_receivable_type receivable.company, false
      else
        receivable.receivable_type = IntacctReceivable.create_receivable_type receivable.company, true
        # Credit Memos should have all credit lines as positive amounts.  The lines come to us
        # as negative amounts from Cargowise and the debits as postive amounts so we invert them.
        receivable.intacct_receivable_lines.each { |l| l.amount = (l.amount * -1) }
      end

      receivable.save!
      receivable
    end

    def process_payable xml, export
      # In cargowise, AP invoices are assembled completely distinct from AR invoicing and there is only a single
      # vendor per AP invoice (unlike in CMUS where an invoice can have both AR and AP lines as well as AP lines
      # to multiple distinct vendors)
      payable = nil
      process_journal_lines(xml) do |lines|
        vendor = vendor_number(ofc_address_org_code(xml))
        # We'll use the export's invoice number as the payables's bill number
        # We're creating a single payable per vendor that appears on the invoice
        bill_number = invoice_number(xml)
        payable = find_existing_payable(export.intacct_payables, vendor, bill_number)
        if uploaded_to_intacct?(payable)
          inbound_file.add_reject_message "Payable #{bill_number} to Vendor #{vendor} has already been sent to Intacct."
          return nil
        end

        if payable.nil?
          payable = export.intacct_payables.create! vendor_number: vendor, bill_number: bill_number, payable_type: IntacctPayable::PAYABLE_TYPE_BILL
        else
          payable.intacct_payable_lines.destroy_all
        end

        payable = populate_payable(xml, lines, export, payable)
      end

      payable
    end

    def populate_payable xml, lines, export, payable
      # If for some reason we're reprocessing a billing file, we can clear any intacct errors that were already there.
      payable.intacct_errors = nil
      payable.company = translate_division_number_to_company(export.division)
      first_line = lines.first
      payable.currency = et(first_line, "OSCurrency/Code")
      payable.bill_date = parse_date(et(xml, "UniversalTransaction/TransactionInfo/TransactionDate"))
      payable.vendor_reference = et(xml, "UniversalTransaction/TransactionInfo/Number")
      payable.shipment_customer_number = export.shipment_customer_number

      job_no = job_number(xml)

      lines.each do |line|
        pl = payable.intacct_payable_lines.build

        pl.charge_code = et(line, "ChargeCode/Code")
        pl.gl_account = gl_account(pl.charge_code)
        pl.amount = parse_decimal(et(line, "OSTotalAmount"))
        # Intacct's accounting system always wants to represent amounts in positive values in the
        # standard case. .ie if you owe $20 to a creditor, that should be sent as $20
        # Cargowise represents that as -$20...hence the -1 sign flip.  For reversals, we want negative amounts.
        pl.amount *= -1
        pl.charge_description = et(line, "Description")

        pl.location = export.division
        pl.line_of_business = "Freight"
        pl.customer_number = export.shipment_customer_number
        pl.broker_file = broker_reference_number(xml)
        pl.freight_file = job_no
      end

      payable.save!
      payable
    end

    def process_journal_lines xml
      lines = xpath(xml, "UniversalTransaction/TransactionInfo/PostingJournalCollection/PostingJournal")
      yield Array.wrap(lines)

      nil
    end

    def parse_boolean value
      return false if value.blank?

      value.downcase.strip == "true"
    end

    def invoice_number doc
      et(doc, 'UniversalTransaction/TransactionInfo/JobInvoiceNumber')
    end

    def job_number xml
      et(xml, 'UniversalTransaction/TransactionInfo/Job[Type = "Job"]/Key')
    end

    def translate_division_number_to_company division
      # The export division numbers (13, 14) should be under VFI, while the Import Freight numbers (11, 12)
      # should be under the LMD company
      if ["11", "12"].include? division
        "lmd"
      else
        "vfc"
      end
    end

    def shipment_relative_xpath relative_xpath
      shipment_portion = "UniversalTransaction/TransactionInfo/ShipmentCollection/Shipment"
      shipment_xpath = "#{shipment_portion}/#{relative_xpath}"
      subshipment_collection_xpath = "#{shipment_portion}/SubShipmentCollection/SubShipment/#{relative_xpath}"
      [shipment_xpath, subshipment_collection_xpath]
    end

    def broker_reference_number xml
      reference_number = nil
      shipment_relative_xpath("AdditionalReferenceCollection/AdditionalReference[Type/Code = 'OAG']/ReferenceNumber").each do |shipment_xpath|
        reference_number = et(xml, shipment_xpath)
        break if reference_number.present?
      end

      reference_number
    end

    def determine_invoice_type xml
      ledger = et(xml, "UniversalTransaction/TransactionInfo/Ledger")
      case ledger.upcase
      when "AP"
        :ap
      when "AR"
        :ar
      else
        raise "Unexpected ledger type #{ledger}."
      end
    end

    def ofc_address_org_code xml
      et(xml, "UniversalTransaction/TransactionInfo/OrganizationAddress[AddressType = 'OFC']/OrganizationCode")
    end

end; end; end; end