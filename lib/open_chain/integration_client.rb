require 'aws-sdk'
require 'open_chain/s3'
module OpenChain
  class IntegrationClient
    def self.go system_code, shutdown_if_not_schedule_server = false
      sqs = AWS::SQS.new(YAML::load_file 'config/s3.yml')
      q = sqs.queues.create system_code
      running = true
      while running
        begin
          in_memory_queue = []
          if ScheduleServer.active_schedule_server?
            while q.visible_messages > 0
              q.receive_message do |m|
                in_memory_queue << m
                m.visibility_timeout = 300 # 5 minutes
              end
            end
          elsif shutdown_if_not_schedule_server
            running = false
          end
          in_memory_queue.sort! {|x,y| x.sent_timestamp <=> y.sent_timestamp}
          in_memory_queue.each do |m|
            cmd = JSON.parse m.body
            r = IntegrationClientCommandProcessor.process_command cmd
            raise r['message'] if r['response_type']=='error'
            running = false if r=='shutdown'
            m.delete
          end
        rescue
          $!.log_me
        end
        sleep 5
      end
    end
  end
  class IntegrationClientCommandProcessor
    def self.process_command command
      case command['request_type']
      when 'remote_file'
        return process_remote_file command
      when 'shutdown'
        return 'shutdown'
      else
        return {'response_type'=>'error','message'=>"Unknown command: #{command}"}
      end
    end

    private
    def self.process_remote_file command
      t = OpenChain::S3.download_to_tempfile(OpenChain::S3.integration_bucket_name,command['remote_path'])
      status_msg = 'Unknown error'
      response_type = 'error'
      begin
        dir, fname = Pathname.new(command['path']).split
        def t.original_filename=(fn); @fn = fn; end
        def t.original_filename; @fn; end
        t.original_filename= fname.to_s
        linkable = LinkableAttachmentImportRule.import t, fname.to_s, dir.to_s
        if linkable
          if linkable.errors.blank?
            status_msg = 'success'
            response_type = 'remote_file'
          else
            status_msg = linkable.errors.full_messages.join("\n")
          end
        elsif command['path'].include? '/to_chain/'
          status_msg = process_imported_file command, t
          response_type = 'remote_file' if status_msg == 'success'
        else
          status_msg = "Can't figure out what to do for path #{command['path']}"
        end
      ensure
        t.unlink
      end
      return {'response_type'=>response_type,(response_type=='error' ? 'message' : 'status')=>status_msg}
    end

    # expects path like /username/to_chain/module/search_name/file.ext
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
end
