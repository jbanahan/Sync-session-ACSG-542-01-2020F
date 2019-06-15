require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSapOrderXmlParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include OpenChain::IntegrationClientParser

  class OnShipmentError < StandardError; end

  VALID_ROOT_ELEMENTS ||= [
    '_-LUMBERL_-3PL_ORDERS05_EXT', #after June 2016
    'ORDERS05' #before June 2016
  ]  

  def self.parse_file data, log, opts={}
    self.new.parse_dom REXML::Document.new(data), opts
  end

  def self.integration_folder
    ["ll/_sap_po_xml", "/home/ubuntu/ftproot/chainroot/ll/_sap_po_xml"]
  end

  def parse_dom dom, opts = {}
    root = dom.root
    inbound_file.error_and_raise "Incorrect root element #{root.name}, expecting '#{VALID_ROOT_ELEMENTS.join(', ')}'." unless VALID_ROOT_ELEMENTS.include?(root.name)

    base = REXML::XPath.first(root,'IDOC')

    # order header info
    order_header = REXML::XPath.first(base,'E1EDK01')
    order_number = et(order_header,'BELNR')
    vendor_system_code = et(order_header,'RECIPNT_NO')

    # envelope info
    envelope = REXML::XPath.first(root,'//IDOC/EDI_DC40')
    ext_time = extract_time(envelope)

    inbound_file.company = importer
    inbound_file.add_identifier :po_number, order_number

    order = nil

    begin
      @first_expected_delivery_date = nil
      vend = find_vendor(importer, vendor_system_code)
      order = find_order(order_number, importer, ext_time) do |o|
        inbound_file.set_identifier_module_info :po_number, Order, o.id

        o.last_file_bucket = opts[:bucket]
        o.last_file_path = opts[:key]

        o.customer_order_number = o.order_number
        o.vendor = vend
        o.order_date = order_date(base)
        o.currency = et(order_header,'CURCY')
        # The method for calculating payment terms was much more complicated prior to proj. 1230.  Per 1230
        # requirements, it was supposed to be retained "for possible future use in calculating the payment date".
        # Should that ever be the case, it's in the repository in revisions of this file older than 06/2017.
        #o.terms_of_payment = REXML::XPath.first(base, './E1EDK01/_-LUMBERL_-ZTERM_DESCRIPTION/ZTERM_TXT').try(:text)
        o.terms_of_payment = payment_terms_description(base)
        terms_of_sale = ship_terms(base)
        o.terms_of_sale = terms_of_sale unless terms_of_sale.blank?
        o.order_from_address = order_from_address(base,vend)
        o.fob_point = fob_point base

        header_ship_to = ship_to_address(base,importer)

        order_lines_processed = []
        REXML::XPath.each(base,'./E1EDP01') {|el| order_lines_processed << process_line(o, el, importer, header_ship_to).line_number.to_i}
        # Look for existing order lines that are not present in the current XML and deal with them.
        o.order_lines.each {|ol|
          if !order_lines_processed.include?(ol.line_number.to_i)
            # If the line is on a shipment already, we can't delete it.  Instead, its quantity should be zeroed and
            # its deleted flag flipped to true.  This represents a "soft delete."  If the order line has no shipment
            # connection, it can simply be deleted, however.  There's no need to keep it around.
            if (!ol.booking_lines.empty? || !ol.shipment_lines.empty?)
              ol.quantity = 0
              ol.update_custom_value!(cdefs[:ordln_deleted_flag], true)
            else
              ol.mark_for_destruction
            end
          end
        }

        o.save!
        o.update_custom_value!(cdefs[:ord_assigned_agent],assigned_agent(o))
        o.update_custom_value!(cdefs[:ord_type],et(order_header,'BSART'))
        o.update_custom_value!(cdefs[:ord_sap_extract],ext_time)
        buyer_name, buyer_phone = buyer_info(base)
        o.update_custom_value!(cdefs[:ord_buyer_name],buyer_name)
        o.update_custom_value!(cdefs[:ord_buyer_phone],buyer_phone)
        o.associate_vendor_and_products! user

        set_header_totals_from_lines o
        set_header_dates_from_lines(base,o)

        o.save!

        o.reload
        validate_line_totals(o, base)

        setup_folders o
        o.create_snapshot(user, nil, opts[:key])
        o
      end
    rescue OnShipmentError
      # mailer here
      send_on_shipment_error dom, order_number, $!.message
    end
  end


  def find_vendor importer, vendor_system_code
    vend = nil
    Lock.acquire("Vendor-#{vendor_system_code}") do
      # creating the vendor shell record if needed and putting the SAP code as the name since we don't have anything better to use
      vend = Company.where(system_code:vendor_system_code).first_or_create!(vendor:true,name:vendor_system_code)
      importer.linked_companies << vend unless importer.linked_companies.include?(vend)
    end
    vend
  end

  def send_on_shipment_error dom, order_number, message
    Tempfile.open(["ll_sap_order-#{order_number}",'.xml']) do |f|
      f << dom.to_s
      f.flush
      subject = "Order #{order_number} XML rejected."
      body = "Order #{order_number} was rejected: #{message}"

      if MasterSetup.get.production?
        to = ['ll-support@vandegriftinc.com', 'POResearch@lumberliquidators.com']
      else
        to = ['ll-support@vandegriftinc.com']
      end

      to << Group.use_system_group("ORDER_REJECTED_EMAIL", name: "Order Rejected Email")
      
      OpenMailer.send_simple_html(to,subject,body,[f]).deliver_now
    end
  end

  def setup_folders order
    folder_list = [{folder_name: 'Quality', group_name: 'Quality', group_system_code: 'QUALITY' },
                   {folder_name: 'Lacey Docs', group_name: 'RO/Product Compliance', group_system_code: 'ROPRODCOMP'}]

    already_existing_folders = order.folders.map(&:name)
    folder_list.each do |f|
      if !already_existing_folders.include?(f[:folder_name])
        new_folder = order.folders.create!(name: f[:folder_name], created_by_id: user.id)
        new_folder.groups << Group.use_system_group(f[:group_system_code], name: f[:group_name])
      end
    end
    nil
  end

  def assigned_agent order
    linked_system_codes = Company.where("companies.id IN (SELECT parent_id FROM linked_companies WHERE child_id = ?)",order.vendor_id).pluck(:system_code)
    agent_codes = ['GELOWELL','RO','GS-EU','GS-US','GS-CA'] & linked_system_codes
    agent_codes.sort.join("/")
  end

  def set_header_totals_from_lines order
    total_freight = 0
    order.order_lines.each do |ol|
      freight = ol.custom_value(cdefs[:ordln_vendor_inland_freight_amount])
      if freight
        total_freight += freight
      end
    end
    order.update_custom_value!(cdefs[:ord_total_freight], total_freight)

    grand_total = ModelField.find_by_uid(:ord_total_cost).process_export(order, user) + total_freight
    order.update_custom_value!(cdefs[:ord_grand_total], grand_total)
  end

  def set_header_dates_from_lines base, order
    avail_to_promise_dates = []
    REXML::XPath.each(base,'./E1EDP01/E1EDP20/EDATU') do |el|
      avail_to_promise_dates << el.text unless el.text.blank?
    end
    avail_to_promise = avail_to_promise_dates.sort.first
    order.update_custom_value!(cdefs[:ord_avail_to_prom_date],avail_to_promise)

    mapping = {
      'VN_EXPEC_DLVD' => [],
      'VN_SHIPBEGIN' => [],
      'VN_SHIPEND' => [],
      'CURR_ARRVD' => [],
      'ACT_SHIP_DATE' => [],
      'VN_HNDDTE' => []
    }
    date_elements = REXML::XPath.match(base,'./E1EDP01/E1EDP20/_-LUMBERL_-PO_SHIP_WINDOW')

    if !date_elements.blank? && has_a_valid_date?(date_elements)
      date_elements.each do |el|
        el.each_element do |child|
          a = mapping[child.name]
          next if a.nil?
          txt = child.text
          a << txt if valid_new_date?(txt)
        end
      end
      # update mapping to get the earliest for each date or nil if the date wasn't sent
      mapping.each {|k,v| mapping[k] = mapping[k].sort.first}

      # set legacy dates if we didn't get a VN_EXPEC_DLVD
      if mapping['VN_EXPEC_DLVD'].blank?
        set_ship_window(order)
        return
      end

      order.first_expected_delivery_date = mapping['CURR_ARRVD']
      if order.first_expected_delivery_date.blank?
        if !mapping['VN_HNDDTE'].blank? && !mapping['VN_HNDDTE'].match(/^0*$/)
          order.first_expected_delivery_date = avail_to_promise
        else
          order.first_expected_delivery_date = mapping['VN_EXPEC_DLVD']
        end
      end
      order.ship_window_start = mapping['VN_SHIPBEGIN']
      order.ship_window_end = mapping['VN_SHIPEND']
      order.update_custom_value!(cdefs[:ord_planned_expected_delivery_date],mapping['VN_EXPEC_DLVD'])
      order.update_custom_value!(cdefs[:ord_ship_confirmation_date],mapping['ACT_SHIP_DATE'])
      order.update_custom_value!(cdefs[:ord_sap_vendor_handover_date],mapping['VN_HNDDTE'])
    else # legacy PO before June 2016 date logic change
      set_ship_window(order)
    end
  end

  def has_a_valid_date? date_elements
    date_elements.find {|el|
      el.elements.find { |inner|
        valid_new_date?(inner.text)
      }
    }
  end
  def valid_new_date? txt
    !txt.blank? && !txt.match(/^0*$/)
  end

  # legacy behavior when ship window didn't come in XML
  def set_ship_window order
    matrix_columns = {
      '9444' => 0,
      '9701' => 1,
      '9445' => 2
    }
    ship_window_matrix = {
      '100003' => [40,40,38,7],
      '100006' => [24,24,17,7],
      '100013' => [40,40,38,7],
      '100021' => [27,27,26,7],
      '100024' => [27,27,26,7],
      '100032' => [24,24,38,7],
      '100037' => [41,41,27,7],
      '100038' => [24,24,52,7],
      '100045' => [27,27,26,7],
      '100049' => [27,27,26,7],
      '100066' => [16,16,3,7],
      '100113' => [41,41,19,7],
      '100116' => [41,41,19,7],
      '100121' => [41,41,19,7],
      '100127' => [41,41,19,7],
      '100128' => [41,41,19,7],
      '100129' => [41,41,19,7],
      '100130' => [41,41,19,7],
      '100131' => [41,41,19,7],
      '100132' => [40,40,25,7],
      '100133' => [41,41,19,7],
      '100134' => [45,45,24,7],
      '100135' => [41,41,19,7],
      '100136' => [41,41,19,7],
      '100137' => [40,40,25,7],
      '100139' => [40,40,18,7],
      '100140' => [37,37,21,7],
      '100141' => [37,37,21,7],
      '100142' => [48,48,31,7],
      '100143' => [41,41,19,7],
      '100144' => [37,37,21,7],
      '100146' => [48,48,31,7],
      '100156' => [41,41,19,7],
      '100161' => [0,0,0,0],
      '100166' => [41,41,19,7],
      '100167' => [41,41,19,7],
      '100168' => [41,41,19,7],
      '100169' => [41,41,19,7],
      '100170' => [37,37,18,7],
      '100171' => [41,41,19,7],
      '100173' => [41,41,19,7],
      '100176' => [41,41,19,7],
      '100182' => [37,37,18,7],
      '100186' => [37,37,22,7],
      '100196' => [41,41,19,7],
      '100197' => [41,41,19,7],
      '100198' => [41,41,19,7],
      '100199' => [41,41,19,7],
      '100201' => [41,41,19,7],
      '100202' => [41,41,19,7],
      '100205' => [24,24,38,7],
      '100206' => [27,27,26,7],
      '100211' => [24,24,17,7],
      '100216' => [24,24,38,7],
      '100217' => [27,27,26,7],
      '100221' => [27,27,26,7],
      '100222' => [41,41,19,7],
      '100226' => [31,31,27,7],
      '100227' => [24,24,17,7],
      '100228' => [24,24,38,7],
      '100231' => [31,31,27,7],
      '100232' => [41,41,19,7],
      '100236' => [0,0,0,0],
      '100237' => [24,24,17,7],
      '100238' => [24,24,17,7],
      '100239' => [37,37,21,7],
      '100241' => [27,27,26,7],
      '100242' => [42,42,30,7],
      '100243' => [41,41,19,7],
      '100244' => [40,40,38,7],
      '100245' => [0,0,0,0],
      '100246' => [37,37,21,7],
      '100251' => [24,24,17,7],
      '100252' => [41,41,19,7],
      '100256' => [41,41,19,7],
      '100261' => [41,41,19,7],
      '100266' => [45,45,26,7],
      '100267' => [31,31,27,7],
      '100268' => [41,41,19,7],
      '100271' => [41,41,19,7],
      '100276' => [41,41,19,7],
      '100277' => [41,41,19,7],
      '100278' => [40,40,20,7],
      '100281' => [31,31,27,7],
      '100286' => [41,41,19,7],
      '100291' => [27,27,26,7],
      '100292' => [27,27,26,7],
      '100293' => [24,24,52,7],
      '100296' => [34,34,30,7],
      '100301' => [27,27,26,7],
      '100302' => [41,41,19,7],
      '100306' => [41,41,19,7],
      '100311' => [38,38,31,7],
      '100316' => [41,41,20,7],
      '100317' => [34,34,30,7],
      '100321' => [0,0,0,0],
      '203260' => [0,0,0,0],
      '203938' => [41,41,19,7],
      '205300' => [0,0,0,0],
      '205938' => [24,24,38,7],
      '206811' => [37,37,21,7],
      '206816' => [37,37,18,7],
      '206850' => [41,41,19,7],
      '206916' => [37,37,18,7],
      '300007' => [41,41,19,7],
      '300010' => [0,0,0,0],
      '300016' => [37,37,22,7],
      '300025' => [41,41,19,7],
      '300026' => [45,45,26,7],
      '300035' => [41,41,19,7],
      '300040' => [27,27,41,7],
      '300051' => [37,37,18,7],
      '300053' => [41,41,19,7],
      '300075' => [37,37,22,7],
      '300076' => [41,41,19,7],
      '300078' => [46,46,19,7],
      '300079' => [37,37,21,7],
      '300080' => [41,41,19,7],
      '300081' => [48,48,31,7],
      '300085' => [39,39,17,7],
      '300086' => [41,41,19,7],
      '300088' => [40,40,25,7],
      '300089' => [41,41,19,7],
      '300090' => [41,41,19,7],
      '300093' => [41,41,19,7],
      '300094' => [40,40,25,7],
      '300095' => [40,40,25,7],
      '300100' => [43,43,33,7],
      '300106' => [24,24,38,7],
      '300108' => [40,40,25,7],
      '300111' => [40,40,25,7],
      '300112' => [0,0,0,0],
      '300115' => [0,0,0,0],
      '300116' => [48,48,31,7],
      '300118' => [18,18,36,7],
      '300119' => [22,22,34,7],
      '300121' => [16,16,36,7],
      '300131' => [29,29,33,7],
      '300142' => [43,43,33,7],
      '300143' => [24,24,25,7],
      '300144' => [40,40,18,7],
      '300165' => [41,41,19,7],
      '300168' => [29,29,33,7],
      '300175' => [41,41,19,7],
      '300180' => [0,0,0,0],
      '300190' => [43,43,33,7],
      '800472' => [0,0,0,0]
    }
    vendor_code = order.vendor.system_code[4,6]
    ship_to_codes = order.order_lines.collect {|ol| ol.ship_to ? ol.ship_to.system_code : nil}.compact.uniq
    use_defaults = true
    if ship_to_codes.length == 1
      matrix_row = ship_window_matrix[vendor_code]
      matrix_column = matrix_columns[ship_to_codes.first]
      if matrix_row && matrix_column
        order.ship_window_end = order.first_expected_delivery_date - (matrix_row[matrix_column] + 7).days
        order.ship_window_start = order.ship_window_end - 7.days
        use_defaults = false
      end
    end
    if use_defaults
      order.ship_window_start = order.first_expected_delivery_date
      order.ship_window_end = order.first_expected_delivery_date
    end
  end

  private

    def find_order order_number, importer, extract_time
      o = nil
      Lock.acquire("LUMBER-#{order_number}") do
        po = Order.where(order_number: order_number).first_or_create! importer: importer

        if process_file?(extract_time, po)
          o = po
        end
      end

      if o
        Lock.with_lock_retry(o) do
          if process_file?(extract_time, o)
            o = yield o
          end
        end
      end

      o
    end

    def process_file? extract_time, order
      previous_extract_time = order.custom_value(cdefs[:ord_sap_extract])

      # We only want to process the file if there was no previous process time, OR the current extract is after (or equal to) the previous time
      return previous_extract_time.nil? || extract_time.to_i >=  previous_extract_time.to_i
    end

    def validate_line_totals order, base_el
      expected_el = REXML::XPath.first(base_el,'E1EDS01/SUMME')
      return true if expected_el.nil?
      expected = BigDecimal(expected_el.text)
      actual = order.order_lines.inject(BigDecimal('0.00')) {|mem,ln| mem + BigDecimal(ln.quantity * (ln.price_per_unit.blank? ? 0 : ln.price_per_unit)).round(2)}
      inbound_file.reject_and_raise "Unexpected order total. Got #{actual.to_s}, expected #{expected.to_s}" unless expected == actual
    end

    def process_line order, line_el, importer, header_ship_to
      line_number = et(line_el,'POSEX').to_i

      ol = order.order_lines.find {|ord_line| ord_line.line_number==line_number}
      if !ol
        ol = order.order_lines.build(line_number:line_number,total_cost_digits:2)
      end

      product = find_product(line_el)
      qty = BigDecimal(et(line_el,'MENGE'),4)
      uom = convert_uom(et(line_el,'MENEE'))

      # price might not be sent.  If it is, use it to get the price_per_unit, otherwise clear the price
      price_per_unit = nil
      extended_cost_text = et(line_el,'NETWR')
      if !extended_cost_text.blank?
        extended_cost = BigDecimal(extended_cost_text,4)
        price_per_unit = extended_cost / qty
      end

      validate_line_not_changed(ol, product) if (!ol.booking_lines.empty? || !ol.shipment_lines.empty?)

      ol.price_per_unit = price_per_unit
      ol.product = product
      ol.quantity = qty
      ol.unit_of_measure = uom

      # There is a possibility these may change between runs. We do not want the part_name or old_article_number
      # to change once they are set.
      unless ol.custom_value(cdefs[:ordln_part_name]).present?
        ol.find_and_set_custom_value cdefs[:ordln_part_name], product.name
      end

      unless ol.custom_value(cdefs[:ordln_old_art_number]).present?
        ol.find_and_set_custom_value cdefs[:ordln_old_art_number], product.custom_value(cdefs[:prod_old_article])
      end

      exp_del = expected_delivery_date(line_el)
      if !@first_expected_delivery_date || (exp_del && exp_del < @first_expected_delivery_date)
        order.first_expected_delivery_date = exp_del
        @first_expected_delivery_date = exp_del
      end

      ol.ship_to = ship_to_address(line_el,importer)

      ol.ship_to = header_ship_to if ol.ship_to.nil?

      description = get_custom_article_description(line_el)
      if description.blank?
        # This is here exclusively to fix a initial deployment issue where blank article descriptions were
        # getting identified as changed as compared to nil ones (see the lumber_order_change_comparator's fingerprinting of OrderData)
        # Rather than changing the fingerprinting method and then have a bunch of things record as changed again, we'll only
        # set a blank string here if the value is already blank, otherwise we'll nil the field.
        if ol.custom_value(cdefs[:ordln_custom_article_description]) == ""
          description = ""
        else
          description = nil
        end
      end

      ol.find_and_set_custom_value cdefs[:ordln_custom_article_description], description
      ol.find_and_set_custom_value cdefs[:ordln_gross_weight_kg], gross_weight(line_el)
      ol.find_and_set_custom_value cdefs[:ordln_carb_statement], product_vendor_text(order, product, "CARB Statement")
      ol.find_and_set_custom_value cdefs[:ordln_patent_statement], product_vendor_text(order, product, "Patent Statement")

      # Default to false.  Although it's unlikely to actually happen, this prevents an "undeleted" line from being
      # stuck in "deleted" status.
      ol.find_and_set_custom_value cdefs[:ordln_deleted_flag], false

      inland_freight_el = get_inland_freight_element line_el
      if inland_freight_el
        inland_freight_amt = BigDecimal(et(inland_freight_el, 'BETRG'))
        ol.find_and_set_custom_value cdefs[:ordln_inland_freight_amount], inland_freight_amt
        vendor_number = REXML::XPath.first(inland_freight_el, '_-LUMBERL_-FREIGHT_COND_VEND/VN_FREIGHT_VNDR').try(:text)
        ol.find_and_set_custom_value cdefs[:ordln_inland_freight_vendor_number], vendor_number

        # Vendor inland freight amount is set only if the order's vendor matches the one in the file.
        # It'll either be the same value as inland freight amount or nil, depending on the vendor.  This field
        # is public, the other amount field is not.
        vendor_inland_freight_amt = vendor_number == order.vendor.system_code ? inland_freight_amt : nil
        ol.find_and_set_custom_value cdefs[:ordln_vendor_inland_freight_amount], vendor_inland_freight_amt
      end

      return ol
    end

    # Combines content from (potentially) several elements together as one description value.  The SAP system will
    # split descriptions longer than 70 characters in the file we receive to multiple elements.
    def get_custom_article_description line_el
      custom_article_desc = ''
      prev_line_separator = '='
      REXML::XPath.each(line_el, "E1EDPT1[TDID='F01']/E1EDPT2") do |custom_article_desc_el|
        custom_article_desc_line = et(custom_article_desc_el, 'TDLINE')
        if custom_article_desc_line && !custom_article_desc_line.strip.empty?
          # An asterisk or slash in the 'TDFORMAT' field indicate that a new line should be added between
          # the previous line and this one.  Any other character means that the two lines can be appended
          # with no separator char.
          if prev_line_separator && ('*' == prev_line_separator || '/' == prev_line_separator)
            custom_article_desc += "\n"
          end
          custom_article_desc += custom_article_desc_line.strip
          prev_line_separator = et(custom_article_desc_el, 'TDFORMAT')
        end
      end
      custom_article_desc
    end

    def get_inland_freight_element line_el
      # Codes ZHF2 and ZLF2 should be specific to inland info.
      REXML::XPath.first(line_el, "E1EDP05[KSCHL='ZHF2' or KSCHL='ZLF2']")
    end

    def validate_line_not_changed ol, product
      changed = false
      changed = true if ol.product != product
      # This error message is a bit vague, but the product change condition is supposedly not even allowed by SAP.
      # We opted to leave it alone, even after the number of checks this method did was reduced to one in 04/2018. - WBH
      inbound_file.reject_and_raise("Order Line #{ol.line_number} already on a shipment.", error_class:OnShipmentError) if changed
    end

    def find_product order_line_el
      product_base = REXML::XPath.first(order_line_el,'E1EDP19')
      prod_uid = et(product_base,'IDTNR')
      return Product.where(unique_identifier:prod_uid).first_or_create!(
        importer:importer,
        name:et(product_base,'KTEXT')
      )
    end

    def ship_terms base
      el = REXML::XPath.first(base,"./E1EDK17[QUALF = '001']")
      return nil unless el
      str = et(el,'LKOND')
      return str.blank? ? nil : str
    end

    def buyer_info base
      el = REXML::XPath.first(base,"./E1EDKA1[PARVW = 'AG']")
      return [nil,nil] unless el
      return [et(el,'BNAME'),et(el,'TELF1')]
    end

    def order_date base
      el = REXML::XPath.first(base,"./E1EDK03[IDDAT = '012']")
      return nil unless el
      str = et(el,'DATUM')
      return nil if str.blank?
      parse_date(str)
    end

    def order_from_address base, vendor
      vendor.addresses.where("system_code like '%-CORP'").first
    end

    def ship_to_address base, importer
      el = REXML::XPath.first(base,"./E1EDPA1[PARVW = 'WE']")
      el = REXML::XPath.first(base,"./E1EDKA1[PARVW = 'WE']") unless el
      return address(el,importer)
    end

    def address el, company
      return nil unless el
      my_addr = Address.new
      my_addr.company_id = company.id

      name1 = et(el,'NAME1')
      name2 = et(el,'NAME2')
      my_addr.name = name1.blank? ? name2 : name1

      my_addr.line_1 = et(el,'STRAS')
      my_addr.line_2 = et(el,'STRS2')
      my_addr.city = et(el,'ORT01')
      my_addr.state = et(el,'REGIO')
      my_addr.postal_code = et(el,'PSTLZ')

      country_iso = et(el,'LAND1')
      my_addr.country = Country.find_by_iso_code(country_iso) unless country_iso.blank?

      my_addr.system_code = et(el,'LIFNR')

      hk = Address.make_hash_key my_addr

      existing = company.addresses.find_by_address_hash hk

      return existing if existing

      my_addr.save!

      return my_addr
    end

    # expected delivery date can come from one of two places
    # if the CURR_ARRVD is populated, use that, otherwise use EDATU
    def expected_delivery_date base
      str = nil
      outer_el = REXML::XPath.first(base,"./E1EDP20")
      return nil unless outer_el
      el = REXML::XPath.first(outer_el,"./_-LUMBERL_-PO_SHIP_WINDOW")
      str = et(el,'CURR_ARRVD') if el
      str = et(outer_el,'EDATU') if str.blank? || str.match(/^0*$/)
      return nil if str.blank?
      parse_date(str)
    end

    def payment_terms_description base
      # Use the ZTERM element to determine if there a special term codes that we need to handle
      # outside of the standard path of parsing the terms elements into a terms description.
      # Special Terms don't have these elements.
      zterm = REXML::XPath.first(base, "./E1EDK01/ZTERM").try(:text)
      if special_payment_terms[zterm]
        special_payment_terms[zterm]
      elsif zterm.to_s =~ /^tt(\d+)$/i
        "T/T Net #{$1}"
      else
        elements = REXML::XPath.match(base,"./E1EDK18")

        # According to the doc from LL, If no E1DK18 is present, then order is due immediately.
        return "Due Immediately" unless elements.try(:size) > 0

        values = []
        elements.each do |el|
          days = et(el, 'TAGE')
          percent = et(el, 'PRZNT')

          next if days.blank?

          if percent.blank?
            values << "Net #{days}"
          else
            # Strip trailing insignificant digits
            if percent =~ /\.\d*[0]+$/
              percent.sub!(/0+$/, "")
              percent = percent[0..-2] if percent.ends_with?(".")
            end
            values << "#{percent}% #{days} Days"
          end
        end

        values.join(", ")
      end
    end

    def special_payment_terms
      {
        "TT00" => "T/T At Sight",
        "LC60" => "Letter of Credit 60 Days",
        "D001" => "T/T .5% 15 Days, Net 15",
        "D002" => "T/T 1% 15 Days, Net 15", 
        "D003" => "T/T .5% 15 Days, Net 60",
        "D004" => "T/T 1% 15 Days, Net 60",
        "D005" => "T/T .5% 15 Days, Net 45",
        "D006" => "T/T 1% 15 Days, Net 45",
        "TT90" => "T/T Net 90 days"
      }
    end

    def fob_point base
      REXML::XPath.first(base, "./E1EDK17/LKTEXT").try(:text)
    end

    def parse_date str
      return nil if str.match(/^0*$/)
      return Date.new(str[0,4].to_i,str[4,2].to_i,str[6,2].to_i)
    end

    def extract_time envelope_element
      date_part = et(envelope_element,'CREDAT')
      time_part = et(envelope_element,'CRETIM')

      # match ActiveSupport::TimeZone.parse
      formatted_date = "#{date_part[0,4]}-#{date_part[4,2]}-#{date_part[6,2]} #{time_part[0,2]}:#{time_part[2,2]}:#{time_part[4,2]}"

      ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse(formatted_date)
    end

    def convert_uom str
      vals = {'FTK'=>'FT2','FOT'=>'FT'}
      new_str = vals[str]
      new_str.blank? ? str : new_str
    end

    def gross_weight line_el
      weight = BigDecimal(et(line_el, 'BRGEW', true))
      uom = et(line_el, 'GEWEI')
      # If the provided weight is in
      if uom == 'LBR'
        weight = (weight * BigDecimal("0.453592"))
      end
      weight.round(3, BigDecimal::ROUND_HALF_UP)
    end

    def product_vendor_text order, product, text_type
      return nil unless order.vendor && order.order_date
      pva = product.product_vendor_assignments.where(vendor_id: order.vendor.id).first
      return nil unless pva
      pva.constant_text_for_date(text_type, reference_date: order.order_date).try(:constant_text)
    end

    def cdefs
      @cdefs ||= self.class.prep_custom_definitions [:ord_sap_extract, :ord_type, :ord_buyer_name, :ord_buyer_phone,
            :ord_planned_expected_delivery_date, :ord_ship_confirmation_date,
            :ord_sap_vendor_handover_date, :ord_avail_to_prom_date, :ord_assigned_agent,
            :ordln_part_name, :ordln_old_art_number, :prod_old_article, :ordln_custom_article_description,
            :ordln_inland_freight_amount, :ordln_vendor_inland_freight_amount, :ordln_inland_freight_vendor_number,
            :ord_total_freight, :ord_grand_total, :ordln_gross_weight_kg, :ordln_deleted_flag, :ordln_carb_statement, :ordln_patent_statement
          ]
    end

    def importer
      @importer ||= Company.where(master: true).first
    end

    def user
      @user ||= User.integration
    end

end; end; end; end
