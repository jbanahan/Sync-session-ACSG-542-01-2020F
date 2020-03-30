require 'open_chain/custom_handler/pdf_generator_support'
require 'combine_pdf'

module OpenChain; module CustomHandler; class CommercialInvoicePdfGenerator
  extend OpenChain::CustomHandler::PdfGeneratorSupport

  ADDRESS ||= Struct.new :name, :line_1, :line_2, :line_3

  # The PDF has much more data on it, but at this point, only data for a specific purpose is being
  # added.  Only fields the generator knows how to print are present.
  INVOICE ||= Struct.new :control_number, :exporter_reference, :exporter_address, :consignee_address, :terms, :origin, :destination,
                :local_carrier, :export_carrier, :port_of_entry, :lading_location, :export_date, :related, :duty_for, :date_of_sale,
                :total_packages, :total_gross_weight, :description_of_goods, :export_reason, :mode_of_transport, :containerized, :employee,
                :firm_address, :owner_agent, :invoice_total

  TEMPLATE_PATH ||= "config/templates/commercial_invoice_template.pdf"


  def self.render_content file, invoice
    pdf_template = nil
    # CombinePDF isn't a huge fan of the template we're using
    # It spits out some warnings that are basically useless, so silence them.
    # No need to have the appear in our stderr log (or on rspec test output)
    # The PDF still works fine.
    Kernel.silence_warnings do
      pdf_template = CombinePDF.load(TEMPLATE_PATH).pages[0]
    end

    prawn_pdf = render_invoice_content invoice
    pdf_content = CombinePDF.parse render_invoice_content(invoice)

    pdf_content.pages.each {|page| page << pdf_template }

    file << pdf_content.to_pdf(subject: "Commercial Invoice", producer: "#{MasterSetup.application_name}")

    nil
  end

  def self.render_invoice_content invoice
    d = pdf_document(document_options: {margin: [0, 0, 0, 0]})

    d.font_size = 12
    d.font("Courier") do
      text_box d, invoice.control_number, [315, 753], 191, 13
      text_box d, invoice.exporter_reference, [509, 753], 83, 13
      text_box d, "1", [533, 735], 10, 13
      text_box d, "1", [569, 735], 10, 13
      text_box d, address_text(invoice.exporter_address), [72, 730], 240, 60
      text_box d, address_text(invoice.consignee_address), [315, 610], 278, 60
      text_box d, invoice.terms, [72, 562], 240, 13
      text_box d, invoice.origin, [315, 538], 141, 13
      text_box d, invoice.destination, [459, 538], 133, 13
      text_box d, invoice.local_carrier, [72, 514], 125, 13
      text_box d, invoice.export_carrier, [72, 491], 125, 13
      text_box d, invoice.port_of_entry, [72, 466], 125, 13
      text_box d, invoice.lading_location, [200, 480], 113, 28
      text_box d, date_value(invoice.export_date), [72, 442], 125, 13
      text_box(d, "X", related_coordinates(invoice.related), 10, 13) unless invoice.related.nil?
      coordinates = duty_for_coordinates(invoice.duty_for)
      text_box(d, "X", coordinates, 10, 13) if coordinates
      text_box d, date_value(invoice.date_of_sale), [459, 466], 141, 13
      text_box d, invoice.total_packages, [222, 371], 205, 13
      text_box d, invoice.total_gross_weight, [430, 371], 150, 13

      # We don't support, yet, the ability to enter individual lines on the invoices...just a blanket goods description.
      if !invoice.description_of_goods.blank?
        text_box d, invoice.description_of_goods, [72, 345], 520, 157
      end

      text_box(d, "X", export_reason_coordinates(invoice.export_reason), 10, 13) unless invoice.export_reason.nil?
      text_box(d, "X", mode_of_transport_coordinates(invoice.mode_of_transport), 10, 13) unless invoice.mode_of_transport.nil?
      text_box(d, "X", containerized_coordinates(invoice.containerized), 10, 13) unless invoice.containerized.nil?
      text_box d, invoice.employee, [77, 102], 250, 10
      text_box d, invoice.firm_address.try(:name), [77, 78], 250, 10
      text_box d, invoice.firm_address.try(:line_1), [77, 66], 250, 10
      text_box d, invoice.firm_address.try(:line_2), [77, 54], 250, 10
      agent_coords = agent_coordinates(invoice.owner_agent)
      text_box(d, "X", agent_coords, 10, 10) if agent_coords
      text_box d, invoice.invoice_total, [509, 179], 80, 10, align: :right
    end


    d.render
  end

  def self.address_text address
    address.nil? ? "" : [address.name.to_s, address.line_1.to_s, address.line_2.to_s, address.line_3.to_s].reject {|a| a.strip.length == 0}.join("\n")
  end

  def self.date_value date, format = "%Y/%m/%d"
    date.nil? ? "" : date.strftime(format)
  end

  def self.related_coordinates related
    related == true ? [202.5, 503] : [260, 503]
  end

  def self.duty_for_coordinates duty_for
    case duty_for.to_s.upcase
    when "SHIPPER INCLUDED"
      [320, 515]
    when "SHIPPER NOT INCLUDED"
      [392, 515]
    when "BUYER"
      [470.5, 515]
    when "CONSIGNEE"
      [535.5, 515]
    else
      nil
    end
  end

  def self.export_reason_coordinates reason
    reason == true || reason.to_s.upcase == "SOLD" ? [104, 178.5] : [169, 178.5]
  end

  def self.mode_of_transport_coordinates mode
    case mode.to_s.upcase
    when "ROAD"
      [89, 130]
    when "RAIL"
      [140, 130]
    when "WATER"
      [190, 130]
    when "AIR"
      [240.5, 130]
    else
      [291, 130]
    end
  end

  def self.containerized_coordinates containerized
    (containerized == true || containerized.to_s.strip.upcase == "NO") ? [341, 130] : [391, 130]
  end

  def self.agent_coordinates agent
    case agent.to_s.upcase
    when "OWNER"
      [348, 47]
    when "AGENT"
      [391.5, 47]
    else
      nil
    end
  end

end; end; end;
