require 'digest'

module OpenChain
  # Client to communicate with XLServer
  class XLClient
  
    #initialize a new XLClient for the attached object
    def self.new_from_attachable attachable
      self.new attachable.attached.path
    end

    # if true the client will raise exceptions instead of including the errors in the JSON response (default = false)
    attr_accessor :raise_errors
    attr_reader :path
    
    def initialize path, options = {}
      @options = {scheme: "s3", bucket: Rails.configuration.paperclip_defaults[:bucket]}.merge options

      @path = assemble_file_path path, @options
      @session_id = Digest::SHA1.hexdigest "#{MasterSetup.get.uuid}-#{Time.now.to_f}-#{@path}" #should be unqiue enough
      base_url = "#{YAML.load(IO.read('config/xlserver.yml'))[Rails.env]['base_url']}/process"
      @uri = URI(base_url)
    end

    # Send the given command Hash to the server and return a Hash with the response
    def send command
      r = private_send command
      raise OpenChain::XLClientError.new(r['errors'].join("\n")) if @raise_errors && r.is_a?(Hash) && !r['errors'].blank? 
      r
    end

    #wraps the `new` command
    def new 
      c = {"command"=>"new","path"=>@path}
      send c
    end

    # wraps the get_cell command
    # takes the sheet, row, column number, and an optional boolean argument specifying whether to return the value, datatype has 
    # that xlserver returns or just the value (default is to only return the value)
    def get_cell sheet, row, column, value_only = true
      c = {"command"=>"get_cell","path"=>@path,"payload"=>{"sheet"=>sheet,"row"=>row,"column"=>column}}
      cell = process_cell_response send c
      # Strip out the outer "cell" hash, there's no point at all to returning it
      cell = cell["cell"]
      if cell && value_only
        cell["value"]
      else 
        cell
      end
    end

    # wraps the set_cell command
    def set_cell sheet, row, column, value
      datatype = determine_datatype value
      output_value = format_value datatype, value
      c = {"command"=>"set_cell","path"=>@path,"payload"=>{"position"=>{"sheet"=>sheet,"row"=>row,"column"=>column},"cell"=>{"value"=>output_value,"datatype"=>datatype}}}
      send c
    end
    
    # wraps the create_sheet command
    def create_sheet name
      c = {"command"=>"create_sheet","path"=>@path,"payload"=>{"name"=>name}}
      send c
    end

    def clone_sheet source_sheet_index, sheet_name=nil
      payload = {"source_index" => source_sheet_index}
      payload['name'] = sheet_name unless sheet_name.blank?
      c = {"command"=>"clone_sheet","path"=>@path,"payload"=>payload}
      response = send c
      validate_response response
      response['sheet_index']
    end

    def delete_sheet index
      c = {"command"=>"delete_sheet","path"=>@path,"payload"=>{"index"=>index}}
      response = send c
      validate_response response
      nil
    end

    def delete_sheet_by_name name
      c = {"command"=>"delete_sheet","path"=>@path,"payload"=>{"name"=>name}}
      response = send c
      validate_response response
      nil
    end

    # wraps the last_row_number command, converting result into integer or throwing exception
    def last_row_number sheet_number
      c = {"command"=>"last_row_number","path"=>@path,"payload"=>{"sheet_index"=>sheet_number}}
      r = send c
      return r['result'] if r['result']
      raise_error r
    end

    def get_row sheet, row
      c = {"command"=>"get_row","path"=>@path,"payload"=>{"sheet"=>sheet,"row"=>row}}
      r = send c
      process_row_response r
    end

    def get_rows sheet: 0, number_of_rows: 50, row: 
      c = {"command"=>"get_rows", "path"=>@path, "payload"=>{"sheet"=>sheet, "row"=>row, "range"=>number_of_rows}}
      r = send c
      validate_response r
      # The response should be a 2 dimensional array, each row should be parsable as a standard "get_row" response value
      r.map {|row| parse_row_values_to_array(row) }
    end

    def get_row_as_column_hash sheet, row
      parse_row_values_to_hash(get_row(sheet, row))
    end

    # call get_row_values for all rows in sheet and yield each row's resulting array
    def all_row_values sheet_number=0, starting_row_number = 0, chunk_size = 50
      r = block_given? ? nil : []
      lrn = last_row_number(sheet_number)
      # Last row number is actually the zero indexed row to retrieve, so make sure we're including that as part of the
      # row counts we need to grab
      rows_to_retrieve = (lrn + 1) - starting_row_number
      rows_retrieved = 0
      begin
        to_retrieve = [chunk_size, (rows_to_retrieve - rows_retrieved)].min

        rows = get_rows(row: starting_row_number, sheet: sheet_number, number_of_rows: to_retrieve)
        rows_retrieved += to_retrieve
        starting_row_number += to_retrieve

        if block_given?
          rows.each {|row| yield row }
        else
          rows.each {|row| r << row }
        end
      end while rows_retrieved < rows_to_retrieve

      r
    end

    def get_row_values sheet, row
      parse_row_values_to_array(get_row(sheet, row))
    end

    def parse_row_values_to_hash response
      r = {}
      response.each do |c|
        c = process_cell_response c
        col = c['position']['column']
        r[col] =  c['cell']
      end
      r
    end
    private :parse_row_values_to_hash

    def parse_row_values_to_array response
      r = parse_row_values_to_hash(response)

      return [] if r.blank?
      # I think, technically, there can be missing index values here (.ie 0,1,2,5), which we'll will want to set as as null values
      # for the index is the array so its a true representation of the grid in the spreadsheet.
      values = []
      (0..r.keys.sort.last).each do |x|
        values << (r[x] ? r[x]["value"] : nil)
      end

      values
    end
    private :parse_row_values_to_array

    def copy_row sheet, source_row, destination_row
      cmd = {'command'=>'copy_row','path'=>@path,'payload'=>{'sheet'=>sheet,'source_row'=>source_row,'destination_row'=>destination_row}}
      r = send cmd
      process_row_response r
    end

    # wraps the save command
    def save alternate_location=nil, alternate_location_options = {}
      alternate_path = (alternate_location.blank? ? @path : assemble_file_path(alternate_location, @options.merge(alternate_location_options)))
      c = {"command"=>"save","path"=>@path,"payload"=>{"alternate_location"=>alternate_path}}
      send c
    end

    def set_row_color sheet, row, color
      # Color must be one of the following values (these come from the IndexedColors java class in the POI library used by xlserver )
      # AQUA, AUTOMATIC, BLACK, BLUE, BLUE_GREY, BRIGHT_GREEN, BROWN, CORAL, CORNFLOWER_BLUE, DARK_BLUE, DARK_GREEN, DARK_RED, DARK_TEAL, DARK_YELLOW, 
      # GOLD, GREEN, GREY_25_PERCENT, GREY_40_PERCENT, GREY_50_PERCENT, GREY_80_PERCENT, INDIGO, LAVENDER, LEMON_CHIFFON, LIGHT_BLUE, LIGHT_CORNFLOWER_BLUE, 
      # LIGHT_GREEN, LIGHT_ORANGE, LIGHT_TURQUOISE, LIGHT_YELLOW, LIME, MAROON, OLIVE_GREEN, ORANGE, ORCHID, PALE_BLUE, PINK, PLUM, RED, ROSE, ROYAL_BLUE, 
      # SEA_GREEN, SKY_BLUE, TAN, TEAL, TURQUOISE, VIOLET, WHITE, YELLOW
      
      cmd = {'command' => 'set_color', 'path' => @path, "payload" => {"position"=> {"sheet"=>sheet,"row"=>row}, "color" => color.to_s.upcase}}
      r = send cmd
      process_cell_response r
      nil
    end

    def set_cell_color sheet, row, column, color
      # Color must be one of the following values (these come from the IndexedColors java class in the POI library used by xlserver )
      # AQUA, AUTOMATIC, BLACK, BLUE, BLUE_GREY, BRIGHT_GREEN, BROWN, CORAL, CORNFLOWER_BLUE, DARK_BLUE, DARK_GREEN, DARK_RED, DARK_TEAL, DARK_YELLOW, 
      # GOLD, GREEN, GREY_25_PERCENT, GREY_40_PERCENT, GREY_50_PERCENT, GREY_80_PERCENT, INDIGO, LAVENDER, LEMON_CHIFFON, LIGHT_BLUE, LIGHT_CORNFLOWER_BLUE, 
      # LIGHT_GREEN, LIGHT_ORANGE, LIGHT_TURQUOISE, LIGHT_YELLOW, LIME, MAROON, OLIVE_GREEN, ORANGE, ORCHID, PALE_BLUE, PINK, PLUM, RED, ROSE, ROYAL_BLUE, 
      # SEA_GREEN, SKY_BLUE, TAN, TEAL, TURQUOISE, VIOLET, WHITE, YELLOW

      cmd = {'command' => 'set_color', 'path' => @path, "payload" => {"position"=> {"sheet"=>sheet,"row"=>row, "column"=>column}, "color" => color.to_s.upcase}}
      r = send cmd
      process_cell_response r
      nil
    end

    # helper method to find a cell in a row hash by column number
    def self.find_cell_in_row row, column_number
      row.each do |r|
        return r['cell'] if r['position']['column']==column_number
      end
      nil
    end

    # This method coerces the given value into the String equivalent
    # to be used for active model attributes.  In essence, the method
    # trims trailing zeros from all numeric values - which tend to get sent
    # in Excel files for string model attributes.
    def self.string_value value
      if value.is_a? Numeric
        # BigDecimal to_s uses engineering notation (stupidly) by default
        value = value.is_a?(BigDecimal) ? value.to_s("F") : value.to_s
        trailing_zeros = value.index /\.0+$/
        if trailing_zeros 
          value = value[0, trailing_zeros]
        end
      elsif !value.is_a? String
        value = value.to_s
      end
      
      value
    end
    
    private
    def private_send command
      command['session'] = @session_id
      json = command.to_json 
      r = {'errors'=>'Client error: did not successfully receive server response.'}
      retry_count = 0
      response_body = "no response"
      begin
        req = Net::HTTP::Post.new(@uri.path)
        req.set_content_type "application/json", "charset"=>json.encoding.to_s
        req.body = json
        res = Net::HTTP.start(@uri.host,@uri.port) do |http|
          http.read_timeout = 600
          http.request req
        end
        response_body = get_response_body res
        r = JSON.parse response_body
      rescue
        retry_count += 1
        if retry_count < 3
          sleep 1
          retry
        end
        r = {'errors'=>["Communications error: #{$!.message}", "Command: #{command.to_s}", "Response Body: #{response_body}", "Retry Count: #{retry_count}"]}
      end
      r
    end

    def get_response_body response
      # This is a fix for the absolutely moronic implementation detail of Net::HTTP not setting the response body
      # charset based on the server's content-type response header.

      content_type = response['content-type']
      if content_type && content_type['charset']
        # Split the content_type header on ; (ie. header field separator) -> Content-Type: text/html; charset=UTF-8
        charset = content_type.split(';').select do |key|
          # Find the header key value that contains a charset
          key['charset']
        end

        # Only use the first charset (technically, there's nothing preventing multiple of them from being supplied in the header)
        # and split it into a key value pair array
        charset = charset.first.to_s.split("=")
        if charset.length == 2
          # If the server supplies an invalid or unsupported charset, we'll just handle the error and ignore it.
          # This isn't really any worse than what was happening before where the default charset was utilized.
          response.body.force_encoding(charset.last.strip) rescue ArgumentError
        end
      end

      response.body
    end

    def process_row_response r
      if r.is_a? Array
        r.each do |cell_set|
          process_cell_response cell_set
        end
      else
        raise_error r
      end
      r
    end

    def process_cell_response cell
      if cell["errors"]
        raise_error cell
      else
        cell['cell']['value'] = Time.at(cell['cell']['value']) if cell && cell['cell'] && cell['cell']['datatype'] == "datetime"
        cell
      end
    end

    def validate_response response
      if response.is_a?(Hash) && response['errors']
        raise_error response
      end
    end

    def raise_error r
      error_messages = "Error: " + r.to_s
      error_messages= r['errors'].respond_to?('join') ? r['errors'].join("\n") : r['errors'].to_s if r['errors']
      raise error_messages
    end
    def determine_datatype value
      return "datetime" if value.is_a?(Date) || value.is_a?(DateTime) || value.is_a?(Time)
      return "number" if value.is_a?(Numeric)
      "string" 
    end
    def format_value datatype, value
      r = value
      case datatype
      when "datetime"
        r = value.respond_to?('to_time') ? value.to_time.to_i : value.to_i
      end
      r
    end

    def assemble_file_path path, options
      # Assume anything that looks like a URI already is one and doesn't need to be assembled.
      if path =~ /\w+:\/\/.+/
        path
      else
        uri_scheme = options[:scheme]
        
        # The scheme tells the xlserver what sort of backend to use (s3 will basically always be what we'll use here),
        # the first machine name in the full hostname for s3 paths determines the bucket to use.  The rest of the hostname
        # is superfluous at the moment - I just used the actual amazon host. The path itself is the s3 object's key,
        # or in the case of file:// uri's the path on the xlserver to the file.
        if uri_scheme.to_s.downcase == "s3"
          bucket = options[:bucket]
          "#{uri_scheme}://#{bucket}.s3.amazonaws.com/#{path}"
        else
          # Use file:///path/to/file.xls to access the file relative to the xlserver's current working directory
          # User file:////home/user/path/to/file.xls to access as absolute path (note double slash after the file://)
          "#{uri_scheme}:///#{path}"
        end
      end
    end
  end

  class XLClientError < RuntimeError
    
  end
end
