require 'open_chain/delayed_job_extensions'

module OpenChain; module EdiParserSupport
  include OpenChain::DelayedJobExtensions
  extend ActiveSupport::Concern

  # If you are utilizing the standard parse implementation below, you can raise the following errors
  # and an email will be sent with the EDI data attached and the process will not be retried.

  # If any other errors are raised while parsing, the parse will be retried at least a couple times before bailing and
  # sending an email to edisupport.

  # Your parser can utilize this error for cases where business logic has been violated, such as 
  # an 856 referencing a PO that doesn't not exist in the system.
  class EdiBusinessLogicError < StandardError; end
  # Your parser should raise this error if the EDI itself is malformed...dates are sent wrong, segments are missing,
  # mandatory elements are missing, etc.
  class EdiStructuralError < StandardError; end

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

  # Searches the given segment for the qualifier in its elements and then returns
  # the value found in the adjacent element.  You see this pattern PO1 / SLN segments
  # where the segment itself can contain multiple reference/value pairs stacked next
  # to each other.
  def find_segment_qualified_value segment, qualifier
    segment.elements.each_with_index do |el, i|
      return segment.elements[i+1].try(:value) if el.value == qualifier
    end

    nil
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

  # Returns the value specified at the given segments index.
  # This method works pretty much exactly like the Array#[] method.
  # .ie pass a range and you will get back an Array, pass a numeric and you'll
  # get back a single value.
  def value segment, index
    return nil if segment.nil?

    vals = Array.wrap(segment.elements[index]).map {|element| element.value }

    vals.length > 1 ? vals : vals[0]
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
    types = Set.new(Array.wrap(segment_types))
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

  # Returns the first segment found matching the given segment type
  def find_segment segments, segment_type
    found = nil
    segments.each do |seg|
      if segment_type == seg.segment_type
        if block_given?
          yield seg
          break
        else
          found = seg
          break
        end
      end
    end

    found
  end

  # Returns all segments up to (but not including) the given terminator segment type...generally this 
  # something you'll probably use to extract all "header" level type segments.
  # So, for an 850, you'd call the following to get only header level data: 
  # all_segments_up_to all_segments, "PO1"
  #
  def all_segments_up_to segments, stop_segment
    stop_segments = Set.new(Array.wrap(stop_segment))

    collected = []
    Array.wrap(segments).each do |seg|
      break if stop_segments.include? seg.segment_type

      collected << seg
    end

    collected
  end

  def extract_loop segments, sub_element_list, stop_segments: nil
    sub_element_list = Array.wrap(sub_element_list)
    raise ArgumentError, "At least one loop sub-element must be passed." if sub_element_list.length == 0

    loop_start = sub_element_list[0]
    sub_elements = sub_element_list.length > 1 ? Set.new(sub_element_list[1..-1]) : Set.new 

    stop_segments = Set.new(Array.wrap(stop_segments))

    loops = []
    current_loop = []

    segments.each do |seg|
      break if stop_segments.include?(seg.segment_type)

      # The only thing we're looking for if we have a blank current loop
      # is the starting segment...that's IT.
      if current_loop.blank?
        if loop_start == seg.segment_type
          current_loop << seg
        end
      else
        # If we got a new starting segment, then flush what we've been buffering
        # and start a new buffer
        if loop_start == seg.segment_type
          loops << current_loop
          current_loop = [seg]
        elsif sub_elements.include?(seg.segment_type)
          current_loop << seg
        else
          # If we've encountered an element that's not part of our sub_element list, then
          # we need to stop collecting elements for the current loop
          loops << current_loop
          current_loop = []
        end
      end
    end

    loops << current_loop if current_loop.length > 0

    loops
  end

  def extract_n1_loops segments, qualifier: nil, stop_segments: nil
    loops = extract_loop(segments, ["N1", "N2", "N3", "N4", "PER"], stop_segments: stop_segments)
    return loops if qualifier.nil?

    loops.find_all {|l| l.first.elements[1].try(:value) == qualifier }
  end

  # This method attempts to assemble HL segements into a heirarchy using the HL01 (ID) and the
  # HL02 (Parent ID) elements to build the heirarchy.  It is assumed that every segment encountered
  # after an HL and prior to the next HL (or any stop element) belongs to the currently processing
  # HL segment.
  def extract_hl_loops segments, stop_segments: nil
    # Keys will be the HL's ID, values will be a hash of sub-segments and the parent id
    hl_entities = {}

    stop_segments =  Set.new Array.wrap(stop_segments)

    current_entity = nil

    segments.each do |seg|
      break if stop_segments.include? seg.segment_type

      if seg.segment_type == "HL"
        if current_entity
          hl_entities[current_entity[:id]] = current_entity
        end

        current_entity = {id: seg.elements[1].value, hl_level: seg.elements[3].value, hl_segment: seg, segments: [], hl_children: [], parent_id: seg.elements[2].value}
        hl_entities[current_entity[:id]] = current_entity
      elsif !current_entity.nil?
        current_entity[:segments] << seg
      end
    end


    # The best way to do this is work backwards through the entity key list and then add the entity 
    # to its parent's children list.
    top_level = nil

    hl_entities.keys.reverse.each do |id|
      child_entity = hl_entities[id]
      parent_entity = hl_entities[child_entity[:parent_id]]

      # If the parent entity is nil, it means we're at the apex HL segment.
      if parent_entity.nil?
        top_level = child_entity
      else
        parent_entity[:hl_children].unshift child_entity
      end
    end

    top_level
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

  def isa_code transaction
    self.class.isa_code(transaction)
  end

  def send_error_email transaction, error, parser_name, filename, to_address: "edisupport@vandegriftinc.com", include_backtrace: true
    self.class.send_error_email transaction, error, parser_name, filename, to_address: to_address, include_backtrace: include_backtrace
  end

  def write_transaction transaction, io, segment_terminator: "\n"
    self.class.write_transaction(transaction, io, segment_terminator: segment_terminator)
  end

  def parser_name
    self.class.name.demodulize
  end

  # Extracts all address data from an N1 loop into a simple hash
  def extract_n1_entity_data n1_loop
    data = {}
    n1 = find_segment(n1_loop, "N1")
    data[:entity_type] = value(n1, 1)
    data[:name] = value(n1, 2)
    data[:id_code_qualifier] = value(n1, 3)
    data[:id_code] = value(n1, 4)

    data[:names] = []
    find_segments(n1_loop, "N2").each do |n2|
      v = value(n2, 1)
      data[:names] << v unless v.blank?
      v = value(n2, 2) 
      data[:names] << v unless v.blank?
    end

    address = Address.new
    data[:address] = address
    n3 = find_segment(n1_loop, "N3")
    address.line_1 = value(n3, 1)
    address.line_2 = value(n3, 2)

    n4 = find_segment(n1_loop, "N4")
    address.city = value(n4, 1)
    address.state = value(n4, 2)
    address.postal_code = value(n4, 3)

    data[:country] = value(n4, 4)

    data
  end

  # Uses the ID Code (N104) value to find (or create if not found) a company based on data parsed
  # out from the extract_n1_entity_data method.  NO UPDATES to existing data is done.  If the company exists,
  # this method is basically a database lookup.
  #
  # data - hash data returned from extract_n1_entity_data
  # company_type_hash - indicate the type(s) of company being created using a hash... -> {factory: true} or {factory: true, vendor: true}
  # link_to_company - if present and a company object is created, the new company will be linked to the company passed in this param
  # system_code_prefix - if present, the system code will be prefixed with this value.  In general, it should be the system code of the company
  # this new company is being linked to.
  # other_attributes - this can be a hash of any company attributes that should be set when creating the company.  -> {mid: "123ABASD1231"}
  # 
  def find_or_create_company_from_n1_data data, company_type_hash: , link_to_company: nil, system_code_prefix: nil, other_attributes: {}
    c = nil
    system_code = system_code_prefix.blank? ? data[:id_code] : "#{system_code_prefix}-#{data[:id_code]}"
    Lock.acquire("Company-#{system_code}", yield_in_transaction: false) do
      c = Company.where(company_type_hash).where(system_code: system_code).first_or_initialize

      if !c.persisted?
        c.name = data[:name]
        c.name_2 = data[:names].first unless data[:names].blank?

        country = Country.where(iso_code: data[:country]).first unless data[:country].blank?
        data[:address].country = country

        c.addresses << data[:address]
        c.assign_attributes(other_attributes) unless other_attributes.blank?

        c.save!
        link_to_company.linked_companies << c unless link_to_company.nil?
      end
    end

    c
  end

  # Uses the ID Code (N104) value to find (or create if not found) an address under the given company based on data parsed
  # out from the extract_n1_entity_data method.  NO UPDATES to existing data is done.  If the address already exists,
  # this method is basically a database lookup.
  #
  # data - hash data returned from extract_n1_entity_data
  # company - the company to link the 
  # link_to_company - if present and a company object is created, the new company will be linked to the company passed in this param
  # system_code_prefix - if present, the system code will be prefixed with this value.  In general, it should be the system code of the company
  # this new company is being linked to.
  # other_attributes - this can be a hash of any company attributes that should be set when creating the company.  -> {mid: "123ABASD1231"}
  # 
  def find_or_create_address_from_n1_data data, company
    a = nil
    Lock.acquire("Address-#{data[:id_code]}", yield_in_transaction: false) do
      address = company.addresses.find {|a| a.system_code == data[:id_code] }

      if address.nil?
        a = data[:address]
        a.system_code = data[:id_code]
        a.name = data[:name]
        a.country = Country.where(iso_code: data[:country]).first
        a.company = company

        a.save!

        company.addresses.reload
      end
    end

    a
  end

  module ClassMethods

    def isa_code transaction
      transaction.isa_segment.elements[13].value
    end

    def send_error_email transaction, error, parser_name, filename, to_address: "edisupport@vandegriftinc.com", include_backtrace: true
      Tempfile.create(["EDI-#{isa_code(transaction)}-",'.edi']) do |f|
        write_transaction transaction, f
        f.rewind
        Attachment.add_original_filename_method(f, filename) unless filename.blank?

        body = "<p>There was a problem processing the attached #{parser_name} EDI. A re-creation of only the specific EDI transaction file the file that errored is attached.</p><p>Error: "
        body += ERB::Util.html_escape(error.message)
        if include_backtrace
          body += "<br>"
          body += error.backtrace.map {|t| ERB::Util.html_escape(t)}.join "<br>"
        end
        body += "</p>"

        OpenMailer.send_simple_html(to_address, "#{parser_name} EDI Processing Error (ISA: #{isa_code(transaction)})", body.html_safe, [f]).deliver!
      end
    end

    # This method exists mostly for error reporting reaons, it takes a REX12::Transaction and 
    # generates (pseudo) EDI from it.
    def write_transaction transaction, io, segment_terminator: "\n"
      io << transaction.isa_segment.value + segment_terminator
      if transaction.gs_segment
        io << transaction.gs_segment.value + segment_terminator
      end
      transaction.segments.each {|s| io << s.value + segment_terminator }
      io.flush

      nil
    end

    def parse data, opts={}
      REX12::Document.each_transaction(data) do |transaction|
        self.delay.process_transaction(transaction, opts)
      end
    end

    def process_transaction transaction, opts
      parser = self.new
      user = self.respond_to?(:user) ? self.user : User.integration
      begin
        parser.process_transaction(user, transaction, last_file_bucket: opts[:bucket], last_file_path: opts[:key])
      rescue EdiBusinessLogicError, EdiStructuralError => e
        # In test, I want the errors to be raised so they're easily test cased
        raise e if test?

        # These errors are conditions that should be reported without having to retry the document processing, they represent
        # errors inside the actual data that will never get remedied by reprocessing
        send_error_email(transaction, e, parser.parser_name, opts[:key], include_backtrace: false)
      rescue => e
        # In test, I want the errors to be raised so they're easily test cased
        raise e if test?

        # We should retry these at least a couple times if we're running in a delayed job, since there's all sorts
        # of database issues that could arise that we will probably want to reprocess for before giving up and emailing
        # (locks, etc)
        raise e if currently_running_as_delayed_job? && currently_running_delayed_job_attempts < max_delayed_job_attempts

        # Send these errors to our bug email so that they're not creating tickets, and getting sent to the customer
        # as they're likely not errors that the customer should be seeing (db issue, data issue inside VFI Track, etc)
        send_error_email(transaction, e, parser.parser_name, opts[:key], to_address: OpenMailer::BUG_EMAIL)
        e.log_me ["File: #{opts[:key]}"]
      end
    end

    def test?
      Rails.env.test?
    end

    def max_delayed_job_attempts
      5
    end

  end

end; end