# This rule should only be applied to PVH entries and should be skipped until a broker invoice is added.
module OpenChain; module CustomHandler; module Pvh; class PvhValidationRuleEntryInvoiceLineMatchesShipmentLine < BusinessValidationRule

  def self.enabled?
    MasterSetup.get.custom_feature? "PVH Feeds"
  end

  def run_validation entry
    shipments = find_shipments(entry)
    preload_entry(entry)
    errors = []
    entry.commercial_invoices.each do |i|
      i.commercial_invoice_lines.each do |l|
        if !invoice_line_matches?(shipments, entry, l)
          errors << "PO # #{l.po_number} / Part # #{l.part_number} - Failed to find matching PVH Shipment Line."
        end
      end
    end

    errors.uniq.to_a
  end

  def find_shipments entry
    @shipments ||= begin
      master_bills = Entry.split_newline_values(entry.master_bills_of_lading)
      s = Shipment.where(importer_id: pvh_importer.id, master_bill_of_lading: master_bills)
      if entry.ocean_mode? 
        container_numbers = Entry.split_newline_values(entry.container_numbers)
        s = s.joins(:containers).where(containers: {container_number: container_numbers})
        s = s.includes(containers: {shipment_lines: {order_lines: [:order, :product]}})
      else
        # Don't need to include containers for air.
        s = s.includes(shipment_lines: {order_lines: [:order, :product]})
      end
      s.to_a
    end
  end

  def importer entry
    entry.candian? ? pvh_importer : entry.importer
  end

  def invoice_line_matches? shipments, entry, line
    shipment_lines = []
    if entry.ocean_mode?
      # Canadian entries won't have container records at the line level
      if !line.container&.container_number.blank?
        shipments.each do |s|
          s.containers.each do |c|
            shipment_lines.push *c.shipment_lines if c.container_number == line.container.container_number
          end
        end
      else
        shipments.each do |s|
          s.containers.each do |c|
            shipment_lines.push *c.shipment_lines
          end
        end
      end
    else
      shipment_lines = shipments.map {|s| s.shipment_lines }.flatten
    end

    shipment_lines.each do |shipment_line|
      return true if shipment_line_matches_invoice_line?(shipment_line, line)
    end

    return false
  end

  def shipment_line_matches_invoice_line? shipment_line, invoice_line
    order_line = shipment_line.order_line
    return false if order_line.nil?

    return false unless order_line.order&.customer_order_number == invoice_line.po_number

    return order_line.product&.unique_identifier == "PVH-#{invoice_line.part_number}"
  end

  def pvh_importer
    @pvh ||= Company.where(system_code: "PVH").first
  end

  def preload_entry entry
    ActiveRecord::Associations::Preloader.new(entry, {commercial_invoices: {commercial_invoice_lines: :container}}).run
  end

end; end; end; end