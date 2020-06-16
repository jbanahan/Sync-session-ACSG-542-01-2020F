require 'open_chain/xml_builder'
require 'open_chain/custom_handler/target/target_support'

module OpenChain; module CustomHandler; module Target; class TargetDocumentPacketXmlGenerator
  include OpenChain::XmlBuilder
  include OpenChain::CustomHandler::Target::TargetSupport

  def generate_xml entry, bill_of_lading, attachments
    doc, root = build_xml_document("packet")
    add_element(root, "source_name", "MaerskBroker")
    add_element(root, "vendor_number", "5003461")
    add_element(root, "bill_of_lading", bill_of_lading)
    add_element(root, "entry_id", entry_number(entry))
    add_element(root, "eta", entry.import_date)

    pos = add_element(root, "purchase_orders")
    po_numbers(entry).each do |po_number|
      add_element(pos, "po", nil, {allow_blank: true, attrs: {"id" => po_number}})
    end

    add_element(root, "image_count", attachments.length)
    document_names = add_element(root, "document_names")
    attachments.each do |attachment|
      add_element(document_names, "document", attachment.attachment_type, {attrs: {"id" => attachment.attached_file_name}})
    end

    doc
  end

  private

    def entry_number entry
      # TODO remove this method and reference the identical method in entry.rb
      # that method is currently on another branch.
      "#{entry.entry_number[0, 3]}-#{entry.entry_number[3..-2]}-#{entry.entry_number[-1]}"
    end

    def date_value date
      return nil if date.nil?

      date.strftime("%Y-%h-%m")
    end

    def po_numbers entry
      pos = Set.new
      entry.commercial_invoices.each do |inv|
        inv.commercial_invoice_lines.each do |line|
          po = order_number(line)
          next if po.blank?
          pos << po
        end
      end

      pos.to_a
    end

end; end; end; end
