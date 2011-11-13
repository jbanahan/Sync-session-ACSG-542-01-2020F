
module OpenChain
  # Client to communicate with XLServer
  class XLClient
    # Create a client with the Patron::Session 
    def initialize path, session=nil  
      @path = path
      base_url = "#{YAML.load(IO.read('config/xlserver.yml'))[Rails.env]['base_url']}/process"
      @uri = URI(base_url)
    end

    # Send the given command Hash to the server and return a Hash with the response
    def send command
      json = command.to_json 
      r = {'errors'=>'Client error: did not successfully receive server response.'}
      begin
        req = Net::HTTP::Post.new(@uri.path)
        req.body = json
        res = Net::HTTP.start(@uri.host,@uri.port) do |http|
          http.request req
        end
        r = JSON.parse res.body
      rescue
        puts $!
        puts $!.backtrace
        r = {'errors'=>["Communications error: #{$!.message}"]}
      end
      r
    end

    #wraps the `new` command
    def new 
      c = {"command"=>"new","path"=>@path}
      send c
    end

    # wraps the get_cell command
    # takes the sheet, row, and column numbers
    def get_cell sheet, row, column
      c = {"command"=>"get_cell","path"=>@path,"payload"=>{"sheet"=>sheet,"row"=>row,"column"=>column}}
      send c
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
    def process_row_response r
      if r.is_a? Array
        r.each do |cell_set|
          cell_set['cell']['value'] = Time.at(cell_set['cell']['value']) if cell_set['cell']['datatype'] == "datetime"
        end
      else
        raise_error r
      end
      r
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
end
