require 'open_chain/xl_client'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftIntacctInvoiceReportHandler
  attr_accessor :custom_file

  def self.valid_file? filename
    ['XLS', 'XLSX'].member? filename.split('.').last.upcase
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?('Intacct Invoice Report Upload') && user.company.master?
  end

  def can_view? user
    self.class.can_view? user
  end

  def initialize custom_file
    @custom_file = custom_file
  end

  def process user
    invoice_nums = []
    xl_client = OpenChain::XLClient.new custom_file.path
    begin
      xl_client.all_row_values(starting_row_number: 7) { |row| invoice_nums << format(row[2]) }
      urls = get_urls(invoice_nums.compact)
      write_xl xl_client, urls
      xl_client.save s3_file_path, bucket: s3_destination_bucket
      send_xl user, urls, custom_file.attached_file_name
    rescue => e
      send_failure_email user.email, e.message
    end
  end

  def format field
    f = (field.is_a? Float) ? field.to_i.to_s : field.to_s
    f if f =~ /^\w+$/
  end

  def write_xl xl_client, urls
    xl_client.set_cell(0, 6, 16, "#{MasterSetup.application_name} Entry Link")
    count = 7
    xl_client.all_row_values(starting_row_number: 7) do |row|
      url = urls[format row[2]]
      xl_client.set_cell(0, count, 16, "Web Link", url) if url.present?
      count += 1
    end
  end

  def send_xl user, urls, file_name
    missing_invoices = urls.select{ |h,k| !k.present? }.keys
    OpenChain::S3.download_to_tempfile(s3_destination_bucket, s3_file_path) do |t|
      Attachment.add_original_filename_method(t, file_name)
      send_success_email user.email, t, missing_invoices
    end
  end

  def get_urls invoice_nums
    urls = BrokerInvoice.joins(:entry)
                        .where(invoice_number: invoice_nums)
                        .map{ |bi| [bi.invoice_number, bi.entry.excel_url] }
                        .to_h
    invoice_nums.each{ |n| urls[n] = nil if urls[n].nil? }
    urls
  end

  def send_success_email addr, attachment, missing_invoices
    subject = "[VFI Track] Intacct Invoice Report Upload completed successfully"
    body = "".html_safe << "The updated Intacct Invoice Report #{attachment.original_filename} is attached."
    body << "<br>".html_safe << "The following invoices could not be found: #{missing_invoices.join(", ")}" if missing_invoices.present?
    OpenMailer.send_simple_html(addr, subject, body, [attachment]).deliver_now
  end

  def send_failure_email addr, error
    subject = "[VFI Track] Intacct Invoice Report Upload completed with errors"
    body = "The Intacct Invoice Report could not be updated due to the following error: #{error}"
    OpenMailer.send_simple_html(addr, subject, body).deliver_now
  end

  private

  def s3_file_path
    fname = custom_file.attached_file_name
    "#{MasterSetup.get.uuid}/intacct_invoice_report/#{fname}"
  end

  def s3_destination_bucket
    "chainio-temp"
  end

end; end; end; end
