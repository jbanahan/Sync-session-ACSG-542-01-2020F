module OpenChain
  class IntegrationClient
    # Connect to the integration server and begin handling requests
    def go(server_connection_string)
      ctx = ZMQ::Context.new
      socket = ctx.socket ZMQ::REQ
      socket.connect server_connection_string
      go_with_socket socket
    end

    # Run with given ZeroMQ socket already set to the integration server's registration socket
    # This is here to simplify unit testing. You should just use the regular go method, which calls this.
    def go_with_socket(socket)

    end
  end
end
