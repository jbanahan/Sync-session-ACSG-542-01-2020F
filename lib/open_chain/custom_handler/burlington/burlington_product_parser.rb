require 'open_chain/custom_handler/custom_file_csv_excel_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/parser_support'

module OpenChain; module CustomHandler; module Burlington; class BurlingtonProductParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::ParserSupport

  attr_accessor(:updater)

  def initialize(custom_file)
    @custom_file = custom_file
    @updater = Updater.new
  end

  def self.can_view?(user)
    MasterSetup.get.custom_feature?("Burlington Parts") && user.company.master? && user.edit_products?
  end

  def can_view? user
    self.class.can_view? user
  end

  def self.valid_file? file
    [".xls", ".xlsx", ".csv"].include? File.extname(file).to_s.downcase
  end

  def csv_reader_options
    {encoding: "Windows-1252"}
  end

  def importer
    @importer ||= Company.find_by system_code: "BURLI"
    raise "'BURLI' importer not found!" unless @importer
    @importer
  end

  def us
    @us ||= Country.find_by(iso_code: "US")
    raise "US missing from countries table" unless @us
    @us
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_type, :prod_part_number, :prod_short_description, :prod_long_description, :class_classification_notes]
  end

  def process(user)
    begin
      process_file(@custom_file, user)
      user.messages.create(subject: "File Processing Complete", body: "Burlington Product Upload processing for file #{@custom_file.attached_file_name} is complete.")
    rescue => e
      user.messages.create subject: "File Processing Complete With Errors", body: "Unable to process file #{@custom_file.attached_file_name} due to the following error:<br>#{e.message}"
    end
    nil
  end

  def build_header_row(row)
    row.map { |cell| cell.to_s.encode("UTF-8", :invalid => :replace, :undef => :replace, replace: "?") }
  end

  def get_product_type(r)
    row = r.map { |cell| cell.to_s.encode("UTF-8", :invalid => :replace, :undef => :replace, replace: "?") }
    row[1]
  end

  def process_file(custom_file, user)
    header_row = nil
    cache = []
    current_style_number = nil
    row_count = 0
    product_type = ""

    foreach(custom_file, skip_headers: false) do |r|
      # We have three headers present. Skip headers ignores one of them, but we still have two to deal with.
      # The first one we want to store, the next one we want to discard.
      row_count += 1
      if row_count == 1
        product_type = get_product_type(r)
        next
      elsif row_count == 2
        header_row = build_header_row(r)
        next
      elsif row_count < 4
        next
      end

      row = r.map { |cell| cell.to_s.encode("UTF-8", :invalid => :replace, :undef => :replace, replace: "?") }

      if row[3] != current_style_number && current_style_number.present?
        process_part(cache, user, header_row, product_type)
        cache = [row]
      else
        cache << row
      end
      current_style_number = row[3]
    end
    process_part(cache, user, header_row, product_type)
  end

  def process_part(cache, user, header_row, product_type)

    # We only really care if the unique identifier is blank. If everything else is empty...that is on Burlington.
    return if cache.first[3].blank?

    @updater.reset
    first_row = cache.first
    part_no = first_row[3].to_s

    find_or_create_product(part_no) do |prod|
      if prod.name != first_row[5]
        prod.name = first_row[5]
        updater.set_changed
      end

      updater.set prod, part_no, cdef: cdefs[:prod_part_number]
      updater.set prod, first_row[7], cdef: cdefs[:prod_short_description]
      updater.set prod, first_row[8], cdef: cdefs[:prod_long_description]
      updater.set prod, product_type, cdef: cdefs[:prod_type]
      hts = first_row[9].gsub('.', '')
      classi = prod.classifications.find{ |cl| cl.country_id = us.id } || prod.classifications.build(country: us)
      if classi.tariff_records.length > 1
        classi.tariff_records.destroy_all
        updater.set_changed
      end
      tariff = classi.tariff_records.first
      if tariff
        updater.set tariff, hts, attrib: :hts_1
      else
        classi.tariff_records.build(hts_1: hts)
        updater.set_changed
      end

      tariff = prod.classifications.find{ |cl| cl.country_id == us.id }
      classification_notes = build_classification_notes(tariff, header_row, first_row)

      if classification_notes.present?
        updater.set tariff, classification_notes, cdef: cdefs[:class_classification_notes]
      end

      if updater.changed?
        prod.save!
        prod.create_snapshot(user, nil, "BurlingtonProductParser")
      end
    end
  end

  def build_classification_notes(tariff, header_row, row)
    # We store this so we can easily add additional classification summary rows, and because I cannot remember numbers.
    classification_summary_rows = (28..35)
    classification_summary = []

    return if tariff.blank?

    classification_summary_rows.each do |i|
      if row[i].present?
        classification_summary << "#{header_row[i]} - #{row[i]}"
      end
    end

    classification_summary.join(',')
  end

  def find_or_create_product(part_no)
    product = nil
    Lock.acquire("Product-#{part_no}") do
      product = Product.where(unique_identifier: part_no).first_or_initialize
      unless product.persisted?
        updater.set_changed
        product.save!
      end
    end

    Lock.with_lock_retry(product) do
      yield product
    end
  end
end; end; end; end