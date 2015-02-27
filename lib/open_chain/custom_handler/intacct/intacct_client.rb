require 'open_chain/http_client'
require 'open_chain/custom_handler/intacct/intacct_xml_generator'
require 'digest/sha1'
require 'rexml/document'

module OpenChain; module CustomHandler; module Intacct; class IntacctClient < OpenChain::HttpClient
  # This is the answer to the security question: :$hSU'ZW^x6>E7'

  INTACCT_CONNECTION_INFO ||= {
    :sender_id => 'vandegriftinc',
    :sender_password => '9gUMGbFIMy',
    :url => 'https://api.intacct.com/ia/xml/xmlgw.phtml',
    :company_id => 'vfi',
    :user_id => 'integration',
    # encode call is because of the & and > in the password since we're just templating the xml as a string below rather than
    # building the xml piece by piece
    :user_password => 'b,Z+&W>6dFR:'.encode(xml: :text),
    :api_version => "2.1"
  }.freeze

  class IntacctClientError < StandardError
  end

  class IntacctRetryError < IntacctClientError
  end

  def initialize xml_generator = IntacctXmlGenerator.new
    @generator = xml_generator
  end

  def self.async_send_dimension type, id, value, company = nil
    self.new.send_dimension type, id, value, company
  end

  def send_dimension type, id, value, company = nil
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
    rescue => e
      # There must be some slight delay when dimensions are created vs. when they're available to the API,
      # since we're only creating the same dimension one at a time (via locking) and we're still getting duplicate
      # create errors.  Just look for an error message stating the transaction was already created and then don't 
      # bother with the error reporting since our end goal of getting the dimension out there has been met we
      # don't care if this particular call errored.
      message = e.message.try(:downcase)
      if message.include?("a successful transaction has already been recorded") || message.include?("another class with the given value(s)")
        return id
      else
        e.log_me ["Failed to find and/or create dimension #{type} #{id} for location #{company}."]
        return nil
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
    rescue => e
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
    begin
      # We need to find the vendor terms, there's no straight forward way to accomplish this without first doing
      # a get request against the API.
      fields = get_object_fields payable.company, "vendor", payable.vendor_number, "termname"
      vendor_terms = fields['termname']
      raise "Failed to retrieve Terms for Vendor #{payable.vendor_number}.  Terms must be set up for all vendors." if vendor_terms.blank?

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
    rescue => e
      payable.intacct_errors = e.message
    end

    payable.save!
  end

  def send_check check, send_adjustment
    begin
      function_control_id = nil
      function_control_id, xml = @generator.generate_check_gl_entry_xml check

      control_ids = [function_control_id]
      check_control_id = function_control_id
      adjustment_control_id = nil
      if send_adjustment
        adjustment_control_id, adjustment_xml = @generator.generate_ap_adjustment check, nil
        control_ids << adjustment_control_id
        xml << adjustment_xml
      end

      response = post_xml(check.company, true, true, xml, control_ids)

      check.intacct_key = extract_result_key response, function_control_id
      if adjustment_control_id
        check.intacct_adjustment_key = extract_result_key response, adjustment_control_id
      end
      check.intacct_upload_date = Time.zone.now
      check.intacct_errors = nil
    rescue => e
      check.intacct_errors = e.message
    end
    check.save!
  end

  def get_object_fields location_id, object_name, key, *fields
    function_control_id, xml = @generator.generate_get_object_fields object_name, key, *fields
    response = post_xml location_id, false, false, xml, function_control_id
    obj = REXML::XPath.first response, "//result[controlid = '#{function_control_id}']/data/#{object_name}"
    raise "Failed to find #{object_name} object with key #{key}." unless obj
    object_fields = {}
    obj.elements.each {|e| object_fields[e.name] = e.text}

    object_fields
  end

  # Receives XML data that should be nested under the <content>
  # element of the Intacct request and sends it, returning the XML
  # response from the API.  The XML data should already be stringified (sans <?xml version..>)
  # DON'T use this method directly, use the other public feeder methods in this class.  The method
  # is primarily exposed as non-private for simplified testing.
  def post_xml location_id, transaction, unique_request, intacct_content_xml, function_control_id, request_options = {}
    raise "Cannot post to Intacct in development mode" unless production?

    connection_options = INTACCT_CONNECTION_INFO.merge(request_options)

    uri = URI.parse connection_options[:url]
    post = Net::HTTP::Post.new(uri)
    post["Content-Type"] = "x-intacct-xml-request"
    post.body = assemble_request_xml(location_id, transaction, unique_request, connection_options, intacct_content_xml)

    xml = http_request(uri, post)

    # Verify all the control ids passed in resulted in a valid response.
    # There's no need for this now, but we may need to not fail if transaction == false and multiple control ids
    # are present.  Since in that scenario, any results w/ non-failed statuses would have taken effect in Intacct.
    control_ids = function_control_id.respond_to?(:each) ? function_control_id : [function_control_id]
    control_ids.each {|id| handle_error xml, id}

    xml
  end

  private
    
    def process_response response
      # The response from Intacct should always be an XML document.
      begin
        REXML::Document.new(response.body)
      rescue REXML::ParseException => e
        e.log_me ["Invalid Intacct API Response:\n" + response.body]
        raise e
      end
    end

    def handle_error xml, function_control_id
      error_elements = REXML::XPath.each(xml, "//errormessage/error")

      if error_elements.size > 0
        # There seems to be a random error when posting data that pops up every so often that is not data related, just 
        # random failures on the Intacct side.  Throw a retry error so that we can just retry the call again after some manner of delay.
        can_retry = retry_error? error_elements

        errors = error_elements.collect {|el| extract_errors_information(el)}

        message = "Intacct API call failed with errors:\n#{errors.join("\n")}"

        if can_retry
          raise IntacctRetryError, message
        else
          raise IntacctClientError, message
        end
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

    def assemble_request_xml location_id, transaction, unique_content, connection_options, intacct_content_xml
      # This uniquely identifies the content section part of the request, if uniqueid is true, then
      # ANY request with the same SHA-1 digest will fail (even non-transactional ones).  In general,
      # if we're just reading information from Intacct there's no point to requiring a unique transaction control
      # identifier.
      control_id = Digest::SHA1.hexdigest intacct_content_xml
      xml = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<request>
  <control>
    <senderid>#{connection_options[:sender_id]}</senderid>
    <password>#{connection_options[:sender_password]}</password>
    <controlid>#{control_id}</controlid>
    <uniqueid>#{((production? && unique_content == true) ? "true" : "false")}</uniqueid>
    <dtdversion>#{connection_options[:api_version]}</dtdversion>
  </control>
  <operation#{((transaction == true) ? ' transaction="true"' : "" )}>
    <authentication>
      <login>
        <userid>#{connection_options[:user_id]}</userid>
        <companyid>#{connection_options[:company_id]}</companyid>
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

    def production?
      Rails.env.production?
    end

    def extract_errors_information el
      "Error No: #{el.text("errorno")}\nDescription: #{el.text("description")}\nDescription 2: #{el.text("description2")}\nCorrection: #{el.text("correction")}"
    end

    def retry_error? error_elements
      # We only really want to retry at this point if the error text only has a BL01001973 Could not create Document record!
      # and a XL03000009 error.  This seems to indicate a random, transient error.
      # All failures seem to have BL01001973 errors, but most seem to have other actual reasons listed for the error,
      # the ones that don't seem to work fine if you just attempt to load them again later, hence the retry.
      bl_count = 0
      xl_count = 0

      error_elements.each do |el|
        bl_count += 1 if el.text("errorno") == "BL01001973"
        xl_count += 1 if el.text("errorno") == "XL03000009"
      end

      return bl_count == 1 && xl_count == 1
    end

end; end; end; end
