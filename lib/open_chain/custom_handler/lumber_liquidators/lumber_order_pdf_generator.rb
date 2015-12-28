require 'prawn'
# Technically prawn/table isn't required to be require, but this class will fail HARD if it's not included and I wanted some
# concrete location in the code to reflect the dependency
require 'prawn/table' 

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderPdfGenerator
  include ActionView::Helpers::NumberHelper 

  def self.create! order, user
    Tempfile.open(['foo', '.pdf']) do |file|
      file.binmode
      self.new.render order, user, file
      Attachment.add_original_filename_method file, "order_#{order.order_number}_#{Time.now.strftime('%Y%m%d%H%M%S%L')}.pdf"
      att = order.attachments.new(attachment_type:'Order Printout')
      att.attached = file
      att.save!
    end
  end

  def render order, user, open_file_object
    # This document will be a standard 8 1/2" x 11" letter size with 1/2" margins (72 pts. per Inch)
    # We've added more bottom margin to force the table to wrap to a new page before the Terms and conditions stamp
    d = Prawn::Document.new page_size: "LETTER", margin: [36, 36, 72, 36]

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
    # TODO Figure out how to do a page counter

    y_pos = d.cursor

    caption_padding = 2 # This is the outer table's padding
    left_table_width = ((page_width / 2) - (box_margins / 2)).to_i - (caption_padding * 2)


    vendor_order_table = make_caption_table(d, "<b>Vendor Order Address</b>", address_lines(order, user, :ord_order_from_address_full_address), width: left_table_width, cell_style: {inline_format: true,  border_width: 0, padding: 1})
    vend_ship_from_table = make_caption_table(d, "<b>Vendor Ship From Address</b>", "As dictated by supplier reference manual, the manufacturer must ship from previously approved facilities.", width: left_table_width, cell_style: {inline_format: true,  border_width: 0, padding: 1})

    d.table([[vendor_order_table], [vend_ship_from_table]], cell_style: {padding: caption_padding}) do |t|
      t.row(0).borders = [:left, :top, :right]
      t.row(0).height = 65
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
      d.table([[general_caption]], cell_style: {padding: caption_padding, height: 238})
    end

    d.move_down box_margins

    d.table(order_lines(order, user), header: true, width: page_width, cell_style: {inline_format: true}) do |t|
      t.row(0).font_style = :bold

      # Need to manually set widths when there's a ship to address, prawn has issues autosizing if we don't
      if multi_shipto?(order, user)
        t.column(1).width = 160
        t.column(2).width = 140
      end
    end

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

    d.number_pages "<page> of <total>", width: 50, at: [(page_width / 2) - 25, -45], align: :center

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
    if multi_shipto?(order, user)
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
      ["<b>Ship Window</b>", "To be provided by freight forwarder"],
      ["<b>Vendor No.</b>", v(order, user, :ord_ven_syscode)],
      ["<b>Vendor Name</b>", v(order, user, :ord_ven_name)],
      ["<b>Currency</b>", v(order, user, :ord_currency)],
      ["<b>Terms of Payment</b>", v(order, user, :ord_payment_terms)],
      ["<b>Terms of Delivery</b>", v(order, user, :ord_terms)]
    ]
  end

  def v_date order, user, uid
    v = ModelField.find_by_uid(uid).process_export(order, user)
    v.nil? ? "" : v.strftime("%Y-%m-%d")
  end

  def v order, user, uid
    ModelField.find_by_uid(uid).process_export(order, user).to_s
  end

  def v_dec order, user, uid, opts = {}
    opts = {precision: 5}.merge opts
    v = ModelField.find_by_uid(uid).process_export(order, user)
    if v && v.is_a?(Numeric)
      v = number_with_delimiter(number_with_precision(v, opts))
    end

    # Strip trailing zeros, but only down to 2 decimal places
    v = v[0..-2] while v =~ /\.\d{2}\d*(0+)$/

    v
  end

  def multi_shipto? order, user
    ModelField.find_by_uid(:ord_ship_to_count).process_export(order, user).to_i > 1
  end

  def order_lines order, user
    multi_shipto = multi_shipto?(order, user)

    lines = [["Line Item", "Article", "Quantity", "UM", "Unit Price", "Net Amount"]]
    if multi_shipto
      lines[0].insert(2, "Ship To")
    end

    order.order_lines.each do |ol|
      line = []
      line << v(ol, user, :ordln_line_number)
      line << "<font size='7'>#{v(ol, user, :ordln_puid)}</font>\n#{v(ol, user, :ordln_pname)}"
      if multi_shipto
        line << address_lines(ol, user, :ordln_ship_to_full_address)
      end
      line << {content: v_dec(ol, user, :ordln_ordered_qty), align: :right}
      line << v(ol, user, :ordln_unit_of_measure)
      line << {content: v_dec(ol, user, :ordln_ppu), align: :right}
      line << {content: v_dec(ol, user, :ordln_total_cost), align: :right}

      lines << line
    end

    lines << [{content: "<b>Total</b>", colspan: (lines.first.size - 1), align: :right}, {content: v_dec(order, user, :ord_total_cost), align: :right}]

    lines
  end


end; end; end; end