require 'open_chain/http_client'
require 'open_chain/custom_handler/intacct/intacct_xml_generator'
require 'digest/sha1'
require 'rexml/document'

module OpenChain; module CustomHandler; module Intacct; class IntacctClient < OpenChain::HttpClient
  # This is the answer to the security question: :$hSU'ZW^x6>E7'

  INTACCT_CONNECTION_INFO ||= {
    url: 'https://api.intacct.com/ia/xml/xmlgw.phtml',
    api_version: "2.1"
  }.freeze

  class IntacctClientError < StandardError
  end

  class IntacctRetryError < IntacctClientError
  end

  class IntacctInvalidDimensionError < IntacctClientError
    attr_reader :dimension_type, :value

    def initialize message, dimension_type, value
      super(message)
      @dimension_type = dimension_type
      @value = value
    end

    def == other
      (self.class == other.class) && self.message == other.message && self.dimension_type == other.dimension_type && self.value == other.value
    end
  end

  def initialize xml_generator = IntacctXmlGenerator.new
    @generator = xml_generator
  end

  def self.async_send_dimension type, id, value, company = nil
    self.new.send_dimension type, id, value, company
  end

  def send_dimension type, id, value, company = nil
    retry_count = 0

    # if location_id is set, then the dimension will post to a specific sub-entity.
    control, xml = @generator.generate_dimension_get type, id
    begin
      response = post_xml company, false, false, xml, control

      # Just look for a <key> element in the response, if it's there, then we can reliably know the dimension already exists
      key = response.text("//key")
      if key.blank?
        # No key was found, so try and create the dimension
        control, xml = @generator.generate_dimension_create type, id, value
        response = post_xml company, true, true, xml, control

        # Might as well return the key that was created
        key = response.text("//key")
      end

      key
    rescue StandardError => e
      if e.is_a?(IntacctRetryError) && (retry_count += 1) < 5
        sleep retry_count
        retry
      end

      # There must be some slight delay when dimensions are created vs. when they're available to the API,
      # since we're only creating the same dimension one at a time (via locking) and we're still getting duplicate
      # create errors.  Just look for an error message stating the transaction was already created and then don't
      # bother with the error reporting since our end goal of getting the dimension out there has been met we
      # don't care if this particular call errored.
      message = e.message.try(:downcase)
      if message.include?("a successful transaction has already been recorded") || (message =~ /another \S+ with the given value\(s\)/i) ||
         message.include?("concurrent request in process")
        id
      else
        e.log_me ["Failed to find and/or create dimension #{type} #{id} for location #{company}."]
        nil
      end
    end
  end

  def send_receivable receivable
    retry_count = 0
    begin
      function_control_id, xml = @generator.generate_receivable_xml receivable
      response = post_xml receivable.company, true, true, xml, function_control_id
      receivable.intacct_key = extract_result_key response, function_control_id
      receivable.intacct_upload_date = Time.zone.now
      receivable.intacct_errors = nil
    rescue IntacctInvalidDimensionError => e
      send_dimension(e.dimension_type, e.value, e.value)
      retry
    rescue StandardError => e
      if e.is_a?(IntacctRetryError) && (retry_count += 1) < 3
        sleep retry_count
        retry
      else
        receivable.intacct_errors = e.message
      end
    end
    receivable.save!
  end

  def send_payable payable, linked_checks
    vendor_terms = nil
    begin
      if vendor_terms.nil?
        # We need to find the vendor terms, there's no straight forward way to accomplish this without first doing
        # a get request against the API.
        fields = get_object_fields payable.company, "vendor", payable.vendor_number, "termname"
        vendor_terms = fields['termname']
        raise "Failed to retrieve Terms for Vendor #{payable.vendor_number}.  Terms must be set up for all vendors." if vendor_terms.blank?
      end

      payable_control_id, payable_xml = @generator.generate_payable_xml payable, vendor_terms

      all_control_ids = [payable_control_id]
      check_control_ids = {}

      linked_checks.each do |check|
        control_id, check_xml = @generator.generate_ap_adjustment check, payable
        payable_xml += check_xml
        check_control_ids[control_id] = check
        all_control_ids << control_id
      end

      # This call will fail if the payable create fails or if any of adjustment calls fail.
      # The error will then be recorded against the payable (which is good).  Because this is in
      # a transaction in Intacct too, we're getting the same all or nothing semantics that we expect
      # from a standard DB transaction.  So, payable + checks are all created or none created - that's good.
      response = post_xml(payable.company, true, true, payable_xml, all_control_ids)

      check_control_ids.each_pair do |control_id, check|
        check.intacct_adjustment_key = extract_result_key response, control_id
        check.save!
      end

      payable.intacct_key = extract_result_key response, payable_control_id
      payable.intacct_upload_date = Time.zone.now
      payable.intacct_errors = nil
    rescue IntacctInvalidDimensionError => e
      send_dimension(e.dimension_type, e.value, e.value)
      retry
    rescue StandardError => e
      payable.intacct_errors = e.message
    end

    payable.save!
  end

  def send_check check, send_adjustment
    begin
      function_control_id = nil
      function_control_id, xml = @generator.generate_check_gl_entry_xml check

      control_ids = [function_control_id]
      adjustment_control_id = nil
      if send_adjustment
        adjustment_control_id, adjustment_xml = @generator.generate_ap_adjustment check, nil
        control_ids << adjustment_control_id
        xml += adjustment_xml
      end

      # Because this is in a transaction, all or nothing semantics apply, so either everything
      # posts together or nothing does, which is good because it means we can resend the full
      # request if needed.
      response = post_xml(check.company, true, true, xml, control_ids)

      check.intacct_key = extract_result_key response, function_control_id
      if adjustment_control_id
        check.intacct_adjustment_key = extract_result_key response, adjustment_control_id
      end
      check.intacct_upload_date = Time.zone.now
      check.intacct_errors = nil
    rescue IntacctInvalidDimensionError => e
      send_dimension(e.dimension_type, e.value, e.value)
      retry
    rescue StandardError => e
      check.intacct_errors = e.message
    end
    check.save!
  end

  def get_object_fields location_id, object_name, key, *fields
    function_control_id, xml = @generator.generate_get_object_fields object_name, key, *fields
    response = post_xml location_id, false, false, xml, function_control_id, read_only: true
    obj = REXML::XPath.first response, "//result[controlid = '#{function_control_id}']/data/#{object_name}"
    raise "Failed to find #{object_name} object with key #{key}." unless obj
    object_fields = {}
    obj.elements.each {|e| object_fields[e.name] = e.text}

    object_fields
  end

  # multiple keys can be passed using an array
  def read_object location_id, intacct_object_type, keys, fields: nil
    control_ids = []
    combined_xml = ""
    Array.wrap(keys).each do |key|
      function_control_id, xml = @generator.generate_read_query intacct_object_type, key, fields: fields
      control_ids << function_control_id
      combined_xml << xml
    end

    response = post_xml location_id, false, false, combined_xml, control_ids, request_options: {api_version: "3.0"}, read_only: true

    objects = []
    control_ids.each do |id|
      object = REXML::XPath.first response, "//result[controlid = '#{id}']/data/#{intacct_object_type}"
      objects << object if object
    end

    # If an Array was passed to keys, then return an array back
    if keys.is_a?(Array)
      objects
    else
      objects.first
    end
  end

  def list_objects location_id, intacct_object_type, query, fields: nil, max_results: 1000
    results = []
    function_control_id, xml = @generator.generate_read_by_query intacct_object_type, query, fields: fields
    response = post_xml location_id, false, false, xml, function_control_id, request_options: {api_version: "3.0"}, read_only: true
    data = parse_list_results response, function_control_id, results

    # Now determine if there's any more results that we have to retrieve
    result_id = nil
    while results.length < max_results && data.attributes["numremaining"].to_i > 0 && (result_id = data.attributes["resultId"].to_s).present?
      function_control_id, xml = @generator.generate_read_more result_id
      response = post_xml location_id, false, false, xml, function_control_id, request_options: {api_version: "3.0"}, read_only: true
      data = parse_list_results response, function_control_id, results
    end

    (results.length > max_results) ? results[0, max_results] : results
  end

  def sanitize_query_parameter_value value
    # Intacct requires escaping apostrophes in data with a \   .ie test'ing -> test\'ing
    # The extra slashes are there because \' in a gsub actually means "part of the string after the match"
    # So then we need to also escape that.
    value.to_s.gsub("'", "\\\\\'")
  end

  def parse_list_results response, function_control_id, results
    data = REXML::XPath.first response, "//result[controlid = '#{function_control_id}']/data"
    data.each_element {|e| results << e }
    data
  end
  private :parse_list_results

  def post_payment location_id, ap_payment
    function_control_id, xml = @generator.generate_ap_payment ap_payment
    response = post_xml location_id, false, false, xml, function_control_id, request_options: {api_version: "3.0"}
    extract_record_no(response, function_control_id, "appymt")
  end

  # Receives XML data that should be nested under the <content>
  # element of the Intacct request and sends it, returning the XML
  # response from the API.  The XML data should already be stringified (sans <?xml version..>)
  # DON'T use this method directly, use the other public feeder methods in this class.  The method
  # is primarily exposed as non-private for simplified testing.
  def post_xml location_id, transaction, unique_request, intacct_content_xml, function_control_id, request_options: {}, read_only: false
    connection_options = INTACCT_CONNECTION_INFO.merge(request_options)
    connection_options = connection_options.merge(self.class.intacct_config)

    # We're going to allow connecting to the production intacct system if the xml post is marked as read_only, regardless of the
    # status of the current system.
    can_send_request?(connection_options) unless read_only

    uri = URI.parse connection_options[:url]
    post = Net::HTTP::Post.new(uri)
    post["Content-Type"] = "x-intacct-xml-request"
    post.body = assemble_request_xml(location_id, transaction, unique_request, connection_options, intacct_content_xml)

    xml = nil
    begin
      xml = http_request(uri, post)
    rescue REXML::ParseException => e
      # basically, what we're doing is allowing the outer call to determine if it wants to retry this
      # failure...which comes about due to cloudflare sending back an HTML file w/ an error in it..which entails
      # a bad endpoint on Intacct's end.
      error = IntacctRetryError.new e.message
      error.set_backtrace e.backtrace
      raise error
    end

    # Verify all the control ids passed in resulted in a valid response.
    # There's no need for this now, but we may need to not fail if transaction == false and multiple control ids
    # are present.  Since in that scenario, any results w/ non-failed statuses would have taken effect in Intacct.
    Array.wrap(function_control_id).each {|id| handle_error xml, id}

    xml
  end

  def self.intacct_config
    @intacct_config ||= begin
      config = MasterSetup.secrets["intacct"]&.with_indifferent_access&.symbolize_keys

      # Since these properties get loaded to an XML file, need to encode all the values properly
      # Not expecting multi-level config values for this yet, so don't worry about parsing hashes,etc.
      if config.present?
        config.each_pair do |k, v|
          # Expected keys are
          config[k] = v.encode(xml: :text) if v.is_a?(String)
        end
      end

      config.presence
    end
    raise "No Intacct client configuration file found in secrets.yml." unless @intacct_config
    @intacct_config
  end

  private

    def can_send_request? connection_options
      raise "Cannot post to Intacct in development mode" unless production? || company_id(connection_options).include?("-sandbox")
    end

    def process_response response
      # The response from Intacct should always be an XML document.
      REXML::Document.new(response.body)
    rescue REXML::ParseException => e
      e.log_me ["Invalid Intacct API Response:\n" + response.body]
      raise e
    end

    def handle_error xml, function_control_id
      error_elements = REXML::XPath.each(xml, "//errormessage/error")

      if error_elements.size > 0
        errors = error_elements.collect {|el| extract_errors_information(el)}
        message = "Intacct API call failed with errors:\n#{errors.join("\n")}"

        # There seems to be a random error when posting data that pops up every so often that is not data related, just
        # random failures on the Intacct side.  Throw a retry error so that we can just retry the call again after some manner of delay.
        retry_error? error_elements, message
        # If the response indicates a dimension was missing, then raise that error so the client can potentially
        # directly handle that and send the dimension
        dimension_error?(error_elements, message)

        raise IntacctClientError, message
      else
        # We want to find the status associated with the function call we made
        status = xml.text("//result[controlid = '#{function_control_id}']/status")
        if status != "success"
          function = xml.text("//result[controlid = '#{function_control_id}']/function")
          raise IntacctClientError, "Intacct API Function call #{function} failed with status #{status}."
        end
      end

      xml
    end

    def extract_result_key xml, function_control_id
      xml.text("//result[controlid = '#{function_control_id}']/key")
    end

    def extract_record_no xml, function_control_id, object_type
      xml.text("//result[controlid = '#{function_control_id}']/data/#{object_type}/RECORDNO")
    end

    def assemble_request_xml location_id, transaction, unique_content, connection_options, intacct_content_xml
      # This uniquely identifies the content section part of the request, if uniqueid is true, then
      # ANY request with the same SHA-1 digest will fail (even non-transactional ones).  In general,
      # if we're just reading information from Intacct there's no point to requiring a unique transaction control
      # identifier.
      control_id = Digest::SHA1.hexdigest intacct_content_xml

      # The Thread.current below is a means of allowing code to force the usage of non-unique controld ids
      # This is solely for use when there's a hash collision with pushing data and it must be overridden.
      # This should ONLY ever be utilized from the command line.
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <request>
          <control>
            <senderid>#{connection_options[:sender_id]}</senderid>
            <password>#{connection_options[:sender_password]}</password>
            <controlid>#{control_id}</controlid>
            <uniqueid>#{((production? && unique_content == true && !Thread.current.thread_variable_get(:force_non_unique_intacct_request)) ? "true" : "false")}</uniqueid>
            <dtdversion>#{connection_options[:api_version]}</dtdversion>
          </control>
          <operation#{((transaction == true) ? ' transaction="true"' : "")}>
            <authentication>
              <login>
                <userid>#{connection_options[:user_id]}</userid>
                <companyid>#{company_id(connection_options)}</companyid>
                <password>#{connection_options[:user_password]}</password>
                #{(location_id.blank? ? "" : "<locationid>#{location_id}</locationid>")}
              </login>
            </authentication>
            <content>
        #{intacct_content_xml}
            </content>
          </operation>
        </request>
      XML
      xml
    end

    def company_id connection_options
      id = connection_options[:company_id]
      if MasterSetup.get.production?
        id
      else
        "#{id}-sandbox"
      end
    end

    def production?
      MasterSetup.get.production?
    end

    def extract_errors_information element
      "Error No: #{element.text("errorno")}\nDescription: #{element.text("description")}\nDescription 2: #{element.text("description2")}\nCorrection: #{element.text("correction")}" # rubocop:disable Layout/LineLength
    end

    def retry_error? error_elements, error_message
      # We only really want to retry at this point if the error text has a Correction message like:
      # "Check the transaction for errors or inconsistencies, then try again."
      error_elements.each do |el|
        if el.text("correction") =~ /Check the transaction for errors or inconsistencies/i
          raise IntacctRetryError, error_message
        end
      end

      false
    end

    def dimension_error? error_elements, error_message
      error_elements.each do |el|
        if el.text("description2") =~ /Invalid (.*) '(.*)' specified./
          dimension_type = nil
          if Regexp.last_match(1) == "Brokerage File"
            dimension_type = "Broker File"
          elsif Regexp.last_match(1) == "Freight File"
            dimension_type = "Freight File"
          end

          if dimension_type
            raise IntacctInvalidDimensionError.new(error_message, dimension_type, Regexp.last_match(2))
          end
        end
      end

      false
    end

end; end; end; end
