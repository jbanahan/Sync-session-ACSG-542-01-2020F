require 'aws-sdk'
module OpenChain
  class IntegrationClient
    def self.go system_code
      sqs = AWS::SQS.new(YAML::load_file 'config/s3.yml')
      q = sqs.queues.create system_code
      running = true
      while running
        in_memory_queue = []
        while q.visible_messages > 0
          q.receive_message do |m|
            in_memory_queue << m
            m.visibility_timeout = 300 # 5 minutes
          end
        end
        in_memory_queue.sort! {|x,y| x.sent_timestamp <=> y.sent_timestamp}
        in_memory_queue.each do |m|
          cmd = JSON.parse m.body
          r = IntegrationClientCommandProcessor.process_command cmd
          running = false if r=='shutdown'
          m.delete
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
