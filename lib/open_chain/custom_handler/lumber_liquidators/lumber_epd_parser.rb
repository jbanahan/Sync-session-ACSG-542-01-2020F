require 'open_chain/xl_client'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

# Creates variants and variant assignments for products / plants based on Lumber Liquidators proprietary spreadsheet format
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberEpdParser
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  # use with CustomFile.process
  def initialize custom_file
    @custom_file = custom_file 
  end

  # use with CustomFile.process
  def process user
    raise "User does not have permission to process file." unless self.class.can_view?(user)
    self.class.parse_xlsx @custom_file.path, user.id
  end

  def self.can_view? user
    return MasterSetup.get.custom_feature?('Lumber EPD') && 
      user.company.master? && 
      user.edit_variants? && 
      user.in_group?('PRODUCTCOMP')
  end

  # Parse an S3 file 
  #
  # uses primitives instead of objects to help DelayedJob serialization
  def self.parse_xlsx file_path, user_id
    user = User.find(user_id)
    rows = OpenChain::XLClient.new(file_path).all_row_values(0,1)
    row_structs, parse_errors = parse_row_arrays(rows)
    process_errors = process_rows(row_structs, user)
    write_results_message(user,(parse_errors+process_errors).flatten.compact.uniq)
  end

  def self.prep_my_custom_definitions
    self.prep_custom_definitions [:cmp_sap_company,:var_recipe,:pva_pc_approved_by,:pva_pc_approved_date]
  end

  def self.parse_row_arrays row_arrays
    row_struct = Struct.new(:article_num, :variant_id, 
      :vendor_num, :component, :component_thickness,
      :genus, :species, :coo, :row_num)
    rows = []
    errors = []

    row_arrays.each_with_index do |r, row_num|
      user_row = row_num+2 #show the user the row number as it appears in the excel sheet
      r_struct, err = parse_row_array(row_struct,r,user_row) 
      rows << r_struct if r_struct
      errors << err if err
    end

    return rows, errors
  end

  def self.process_rows row_structs, user
    variant_hash = Hash.new
    row_structs.each do |rs|
      key = "#{rs.article_num}~#{rs.variant_id}"
      variant_hash[key] ||= []
      variant_hash[key] << rs
    end
    cdefs = prep_my_custom_definitions
    errors = variant_hash.values.collect {|variant| process_variant(variant,user,cdefs)}
    return errors.compact.uniq
  end

  def self.process_variant variant_array, user, cdefs
    return [] if variant_array.blank?

    fv = variant_array.first
    begin
      ActiveRecord::Base.transaction do
        if fv.article_num.blank?
          return ["Article number is blank for row #{fv.row_num}."]
        end
        if fv.variant_id.blank?
          return ["Recipe ID is blank for row #{fv.row_num}."]
        end
        if fv.vendor_num.blank?
          return ["Vendor ID is blank for row #{fv.row_num}."]
        end

        prod = Product.find_by_unique_identifier fv.article_num
        if prod.nil?
          return ["Product \"#{fv.article_num}\" not found for row #{fv.row_num}."]
        end

        variant = prod.variants.find_by_variant_identifier fv.variant_id
        if(variant.nil?)
          variant = prod.variants.create!(variant_identifier:fv.variant_id)
        end

        recipe = variant_array.collect {|v| "#{v.component}: #{v.genus}/#{v.species} - #{v.component_thickness} - #{v.coo}"}.join("\n")

        variant.update_custom_value!(cdefs[:var_recipe],recipe)

        vendor = Company.find_by_custom_value cdefs[:cmp_sap_company], fv.vendor_num

        if vendor.nil?
          return ["Vendor \"#{fv.vendor_num}\" not found for row #{fv.row_num}."]
        end

        plant = vendor.plants.first_or_create!(name:vendor.name)

        pva = variant.plant_variant_assignments.first_or_create!(plant_id:plant.id)
        approved_date_cv = pva.get_custom_value(cdefs[:pva_pc_approved_date])
        if approved_date_cv.value.nil?
          pva.update_custom_value!(cdefs[:pva_pc_approved_date],0.seconds.ago)
          pva.update_custom_value!(cdefs[:pva_pc_approved_by],user.id)
        end

        return []
      end
    rescue
      $!.log_me "User: #{user.username}"
      return ["Error on row #{fv.row_num}: #{$!.message}"]
    end
  end

  def self.write_results_message(user, errors) 
    subject = "EPD Processing Complete"
    body = "<p>EPD Processing has finished.</p>"
    if !errors.blank?
      subject << " - WITH ERRORS"
      body << "<p><strong>Errors:</strong></p><ul>"
      errors.each {|err| body << "<li>#{err}</li>"}
      body << "</ul>"
    end
    user.messages.create!(subject:subject,body:body)
  end

  # PRIVATE STUFF BELOW

  def self.parse_row_array struct, row, row_num
    # skip blank row
    return [nil,nil] if row.length == 0

    if row.length < 33
      return [nil,"Row #{row_num} failed because it only has #{row.length} columns. All rows must have at least 33 columns."] 
    end

    rs = struct.new
    article_base = row[2].to_s.gsub(/\.0$/,'')
    vendor_base = row[7].to_s.gsub(/\.0$/,'')
    rs.article_num = lpad(article_base,18)
    rs.variant_id = row[3].to_s.gsub(/\.0$/,'')
    rs.vendor_num = lpad(vendor_base,10)
    rs.component = row[11]
    rs.component_thickness = row[12].to_s.gsub(/\.0$/,'')
    rs.genus = row[26]
    rs.species = row[27]
    rs.coo = row[28]
    rs.row_num = row_num
    return [rs, nil]
  end
  private_class_method :parse_row_array


  def self.lpad(string,len)
    s = string
    s = "0#{s}" while s.length < len
    s
  end

end; end; end end