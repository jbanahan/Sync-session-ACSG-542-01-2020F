require 'open_chain/fixed_position_generator'

module OpenChain; module FixedWidthLayoutBasedGenerator
  extend ActiveSupport::Concern

  def write_line io, line_layout, *line_objects
    layout_fields = Array.wrap(line_layout[:fields])
    map_name = line_layout[:map_name]

    raise "No output field definitions for given line_layout with map name #{map_name}" if layout_fields.blank?
    outputters = output_mapping_for(map_name)

    raise "No output mapping callbacks set up for map name #{map_name}" if outputters.nil? || outputters.blank?

    line_layout[:fields].each do |field_definition|
      io << write_field(field_definition, outputters[field_definition[:field]], *line_objects)
    end
  end

  def write_field field_definition, map_value_proc, *args
    io = StringIO.new
    value = mapping_value(map_value_proc, *args)

    if field_definition[:sub_layout]
      write_line io, field_definition[:sub_layout], value
    else
      io << format_for_output(field_definition, value)
    end

    io.rewind
    io.read
  end

  def format_for_output field, value
    # If no datatype is present, handle it as a string
    datatype = field[:datatype].presence || detect_datatype(value)
    format = field[:format].presence || {}
    length = field[:length]

    raise "All fields must have a length defined. #{field[:field]} is missing a length." if length.to_i == 0

    case datatype
    when :string
      return output_string(value, length, format)
    when :decimal
      my_format = {decimal_places: 2}.merge(format)
      return output_decimal(value, length, my_format)
    when :integer
      return output_integer(value, length, format)
    when :date
      my_format = {date_format: "%Y%m%d"}.merge format
      return output_date(value, length, my_format)
    when :datetime
      my_format = {date_format: "%Y%m%d%H%M%S"}.merge format
      return output_datetime(value, length, my_format)
    else
      raise "Unknown datatype #{datatype} for #{field[:field]}."
    end
  end

  def output_string value, length, format_hash
    generator.string(value, length, **format_hash)
  end

  def output_decimal value, length, format_hash
    return generator.number(value, length, **format_hash)
  end

  def output_integer value, length, format_hash
    return generator.number(value, length, **format_hash)
  end

  def output_date value, length, format_hash
    format_hash = {max_length: length}.merge format_hash
    return generator.datetime(value, **format_hash)
  end

  def output_datetime value, length, format_hash
    format_hash = {max_length: length}.merge format_hash
    return generator.datetime(value, **format_hash)
  end

  def detect_datatype value
    return :string if value.nil?

    if value.is_a?(String)
      return :string
    elsif value.is_a?(DateTime) || value.is_a?(ActiveSupport::TimeWithZone)
      return :datetime
    elsif value.is_a?(Date)
      return :date
    elsif value.is_a?(BigDecimal) || value.is_a?(Float)
      return :decimal
    elsif value.is_a?(Numeric)
      return :integer
    else
      return :string
    end
  end

  def mapping_value lamda_or_method_name, *args
    value = nil
    if lamda_or_method_name
      if lamda_or_method_name.is_a? Proc
        # Use self as the context for the lamda execution so any helper methods
        # for formatting, etc are available to use by the lamda (especially important here is allowing convert_company_to_hash to be accessible)
        value = instance_exec *args, &lamda_or_method_name
      elsif lamda_or_method_name.is_a? Symbol
        # If we have symbol from the mapping, assume it's a method that should be called on the first arg
        if args && args.length > 0
          value = args[0].public_send lamda_or_method_name
        end
        
      else
        # We'll assume anything else returned from the mapping is a "constant" value
        value = lamda_or_method_name
      end
    end
    value 
  end

  def generator
    @gen ||= create_fixed_position_generator
  end

  def create_fixed_position_generator
    OpenChain::FixedPositionGenerator.new(exception_on_truncate: false)
  end

end; end