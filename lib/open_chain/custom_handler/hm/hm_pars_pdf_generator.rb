require 'open_chain/custom_handler/pdf_generator_support'
require 'prawn/table'
require 'barby'
require 'barby/barcode/code_39'
require 'barby/outputter/png_outputter'

module OpenChain; module CustomHandler; module Hm; class HmParsPdfGenerator
  extend OpenChain::CustomHandler::PdfGeneratorSupport

  def self.generate_pars_pdf pars_data, file
    doc = pdf_document
    generate_header_info(doc, pars_data)
    # Once we start putting barcodes in the actual document, the flag here can be removed (as can the extra code branch below for handling the flag)
    generate_pars_info(doc, pars_data, add_barcodes: false)

    add_page_numbers doc
    doc.render file
    file.flush
  end

  def self.generate_header_info d, pars_data
    # Find the first pars that has a date (they all should have them, but...whatever)
    data = pars_data.find {|d| !d.invoice_date.nil? }
    date = data.nil? ? "" : data.invoice_date.strftime("%Y-%m-%d")

    d.font_size = 6
    d.draw_text"Date of Departure:  #{date}", at: [0, 720]
    d.draw_text "Shipper Address:", at: [0, 700]
    d.draw_text "H&M", at: [0, 692]
    d.draw_text "281 AirTech Pkwy. Suite 191", at: [0, 684]
    d.draw_text "Plainfield, IN 46168", at: [0, 676]

    dest_x = 110
    d.draw_text "Destination Address:", at: [dest_x, 700]
    d.draw_text "Purolator International, Inc.", at: [dest_x, 692]
    d.draw_text "1151 Martin Grove Road", at: [dest_x, 684]
    d.draw_text "Etobicoke, ON M9W 0C1", at: [dest_x, 676]

    nil
  end


  def self.generate_pars_info d, pars_data, add_barcodes: false
    d.move_down 60
    table_data = [["Exporter", "Broker", "Commodity", "Cartons", "Weight", "Invoice ID", "PARS Number"]]
    total_cartons = 0
    total_weight = 0

    barcode_files = {}
    if add_barcodes
      pars_data.each do |pars|
        code = Barby::Code39.new(pars.pars_number.to_s.upcase)
        file = Tempfile.new([pars.pars_number.to_s, ".png"])
        file.binmode
        file.write code.to_png
        file.flush

        barcode_files[pars.pars_number.to_s] = file
      end
    end

    pars_data.each do |pars|

      if barcode_files[pars.pars_number.to_s]
        # An image cell in Prawn cannot contain anything other than an image...so in order to add the pars number
        # to the display, we need to make a subtable with the barcode as the top cell and the pars number as the bottom
        subtable_data = [[{image: barcode_files[pars.pars_number.to_s].path, position: :center, vposition: :center}], [pars.pars_number.to_s]]
        pars_cell = d.make_table(subtable_data, cell_style: {align: :center, borders: [], border_width: 0, padding: 1}) do |t|
          t.row(0).height = 123
          t.row(1).height = 8
        end
      else
        pars_cell = pars.pars_number.to_s
      end

      table_data << ["H & M", "Vandegrift Canada ULC", "Wearing Apparel & Accessories", pars.cartons.to_s, "#{pars.weight} KG", pars.invoice_number, pars_cell]
      total_cartons += pars.cartons if pars.cartons.to_f > 0
      total_weight += pars.weight if pars.weight.to_f > 0
    end

    table_data << [nil, nil, "Totals", total_cartons.to_s, "#{total_weight} KG", nil, nil]

    d.font_size = 6
    # When we add barcodes, I think we'll have to render them out to an image tempfile, then add them to the table as an image cell,
    # then clean them up.

    d.table(table_data, header: true, cell_style: {height: (barcode_files.size > 0 ? 135 : 80), align: :center}, width: 540) do |t|
      first_row = t.row(0)
      first_row.height = 16
      first_row.background_color = "d3d3d3"
      t.column(0).width = 32
      t.column(1).width = 73
      # Row 2 is the row we can potentially squeeze if we're printing barcodes
      if barcode_files.size == 0
        t.column(2).width = 94
      end
      t.column(3).width = 32
      t.column(4).width = 35
      t.column(5).width = 40
      # When we're printing barcodes, let column 6 take up as much space as it needs and we'll let it steal width from column 2 (the commodity column)

      last_row = t.row(-1)
      last_row.borders = []
      last_row.column(2).align = :right
      last_row.columns(3..4).borders = [:left, :right, :bottom]
      last_row.height = 16
    end

    nil
  ensure
    # Cleanup any barcode temp files...
    if barcode_files.try(:size) > 0
      barcode_files.values.each {|f| f.close! unless f.closed? }
    end
  end

end; end; end; end