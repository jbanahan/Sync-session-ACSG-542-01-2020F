require 'open_chain/mutable_boolean'
require 'open_chain/custom_handler/custom_file_csv_excel_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Ascena; class AscenaProductUploadParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?("Ascena Parts") && user.company.master? && user.edit_products?
  end

  def can_view? user
    self.class.can_view? user
  end

  def process user
    
    begin
      process_file @custom_file, user
    rescue => e
      user.messages.create(:subject=>"File Processing Complete With Errors", :body=>"Unable to process file #{@custom_file.attached_file_name} due to the following error:<br>#{e.message}")
    end
    nil
  end

  def cdefs 
    @cdefs ||= self.class.prep_custom_definitions [:prod_part_number, :prod_reference_number, :prod_department_code, :prod_country_of_origin, :class_customs_description, :class_classification_notes]
  end

  def process_file custom_file, user
    # We need to do two passes at these files because they're huge and too big to buffer all the lines directly into
    # memory.
    #
    # The first pass is going to build the list of "duplicate" styles.
    #
    # Ascena's product file is going to have duplicate styles (quite a number of them...but most of the time
    # it's going to be because the styles have different vendors...which we don't care about).
    # The only time we care about duplicate styles is when they have different hts numbers.
    # 
    # This happens because ascena ships womens and girls garments with the exact same styles,
    # however, the girls size garments can have different HTS numbers...thus we get a second row
    # for these.  We don't want this to overwrite the existing record.  Thus, we handle these
    # differently.
    #
    # So what we're going to do is record the style and the HTS for everything and then on the second
    # pass we'll treat the styles that have multiple HTS values differently than the ones with only a single.
    all_styles = {}
    headers = false
    foreach(custom_file, skip_headers: true) do |row|
      style = text(row[1])
      next if style.blank?

      hts = hts_val(row)
      set_style_data(all_styles, style, hts)
      
      parent_style = text(row[3])
      if parent_style != style && !parent_style.blank?
        set_style_data(all_styles, parent_style, hts)
      end
    end

    duplicate_styles = Hash.new { |h, k| h[k] = [] }
    foreach(custom_file, skip_headers: true) do |row|
      style = text(row[1])
      next if style.blank?

      # If we know we had duplicate styles to process, don't process these until 
      # the end...(we could potentially reprocess them inline once we know we have
      # all the rows needed, but that's more complicated logic and I think we're ok 
      # doing it like this)
      if all_styles[style] && all_styles[style][:hts].length > 1
        duplicate_styles[style] << row
      else
        # We have a style that only has a single HTS...just process it
        process_file_row(user, custom_file.attached_file_name, row, style, hts_val(row), nil)
        # See if the parent style has multiple HTSs
        parent_style = text(row[3])
        # If the parent style is the same as the style (which appears to happen a lot), then we 
        # can move on
        next if style == parent_style

        if all_styles[parent_style] && all_styles[parent_style][:hts].length > 1
          duplicate_styles[parent_style] << row
        else
          process_file_row(user, custom_file.attached_file_name, row, parent_style, hts_val(row), nil)
        end
      end
    end

    duplicate_styles.each_pair do |style, rows|
      # Basically, at this point, we're using the key as the style and then extracting the garment type and hts from
      # each row and putting them in the classification notes field (sort them alphabetically based on the garment type)
      classification_notes = rows.map {|row| [text_value(row[2]), hts_val(row)]}.sort {|a, b| a[0].to_s <=> b[0].to_s }.map {|v| "#{v[0]}: #{v[1].hts_format}"}.join "\n "

      process_file_row(user, custom_file.attached_file_name, rows.first, style, nil, classification_notes)
    end

    nil
  end

  def text v
    text_value(v).to_s.strip
  end

  def hts_val row
    text(row[9]).gsub(".", "")
  end

  def set_style_data all_styles, style, hts
    # 
    style_values = all_styles[style]
    if style_values.nil?
      all_styles[style] = { counter: 1, hts: Set.new([hts]) }
    else
      style_values[:hts] << hts
      style_values[:counter] += 1
    end
  end

  def process_file_row user, filename, row, style, hts, classification_notes
    # This changed tracking stuff is mostly about not creating change records when the product
    # is unchanged...it floods the history pointlessly.  Because the product heirarchy is multiple layers
    # (both horizontally (custom values) and vertically (classification, tariff records))
    # the standard ActiveRecord "changed?" method call doesn't really work well for determining if the product
    # changed...so we're doing it manually.
    changed = MutableBoolean.new(false)
    find_or_create_product(style, changed) do |product|
      product.name = text(row[6])

      set_custom_value(product, cdefs[:prod_part_number], style, changed)
      # Only set the parent id (reference number) if it's different than the style (both because ascena
      # sends the parent id as the same value as the style all the time, and when creating parents it'll 
      # be the same value)
      parent_id = text(row[3])
      parent_id = nil if style == parent_id

      set_custom_value(product, cdefs[:prod_reference_number], parent_id, changed)
      set_custom_value(product, cdefs[:prod_department_code], text(row[4]), changed)
      set_custom_value(product, cdefs[:prod_country_of_origin], text(row[8]), changed)

      classification = product.classifications.find {|c| c.country_id == us.id }
      if classification.nil?
        changed.value = true
        classification = product.classifications.build country_id: us.id
      end

      set_custom_value(classification, cdefs[:class_customs_description], text(row[38]), changed)
      set_custom_value(classification, cdefs[:class_classification_notes], classification_notes, changed)

      tariff = classification.tariff_records.find {|t| t.line_number == 1 }
      # If the hts value is nil, remove the tariff record
      if hts.nil? && tariff
        tariff.destroy
        changed.value = true
      elsif !hts.nil?
        if tariff.nil?
          changed.value = true
          tariff = classification.tariff_records.build line_number: 1
        end

        if tariff.hts_1 != hts
          changed.value = true
          tariff.hts_1 = hts
        end
      end
      

      if product.changed? || changed.value
        product.save!
        product.create_snapshot user, nil, filename
      end
    end
  end

  def find_or_create_product style, flag
    unique_identifier = "ASCENA-#{style}"
    product = nil
    Lock.acquire("Product-#{unique_identifier}") do 
      product = Product.where(importer_id: importer.id, unique_identifier: unique_identifier).first_or_initialize
      unless product.persisted?
        flag.value = true
        product.save!
      end
    end

    Lock.with_lock_retry(product) do 
      yield product
    end
  end

  def importer
    @importer ||= Company.where(system_code: "ASCENA", importer: true).first
    raise "Unable to find Ascena company account." unless @importer
    @importer
  end

  def us
    @country ||= Country.where(iso_code: "US").first
    raise "Unable to find US country." unless @country
    @country
  end

  def set_custom_value obj, cdef, val, flag
    custom_value = obj.custom_values.find {|cd| cd.custom_definition_id == cdef.id}
    return if custom_value.nil? && val.nil?

    c_val = custom_value.try(:value)

    if c_val != val
      obj.find_and_set_custom_value cdef, val
      flag.value = true
    end

    nil
  end

end; end; end; end