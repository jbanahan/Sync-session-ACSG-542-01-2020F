module OpenChain; module EdiParserSupport
  extend ActiveSupport::Concern

  # Yields all segments that contain the value in the position/segment specified.
  def with_qualified_segments segments, segment_type, segment_position, qualifier_value
    find_segments(segments, segment_type) do |seg|
      if seg.elements[segment_position].try(:value) == qualifier_value
        yield seg
      end
    end
    nil
  end

  # Finds all elements that match segment type and qualifier values provided.  The indexes to use
  # for the qualifier and value positions on the segment are explicitly supplied as well.
  def find_elements_by_qualifier segments, segment_type, qualifier, qualifier_position, value_position
    values = []
    with_qualified_segments(segments, segment_type, qualifier_position, qualifier) do |seg|
      val = seg.elements[value_position]
      values << val.value unless val.nil?
    end

    values
  end


  # Finds all segments that have the given qualfier value in the coordinate specified.
  # 
  # Example: to find all REF segments with a REF01 qualifier of "MB" -> find_segments_by_qualifier(segments, "REF01", "BM")
  def find_segments_by_qualifier segments, edi_position, qualifier_value
    segment_type, segment_position = *parse_edi_coordinate(edi_position)
    found = []
    with_qualified_segments(segments, segment_type, segment_position, qualifier_value) do |seg|
      found << seg
    end

    found
  end

  # Finds the value element that have the given qualfier value in the coordinate specified.
  # If value_index is left unspecified, it is assumed to be 1 index higher than the qualifier's index.
  # 
  # Example: to find the element values for REF01 segments with a qualifier of "MB" -
  #            -> find_values_by_qualifier(segments, "REF01", "BM")
  # 
  def find_values_by_qualifier segments, qualifier_coordinate, qualifier_value, value_index: nil
    # qualifier is going to be the text representation of the field...so REF01 generally
    qualifier_data = parse_edi_coordinate(qualifier_coordinate)
    value_index = (qualifier_data[1] + 1) if value_index.nil?
    find_elements_by_qualifier(segments, qualifier_data[0], qualifier_value, qualifier_data[1], value_index)
  end

  # Simple helper method that returns the first result returned by passing the same
  # params to find_values_by_qualifier
  def find_value_by_qualifier segments, qualifier_coordinate, qualifier_value, value_index: nil
    find_values_by_qualifier(segments, qualifier_coordinate, qualifier_value, value_index: value_index).first
  end

  # Finds all "REF" values with the given qualifier
  # This is basically just a helper method for find_elements_by_qualifier, but since
  # REF's are the most common thing that you'd use that for, this method exists.
  def find_ref_values segments, qualifier
    find_elements_by_qualifier(segments, "REF", qualifier, 1, 2)
  end

  def find_ref_value segments, qualifier
    find_ref_values(segments, qualifier).first
  end

  # Finds every value in the given segment list that has a given coordinate.
  # .ie Find every BEG01 -> find_element_values(segments, "BEG01")
  def find_element_values segments, edi_position
    segment_type, segment_position = *parse_edi_coordinate(edi_position)
    values = []
    find_segments(segments, segment_type) do |seg|
      val = seg.elements[segment_position]
      values << val.value unless val.nil?
    end

    values
  end

  # This is just a helper method that calls first on the result of
  # passing the same params to find_element_values.
  def find_element_value segments, edi_position
    find_element_values(segments, edi_position).first
  end

  # Finds DTM segments using the qualifier specified and then parses the date/time
  # from it relative to the specified time zone.  If nil, UTC is used.
  #
  # DTM can optionally specify a date format in DTM03, this method WILL NOT consult that format.
  # If a format that ActiveRecord::TimeZone cannot parse is used, you must supply a date_format
  # that matches the specified EDI format.  Even if a date_format is utilized, this method will 
  # still return a TimeWithZone object relative to the time_zone specified.
  def find_date_values segments, qualifier, time_zone: nil, date_format: nil
    segment_type, segment_position = *parse_edi_coordinate("DTM01")

    time_zone = ActiveSupport::TimeZone["UTC"] if time_zone.nil?

    unless time_zone.is_a?(ActiveSupport::TimeZone)
      time_zone = ActiveSupport::TimeZone[time_zone.to_s]
    end

    # We're going to see if the format already has the timezone mentioned in it, otherwise we'll
    # append our own so that we can get actual TimeWithZone objects back.
    append_offset = false
    if date_format 
      if (date_format =~ /%z/i).nil?
        append_offset = true
        date_format += " %z"
      end
    end

    values = []
    with_qualified_segments(segments, segment_type, segment_position, qualifier) do |seg|
      date_element = seg.elements[2]
      next unless date_element

      date_value = date_element.value
      unless date_value.blank?
        v = parse_dtm_date_value(date_value, time_zone: time_zone, date_format: date_format, force_append_offset: append_offset)
        values << v unless v.nil?
      end
    end

    values 
  end

  # Simple helper method that returns the first date value returned by 
  # using the same parameters to find_date_values
  def find_date_value segments, qualifier, time_zone: nil, date_format: nil
    find_date_values(segments, qualifier, time_zone: time_zone, date_format: date_format).first
  end

  def parse_dtm_date_value date_value, time_zone: nil, date_format: nil, force_append_offset: false
    return nil if date_value.to_s.blank?

    append_offset = false
    if date_format 
      if (date_format =~ /%z/i).nil?
        append_offset = true
        date_format += " %z"
      end
    end

    time_zone = ActiveSupport::TimeZone["UTC"] if time_zone.nil?
    unless time_zone.is_a?(ActiveSupport::TimeZone)
      time_zone = ActiveSupport::TimeZone[time_zone.to_s]
    end

    # Technically, DTM03 can specify a format code...unless an alternate layout is provided
    # we're going to assume the value given is parsable by the ActiveSupport::TimeZone object.
    if date_format
      date_value += " #{time_zone.formatted_offset(false)}" if append_offset || force_append_offset
      val = Time.strptime date_value, date_format
      return val.in_time_zone(time_zone)
    else
      return time_zone.parse(date_value)
    end
  end

  # Find every given segment type from the list of segments provided.
  # Yields any matched segments if a block is provided.
  def find_segments segments, *segment_types
    types = Set.new(Array.wrap(segment_types).map {|t| t.to_s.upcase } )
    found = block_given? ? nil : []
    segments.each do |seg|
      if types.include?(seg.segment_type)
        if block_given?
          yield seg
        else
          found << seg
        end
      end
    end
    found
  end

  # Parses a given EDI position (coordinate) into the segment type and index provided.
  # Example: parse_edi_coordinate("BEG01") -> ["BEG", 1]
  def parse_edi_coordinate coord
    if coord.to_s.upcase =~ /\A([A-Z0-9]+)(\d{2})\z/
      [$1, $2.to_i]
    else
      raise ArgumentError, "Invalid EDI coordinate value received: '#{coord}'."
    end
  end

end; end