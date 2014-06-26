require 'open_chain/http_client'
require 'open_chain/custom_handler/intacct/intacct_xml_generator'
require 'digest/sha1'
require 'rexml/document'

module OpenChain; module CustomHandler; module Intacct; class IntacctClient < OpenChain::HttpClient
  # This is the answer to the security question: :$hSU'ZW^x6>E7'

  INTACCT_CONNECTION_INFO ||= {
    :sender_id => 'vandegriftinc',
    :sender_password => '9gUMGbFIMy',
    :url => 'https://www.intacct.com/ia/xml/xmlgw.phtml',
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
    # Need to lock on the dimension type, id, so only one process is trying to send a dimension at a time.
    # Otherwise, due to the way we trigger a whole bunch of dimension sends on Alliance invoice retrievals
    # there's a very good chance we'll try and create the same dimension multiple times due to the inherent
    # race conditions between checking intacct for the dimension value and then attempting to create them.
    Lock.acquire("IntacctDimension-#{type}-#{id}", temp_lock: true) do 
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

  def send_payable payable
    begin
      response = nil
      function_control_id = nil
      # Check if we have a check number, if so, that means we're sending a check and not a standard bill
      if [IntacctPayable::PAYABLE_TYPE_ADVANCED, IntacctPayable::PAYABLE_TYPE_CHECK].include?(payable.payable_type)
        function_control_id, response = send_check payable
      else
        function_control_id, response = send_bill payable
      end

      payable.intacct_key = extract_result_key response, function_control_id
      payable.intacct_upload_date = Time.zone.now
      payable.intacct_errors = nil
    rescue => e
      payable.intacct_errors = e.message
    end
    payable.save!
  end

  def send_bill payable
    # We need to find the vendor terms, there's no straight forward way to accomplish this without first doing
    # a get request against the API.
    fields = get_object_fields payable.company, "vendor", payable.vendor_number, "termname"
    vendor_terms = fields['termname']
    raise "Failed to retrieve Terms for Vendor #{payable.vendor_number}.  Terms must be set up for all vendors." if vendor_terms.blank?

    function_control_id, xml = @generator.generate_payable_xml payable, vendor_terms
    [function_control_id, post_xml(payable.company, true, true, xml, function_control_id)]
  end

  def send_check payable
    function_control_id, xml = @generator.generate_check_gl_entry_xml payable
    [function_control_id, post_xml(payable.company, true, true, xml, function_control_id)]
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
    connection_options = INTACCT_CONNECTION_INFO.merge(request_options)

    uri = URI.parse connection_options[:url]

    post = Net::HTTP::Post.new(uri)
    post["Content-Type"] = "x-intacct-xml-request"
    post.body = assemble_request_xml(location_id, transaction, unique_request, connection_options, intacct_content_xml)

    xml = http_request(uri, post)

    handle_error xml, function_control_id
  end

  private
    
    def process_response response
      # The response from Intacct should always be an XML document.
      REXML::Document.new(response.body)
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
      retry_data = {"BL01001973" => ["Could not create Document record!"]}

      error_elements.each do |el|
        return true if retry_data[el.text("errorno")].to_a.include? el.text("description2")
      end
      false
    end

end; end; end; end