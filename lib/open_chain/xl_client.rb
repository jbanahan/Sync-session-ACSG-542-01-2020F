module OpenChain
  # Client to communicate with XLServer
  class XLClient
  
    # if true the client will raise exceptions instead of including the errors in the JSON response (default = false)
    attr_accessor :raise_errors
    def initialize path 
      @path = path
      @session_id = "#{MasterSetup.get.uuid}-#{Process.pid}" #should be unqiue enough
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

    def get_row_as_column_hash sheet, row
      resp = get_row sheet, row
      r = {}
      resp.each do |c|
        col = c['position']['column']
        r[col] = c['cell']
      end
      r
    end

    def get_row_values sheet, row
      r = get_row_as_column_hash sheet, row

      # I think, technically, there can be missing index values here (.ie 0,1,2,5), which we'll will want to set as as null values
      # for the index is the array so its a true representation of the grid in the spreadsheet.
      values = []
      (0..r.keys.sort.last).each do |x|
        values << (r[x] ? r[x]["value"] : nil)
      end

      values
    end

    def copy_row sheet, source_row, destination_row
      cmd = {'command'=>'copy_row','path'=>@path,'payload'=>{'sheet'=>sheet,'source_row'=>source_row,'destination_row'=>destination_row}}
      r = send cmd
      process_row_response r
    end

    # wraps the save command
    def save alternate_location=nil
      loc = alternate_location ? alternate_location : @path
      c = {"command"=>"save","path"=>@path,"payload"=>{"alternate_location"=>loc}}
      send c
    end

    # helper method to find a cell in a row hash by column number
    def self.find_cell_in_row row, column_number
      row.each do |r|
        return r['cell'] if r['position']['column']==column_number
      end
      nil
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
  end
  class XLClientError < RuntimeError
    
  end
end
