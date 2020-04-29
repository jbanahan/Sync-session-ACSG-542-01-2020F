require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberProductVendorConstantTextUploader
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  attr_reader :custom_file
  # This is primarily for test cases
  attr_reader :errors

  def initialize custom_file
    @custom_file = custom_file
  end

  def can_view? user
    self.class.can_view? user
  end

  def self.valid_file? file_name
    [".XLSX", ".XLS", ".CSV"].include? File.extname(file_name).to_s.upcase
  end

  def process user
    @errors = []
    # start at row 1, since we're assuming there's headers in the file
    row_number = 1

    vendors = {}
    foreach(custom_file, skip_headers: true, skip_blank_lines: true) do |row|
      row_number += 1

      vendor_code = text_value(row[0])
      product_code = text_value(row[1])
      code = text_value(row[2])
      effective_date = date_value(row[3])
      delete = ["Y", "T", "1"].include?(text_value(row[4]).to_s.strip.upcase[0])

      next if vendor_code.blank? || product_code.blank? || code.blank? || (effective_date.blank? && !delete)

      xref_text = cross_reference(code)
      if xref_text.blank?
        errors << "Error in Row #{row_number}: No #{cross_reference_description} found for Code '#{code}'."
        next
      end

      pva = product_vendor_assignment vendor_code, product_code
      if pva.nil?
        errors << "Error in Row #{row_number}: Vendor '#{vendor_code}' is not linked to Product '#{product_code}'."
        next
      elsif !pva.can_edit?(user)
        errors << "Error in Row #{row_number}: You do not have permission to update Vendor '#{vendor_code}'."
        next
      elsif delete
        # Error if the pva doesn't have the code that's being deleted
        constant_text = find_constant_text(pva, code)
        if constant_text.nil?
          errors << "Error in Row #{row_number}: Vendor '#{vendor_code}' / Product '#{product_code}' does not have a #{constant_text_type} code of '#{code}' to delete."
          next
        end
      end

      vendors[pva] ||= []
      vendors[pva] << {code: code, effective_date: effective_date, delete: delete}
    end
    vendors.each_pair do |vendor, data|
      Lock.db_lock(vendor) do
        update_vendor vendor, data, user
      end
    end

    send_email(vendors.size, errors, user)
    nil
  end

  def cross_reference code
    # cross_reference_type should be defined by the extending class
    @cross_references ||= DataCrossReference.hash_for_type cross_reference_type
    @cross_references[code]
  end

  def product_vendor_assignment vendor_code, product_code
    vendor_system_code = vendor_code.rjust(10, '0')
    product_unique_identifier = product_code.rjust(18, '0')

    @product_vendors ||= Hash.new do |h, k|
      v, u = k.split "~"
      # Because of the joins, rails sets this to a readonly query...however, they're both 1-1 joins, so we don't need to worry about the
      # reason rails makes this a readonly query.
      h[k] = ProductVendorAssignment.joins(:product, :vendor).where(companies: {system_code: v}, products: {unique_identifier: u}).readonly(false).first
    end

    @product_vendors["#{vendor_system_code}~#{product_unique_identifier}"]
  end

  def update_vendor pva, constant_texts, user
    updated = false
    constant_texts.each do |ct|
      xref_text = cross_reference(ct[:code])
      code = ct[:code].upcase
      full_text = "#{ct[:code]} - #{xref_text}"
      constant_text = find_constant_text(pva, code)

      if ct[:delete]
        # It's possible the user tried to delete a constant text that didn't exist
        if constant_text
          constant_text.mark_for_destruction
          updated = true
        end
      else
        if constant_text.nil?
          constant_text = pva.constant_texts.build text_type: constant_text_type
        end

        constant_text.constant_text = full_text
        constant_text.effective_date_start = ct[:effective_date]
        if constant_text.changed?
          updated = true
        end
      end
    end

    if updated
      pva.save!
      pva.create_snapshot user, nil, "#{cross_reference_description} Upload"
    end
  end

  def find_constant_text pva, code
    pva.constant_texts.find {|t| t.constant_text.start_with?(code) && t.text_type == constant_text_type }
  end

  def send_email vendor_update_count, errors, user
    subject = "Vendor #{cross_reference_description} Upload Complete"
    subject += " With #{errors.length} #{"error".pluralize(errors.length)}" if errors.length > 0
    body = "<p>The Vendor #{cross_reference_description} Upload has completed.  #{vendor_update_count} Vendor Product #{vendor_update_count == 1 ? "link has" : "links have"} been updated.</p>"
    if errors.length > 0
      body += "<p>The following errors were encounted:<br><ul>"
      errors.each {|e| body+= "<li>#{e}</li>"}
      body += "</ul></p>"
    end

    OpenMailer.send_simple_html(user.email, subject, body.html_safe).deliver_now
  end

end; end; end; end