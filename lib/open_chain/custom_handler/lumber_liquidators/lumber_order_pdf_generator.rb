require 'open_chain/custom_handler/pdf_generator_support'
# Technically prawn/table isn't required to be require, but this class will fail HARD if it's not included and I wanted some
# concrete location in the code to reflect the dependency
require 'prawn/table'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderPdfGenerator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include ActionView::Helpers::NumberHelper
  include OpenChain::CustomHandler::PdfGeneratorSupport

  def self.carb_statement order
    if (order.order_date || order.created_at) <= Date.new(2017,8,31)
      "All Composite Wood Products contained in finished goods must be compliant to California 93120 Phase 2 for formaldehyde."
    else
      "All Composite Wood Products contained in finished goods must be TSCA Title VI Compliant and must be compliant with California Phase 2 formaldehyde emission standards (17 CCR 93120.2)"
    end
  end

  def self.create! order, user
    Tempfile.open(['foo', '.pdf']) do |file|
      existing_printout_count = order.attachments.where(attachment_type: "Order Printout").count

      file.binmode
      g = self.new
      g.render order, user, file
      Attachment.add_original_filename_method file, "order_#{order.order_number}_#{Time.now.strftime('%Y%m%d%H%M%S%L')}.pdf"
      att = order.attachments.new(attachment_type:'Order Printout')
      att.attached = file
      att.save!

      file.rewind
      g.email_pdf order, file, user, (existing_printout_count == 0)
    end
  end

  def initialize
    @cdefs = self.class.prep_custom_definitions([:prod_old_article, :cmp_purchasing_contact_email, :ordln_old_art_number, :ordln_part_name, :ord_change_log, :ordln_vendor_inland_freight_amount, :ordln_custom_article_description, :ord_total_freight, :ord_grand_total])
  end

  def render order, user, open_file_object
    # This document will be a standard 8 1/2" x 11" letter size with 1/2" margins (72 pts. per Inch)
    # We've added more bottom margin to force the table to wrap to a new page before the Terms and conditions stamp
    d = pdf_document(document_options: {margin: [36, 36, 72, 36]})

    page_width = d.bounds.width.to_f # w/ Letter (minus margins), this is 540
    page_height = d.bounds.height.to_f # w/ Letter (minus margins), this is 720
    box_margins = 6.0

    d.font_size = 8
    d.table([[{image: "app/assets/images/ll_logo.png", fit: [85, 40], position: :center}, "LUMBER LIQUIDATORS\n3000 John Deere Road\nToano, VA 23168 US", "Phone:   757-259-4280\nWebsite: <link href=\"http://www.lumberliquidators.com\">http://www.lumberliquidators.com</link>"]], width: page_width, cell_style: {inline_format: true}) do |t|
      t.cells.borders = []
      t.column(1).borders = [:left, :top, :bottom]
      t.column(2).borders = [:right, :top, :bottom]
      t.columns(1..2).border_width = 2
      t.columns(1..2).padding = 5
      t.column(0).padding_right = 10
    end

    d.move_down 10
    d.text "Purchase Order", size: 18, align: :center
    d.text v(order, user, :ord_ord_num), size: 18, align: :center

    y_pos = d.cursor

    caption_padding = 2 # This is the outer table's padding
    left_table_width = ((page_width / 2) - (box_margins / 2)).to_i - (caption_padding * 2)


    vendor_order_table = make_caption_table(d, "<b>Vendor Order Address</b>", address_lines(order, user, :ord_order_from_address_full_address), width: left_table_width, cell_style: {inline_format: true,  border_width: 0, padding: 1})
    vend_ship_from_table = make_caption_table(d, "<b>Vendor Ship From Address</b>", address_lines(order, user, :ord_ship_from_full_address), width: left_table_width, cell_style: {inline_format: true,  border_width: 0, padding: 1})

    d.table([[vendor_order_table], [vend_ship_from_table]], cell_style: {padding: caption_padding, height: 65}) do |t|
      t.row(0).borders = [:left, :top, :right]
      t.row(1).borders = [:left, :bottom, :right]
    end

    billing_address_table = make_caption_table(d, "<b>Billing Address</b>", lumber_billing_address, width: left_table_width, cell_style: {inline_format: true,  border_width: 0, padding: 1})
    ship_to_table = make_caption_table(d, "<b>Ship To Address</b>", ship_to_header_address(order, user), width: left_table_width, cell_style: {inline_format: true,  border_width: 0, padding: 1})

    d.move_down box_margins

    d.table([[billing_address_table], [ship_to_table]], cell_style: {padding: caption_padding, height: 65}) do |t|
      t.row(0).borders = [:left, :top, :right]
      t.row(1).borders = [:left, :bottom, :right]
    end

    d.move_cursor_to(y_pos)

    general_table = d.make_table(general_order_info(order, user), cell_style: {inline_format: true, padding: 1, height: 14, border_width: 0}) do |t|
      t.cells.border = []
      t.column(0).width = 115
      t.column(1).width = 145
    end

    d.indent((page_width / 2) + (box_margins / 2)) do
      general_caption = make_caption_table(d, "<b>General Information</b>", general_table, width: left_table_width, cell_style: {inline_format: true,  border_width: 0, padding: caption_padding})

      # This height is aligned with the height of the tables that comprise the left column
      d.table([[general_caption]], cell_style: {padding: caption_padding, height: 266})
    end

    d.move_down box_margins

    d.table(order_lines(order, user), header: true, width: page_width, cell_style: {inline_format: true}) do |t|
      t.row(0).font_style = :bold

      # Need to manually set widths when there's a ship to address, prawn has issues autosizing if we don't
      if self.class.multi_shipto?(order, user)
        t.column(1).width = 160
        t.column(2).width = 140
      end
    end

    d.formatted_text [{text: "\n", size: 8}, {text: self.class.carb_statement(order), styles: [:bold, :italic], color: "ff0000", size: 8}]
    
    # change log
    d.start_new_page
    d.formatted_text [
      {text: "Change Log\n\n", styles: [:bold], size: 14},
      {text: "#{order.custom_value(@cdefs[:ord_change_log])}".gsub("\t",Array.new(4,Prawn::Text::NBSP).join('')), size: 12}
    ]

    d.repeat(:all) do
      height = 33
      padding = 3
      d.bounding_box([0, -2], width: page_width, height: height) do
        d.stroke_bounds
        d.text_box terms_and_conditions, inline_format: true, at: [padding, height - padding], height: height-(2*padding), width: d.bounds.width - padding
      end
    end

    d.repeat(:all) do
      d.text_box "#{Time.now.utc.to_s} UTC", align: :right, at: [page_width - 85, -45], height: d.font_size + 2
    end

    add_page_numbers d, at: [(page_width / 2) - 25, -45]

    d.render open_file_object
    open_file_object.flush
  end

  def padded_bounding_box doc, *args
    box_opts = args.extract_options!
    padding = box_opts.delete(:padding).to_i
    doc.bounding_box(*args, box_opts) do
      doc.bounding_box([padding, doc.bounds.height - padding], width: doc.bounds.width-(2*padding), height: doc.bounds.height-(2*padding)) do
        yield
      end
    end
  end

  def address_lines order, user, model_field_uid
    address_lines = ModelField.find_by_uid(model_field_uid).process_export(order, user)
    if address_lines && address_lines.respond_to?(:join)
      address_lines[0] = "<b>" + address_lines[0] + "</b>"
      address_lines = address_lines.join("\n")
    else
      address_lines = address_lines.to_s
    end

    address_lines
  end

  def make_caption_table d, caption, body, table_opts
    d.make_table([[caption], [body]], table_opts) do |t|
      t.row(0).padding_left = 5
      t.row(0).height = d.font_size +  4
      t.row(0).background_color = "d3d3d3"

      yield t if block_given?
    end
  end

  def lumber_billing_address
    "<b>Lumber Liquidators Services, LLC</b>\nATTN: Accounts Payable\n3000 John Deere Rd\nToano, VA 23168 US"
  end

  def terms_and_conditions
    'The Purchase Order is subject to and incorporates by reference the Purchase Order Terms and Conditions located at <u><link href="http://www.llvendors.com">www.llvendors.com</link></u>. By accepting this Purchase Order, Seller agrees to be bound by the Purchase Order Terms and Conditions. The Terms and Conditions may not be modified, altered, amended or edited in any way without the express written consent of Lumber Liquidators\' Chief Merchandising Officer'
  end

  def ship_to_header_address order, user
    if self.class.multi_shipto?(order, user)
      "Multi-Stop"
    else
      if order.order_lines.length > 0
        address_lines(order.order_lines.first, user, :ordln_ship_to_full_address)
      else
        ""
      end
    end
  end

  def general_order_info order, user
    [
      ["<b>Issue Date</b>", v_date(order, user, :ord_ord_date)],
      ["<b>Planned Delivery Date</b>", v_date(order, user, :ord_first_exp_del)],
      ["<b>Ship Window Start</b>", v(order, user, :ord_window_start)],
      ["<b>Ship Window End</b>", v(order, user, :ord_window_end)],
      ["<b>Vendor No.</b>", v(order, user, :ord_ven_syscode)],
      ["<b>Vendor Name</b>", v(order, user, :ord_ven_name)],
      ["<b>Currency</b>", v(order, user, :ord_currency)],
      ["<b>Terms of Payment</b>", v(order, user, :ord_payment_terms)],
      ["<b>Terms of Delivery</b>", v(order, user, :ord_terms)],
      ["<b>Delivery Location</b>", v(order, user, :ord_fob_point)],
    ]
  end

  def v_date order, user, uid
    v = ModelField.find_by_uid(uid).process_export(order, user)
    v.nil? ? "" : v.strftime("%Y-%m-%d")
  end

  def v order, user, uid
    return '' unless order
    ModelField.find_by_uid(uid).process_export(order, user).to_s
  end

  def v_dec order, user, uid, opts = {}
    v = ModelField.find_by_uid(uid).process_export(order, user)
    format_number v
  end

  def format_number v, opts = {}
    opts = {precision: 5}.merge opts
    if v && v.is_a?(Numeric)
      v = number_with_delimiter(number_with_precision(v, opts))
    end

    # Strip trailing zeros, but only down to 2 decimal places
    v = v[0..-2] while v =~ /\.\d{2}\d*(0+)$/

    v
  end

  def self.multi_shipto? order, user
    ModelField.find_by_uid(:ord_ship_to_count).process_export(order, user).to_i > 1
  end

  def order_lines order, user
    multi_shipto = self.class.multi_shipto?(order, user)

    lines = [["Line Item", "Article", "Quantity", "UM", "Unit Price", "Net Amount"]]
    if multi_shipto
      lines[0].insert(2, "Ship To")
    end

    order.order_lines.each do |ol|
      line = []
      line << v(ol, user, :ordln_line_number)
      line << "<font size='7'>#{v(ol, user, :ordln_puid)}</font>\n#{v(ol, user, @cdefs[:ordln_old_art_number].model_field_uid)}\n#{v(ol, user, @cdefs[:ordln_part_name].model_field_uid)}"
      if multi_shipto
        line << address_lines(ol, user, :ordln_ship_to_full_address)
      end
      line << {content: v_dec(ol, user, :ordln_ordered_qty), align: :right}
      line << v(ol, user, :ordln_unit_of_measure)
      line << {content: v_dec(ol, user, :ordln_ppu), align: :right}
      line << {content: v_dec(ol, user, :ordln_total_cost), align: :right}

      lines << line

      custom_article_desc = ol.custom_value(@cdefs[:ordln_custom_article_description])
      if custom_article_desc
        lines << [{content: ""}, {content: custom_article_desc, colspan: (lines.first.size - 1)}]
      end
    end

    total_freight = order.custom_value(@cdefs[:ord_total_freight])
    if total_freight && total_freight > 0
      lines << [{content: "<b>Freight</b>", colspan: (lines.first.size - 1), align: :right}, {content: format_number(total_freight), align: :right}]
    end

    grand_total = order.custom_value(@cdefs[:ord_grand_total])
    if !grand_total
      # Orders received prior to June 2017 (or thereabouts) won't have a grand total custom definition.  Use the old total cost value.
      grand_total = ModelField.find_by_uid(:ord_total_cost).process_export(order, user)
    end
    lines << [{content: "<b>Total</b>", colspan: (lines.first.size - 1), align: :right}, {content: format_number(grand_total), align: :right}]

    lines
  end

  def email_pdf order, file, user, initial_pdf
    # See if there is a purchasing contact email for the vendor, if so, email it to that person.
    vendor = order.vendor
    contact_email = vendor ? v(vendor, user, @cdefs[:cmp_purchasing_contact_email].model_field_uid) : nil
    if !contact_email.blank?
      host = "https://#{MasterSetup.get.request_host}"
      subject = "Lumber Liquidators PO #{v(order, user, :ord_ord_num)} - #{initial_pdf ? "NEW" : "UPDATE"}"
      body = "You have received the attached purchase order from Lumber Liquidators.  If you have a VFI Track account, you may access the order at <a href=\"#{host}\">#{host}</a>".html_safe
      OpenMailer.send_simple_html(contact_email, subject, body, file).deliver!
    end
  end

end; end; end; end
