module OpenChain
  class IntegrationClient
    def self.go remote_server, registration_port, system_code
      client = OpenChain::ZmqIntegrationClientConnection.new
      p = client.get_responder_port "tcp://#{remote_server}:#{registration_port}", system_code
      client.connect_to_responder "tcp://#{remote_server}:#{p}"
      r = true
      while r
        r = client.next_command do |cmd|
          IntegrationClientCommandProcessor.process_command cmd
        end
      end
    end
  end
  class IntegrationClientCommandProcessor
    def self.process_command command
      case command['request_type']
      when 'remote_file'
        process_remote_file command
      when 'shutdown'
        return 'shutdown'
      else
        return {'response_type'=>'error','message'=>"Unknown command: #{command}"}
      end
    end

    private
    def self.process_remote_file command
      t = OpenChain::S3.download_to_tempfile(OpenChain::S3.bucket_name,command['remote_path'])
      status_msg = 'Unknown error'
      begin
        dir, fname = Pathname.new(command['path']).split
        def t.original_filename=(fn); @fn = fn; end
        def t.original_filename; @fn; end
        t.original_filename= fname.to_s
        linkable = LinkableAttachmentImportRule.import t.path, fname.to_s, dir.to_s
        if linkable
          status_msg = linkable.errors.blank? ? 'success' : linkable.errors.full_messages.join("\n")
        elsif command['path'].include? '/to_chain/'
          status_msg = process_imported_file command, t
        else
          status_msg = "Can't figure out what to do for path #{command['path']}"
        end
      ensure
        t.unlink
      end
      return {'response_type'=>'remote_file','status'=>status_msg}
    end

    def self.process_imported_file command, file
      dir, fname = Pathname.new(command['path']).split
      folder_list = dir.to_s.split('/')
      user = User.where(:username=>folder_list[1]).first
      return "Username #{folder_list[1]} not found." unless user
      return "User #{user.username} is locked." unless user.active?
      ss = user.search_setups.where(:module_type=>folder_list[3],:name=>folder_list[4]).first
      return "Search named #{folder_list[4]} not found for module #{folder_list[3]}." unless ss
      imp = ss.imported_files.build(:starting_row=>1,:starting_column=>1,:update_mode=>'any')
      imp.attached = file
      imp.module_type = ss.module_type
      imp.user = user
      imp.save
      return "Imported file could not be save: #{imp.errors.full_messages.join("\n")}" unless imp.errors.blank?
      imp.process user, {:defer=>true}
      return "success"
    end
  end

  class ZmqIntegrationClientConnection
    # Internally used socket for getting commands from server, set by connect_to_responder
    attr_reader :responder_socket

    # Get the port number from the server that should be used for the REP connection
    def get_responder_port registration_server_uri, my_system_code
      ctx = ZMQ::Context.new
      s = ctx.socket ZMQ::REQ
      s.connect registration_server_uri
      begin
        request_content = {:request_type=>'register',:instance_name=>my_system_code}.to_json
        s.send_string request_content
        response_hash = ActiveSupport::JSON.decode s.recv_string
        bp = response_hash['bound_port']
        if bp
          return bp
        else
          raise "Error registering with integration server: #{response_hash}"
        end
      ensure
        s.close
      end
    end

    def connect_to_responder uri
      ctx = ZMQ::Context.new
      @responder_socket = ctx.socket ZMQ::REP
      @responder_socket.connect uri
    end

    #return a hash with the next command from the server
    #optionally pass in a socket if you haven't called connect_to_responder
    #the block will be passed the hash sent from the server and must return a hash that will be sent back to the server as json
    def next_command socket=nil
      s = socket ? socket : @responder_socket
      raise "Cannot get next Integration Server command: Socket not set." unless s 
      r = yield(ActiveSupport::JSON.decode s.recv_string)
      s.send_string r.to_json
      r!='shutdown'
    end

    #close the socket if it exists
    def close
      @responder_socket.close if @responder_socket
    end
  end
end
