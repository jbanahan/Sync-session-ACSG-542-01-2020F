module OpenChain
  # Client to communicate with XLServer
  class XLClient
    # Create a client with the given ZeroMQ socket
    def initialize socket, path
      @socket = socket
      @path = path
    end

    # Send the given command Hash to the server and return a Hash with the response
    def send command
      json = command.to_json 
      r = {'errors'=>'Client error: did not successfully receive server response.'}
      begin
        @socket.send_string json
      ensure
        server_response = @socket.recv_string
        r = JSON.parse server_response
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
    def set_cell sheet, row, column, value, datatype
      c = {"command"=>"set_cell","path"=>@path,"payload"=>{"position"=>{"sheet"=>sheet,"row"=>row,"column"=>column},"cell"=>{"value"=>value,"datatype"=>datatype}}}
      send c
    end
    
    # wraps the create_sheet command
    def create_sheet name
      c = {"command"=>"create_sheet","path"=>@path,"payload"=>{"name"=>name}}
      send c
    end

    # wraps the save command
    def save alternate_location=nil
      loc = alternate_location ? alternate_location : @path
      c = {"command"=>"save","path"=>@path,"payload"=>{"alternate_location"=>loc}}
      send c
    end

  end
end
