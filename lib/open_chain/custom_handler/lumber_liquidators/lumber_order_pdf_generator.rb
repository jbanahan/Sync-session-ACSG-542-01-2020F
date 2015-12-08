require 'prawn'
require 'tempfile'
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderPdfGenerator

  def self.create! order
    file = Tempfile.new('foo')
    begin
      self.render order, file
      file.flush
      Attachment.add_original_filename_method file
      file.original_filename = "order_#{order.order_number}_#{Time.now.strftime('%Y%m%d%H%M%S%L')}.pdf"
      att = order.attachments.new(attachment_type:'Order Printout')
      att.attached = file
      att.save!
    ensure
      file.close
      file.unlink   # deletes the temp file
    end
  end
  def self.render order, open_file_object
    doc = Prawn::Document.new

    # print the grid axis for alignment help
    doc.stroke_axis if Rails.env == 'development'

    doc.text "Order: #{order.order_number}"
    doc.text "Generated at: #{Time.now.utc.to_s} UTC"
    doc.render open_file_object
  end
end; end; end; end