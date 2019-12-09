module OpenChain; module CustomHandler; module Amazon; module AmazonProductParserSupport
  extend ActiveSupport::Concern

  def process_parts csv, user, filename
    # The first thing we want to do is group all the lines together by part number.
    parts = group_parts(csv)
    parts.each_pair do |action_sku, lines|
      process_part_lines(user, filename, lines)
    end
  end

  def sku row
    text(row[2])
  end

  def set_custom_value product, cdef_uid, changed, value
    cv = product.find_and_set_custom_value(cdefs[cdef_uid], value)
    changed.value = true if cv.changed?
    nil
  end

  def text v
    v = v.to_s.strip
    v.blank? ? nil : v
  end

  def country iso
    @countries ||= Hash.new do |h, k|
      h[k] = Country.where(iso_code: k).first
    end

    @countries[iso]
  end

  def amazon_importer ior_id
    # Amazon confirmed we may get data for multiple importers, if the same part is sold by multiple IORs

    # For some reason, the test IORIds are prefixed with IOR-..strip that off
    if ior_id =~ /\AIOR-(.+)/i
      ior_id = $1
    end

    @importers ||= Hash.new do |h, k|
      c = Company.importers.with_identifier("Amazon Reference", k).first
      # Because there are possibly multiple importers in the same file, we don't want to reject the whole file if we encounter one
      # that's invalid, just log a message.  This way if one importer is missing, we can at least import those parts that
      # are linked to an IOR we actually have in the system.
      inbound_file.add_reject_message("Failed to find Amazon Importer with IOR Id '#{k}'.") if c.nil?
      h[k] = c
    end

    @importers[ior_id]
  end

  def find_or_create_product line
    importer = amazon_importer(ior(line))
    # Importer will be nil if the IOR's haven't been set up in Kewill
    return if importer.nil?

    part_number = sku(line)
    product = nil
    unique_identifier = "#{importer.kewill_customer_number}-#{part_number}"
    created = false
    Lock.acquire("Product-#{unique_identifier}") do 
      product = Product.where(importer_id: importer.id, unique_identifier: unique_identifier).first_or_initialize
      if !product.persisted?
        product.save!
      end
    end

    Lock.db_lock(product) do
      yield product
    end
  end

  def header_row? row
    row[0].to_s.match?(/IORId/i)
  end

  def parts_key row
    sku(row)
  end

  def group_parts csv
    parts = Hash.new do |h, k|
      h[k] = []
    end

    csv.each do |row|
      next if header_row?(row)

      parts[parts_key(row)] << row
    end

    parts
  end

  def ior row
    text(row[0])
  end

end; end; end; end