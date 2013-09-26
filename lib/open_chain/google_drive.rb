require 'google/api_client'
require 'google/api_client/auth/installed_app'
require 'tempfile'

module OpenChain
  # This class is for interfacing with Google Drive.  It attempts to be API compatible with the OpenChain::S3 client.
  # In general, this means that where you see "bucket" used in S3, in Google Drive, we user user account email instead.
  # In place of key, we use a file path.
  class GoogleDrive

    def self.default_user_account environment = Rails.env
      environment == "production" ? "integration@vandegriftinc.com" : "integration-dev@vandegriftinc.com"
    end

    # Uploads the provided file to the specified path under the user account specified.
    # 
    # user_email - a drive email account that has already been authorized for access (.ie there's a reference to it in google_drive.yml)
    # If blank/nil, the system default will be used.
    # path - a standard path like 'folder/subfolder/file.txt'.  The path may consist solely of a filename, but it MUST have a name.
    # file - a IO/File object or a string path to the file to upload
    def self.upload_file user_email, path, file, options = {}
      client = get_client(user_email)
      # Returns the new file's id
      client.upload_file path, file, options
    end

    # Downloads the Google Drive data specified by the user/path.  The tempfile
    # created will attempt to use the filename from the path as a template for naming the tempfile created.
    # Meaning, at a minimum, the file name name should retain the same file extension that
    # it currently has on the Drive file system.
    #
    # If a block is passed, the tempfile is yielded to the block as the sole argument and cleanup
    # of the tempfile is handled transparently to the caller.  The tempfile will be set to read from the
    # beginning of the file when yielded.
    def self.download_to_tempfile user_email, path
      client = get_client(user_email)

      tempfile = nil
      begin
        tempfile = Tempfile.new([File.basename(path, ".*"), File.extname(path)])
        tempfile.binmode

        client.download_file path, tempfile

        if block_given?
          return yield tempfile
        else
          return tempfile
        end
      rescue Exception
        errored = true
        raise $!
      ensure
        tempfile.close! if tempfile && (errored || block_given?)
      end
    end

    # Returns the file id of the file referenced by the path.
    def self.find_file_id user_email, path
      object_hash = find_object_hash get_client(user_email), path, :file
      object_hash ? object_hash[:id] : nil
    end

    # Returns the file id of the folder referenced by the path.
    def self.find_folder_id user_email, path
      object_hash = find_object_hash get_client(user_email), path, :folder
      object_hash ? object_hash[:id] : nil
    end

    # Returns the drive object id of the path / object type referenced.
    def self.find_object_hash client, path, object_type = :file
      object_hash = nil
      begin
        object_hash = client.find_object_id path, nil, object_type, false
      rescue FileNotFoundError
        # don't care, there's just no need to propigate this error out in this situation
      end

      object_hash
    end
    private_class_method :find_object_hash

    # Perminently deletes the file object this path references.
    # Using 'delete' instead of delete_file to preserve S3 API parity
    def self.delete user_email, path
      delete_object user_email, path, :file
      nil
    end

    # Perminently deletes the folder object this path references.
    # BEWARE - This also deletes EVERYTHING below the folder too.
    def self.delete_folder user_email, path
      delete_object user_email, path, :folder
      nil
    end

    # Perminently deletes the file/folder object this path references
    # BEWARE - deleting a folder WILL delete all files below the folder.
    def self.delete_object user_email, path, object_type = :file
      client = get_client(user_email)
      object_id = client.find_object_id path, nil, object_type, false

      if object_id
        client.delete_object object_id
      end
    end
    private_class_method :delete_object

    # Use this method to pre-set up access to a user account for drive information
    # from the specified chain_account. The ONLY time this should be needed is when
    # you intend to add new user accounts to push/pull Drive files to/from - .ie only run
    # this when adding new lines to the google_drive.yml file.
    def self.drive_authorization_script user_email, environment
      raise "The OAuth2 authorization process cannot be run in the production environment.  It must be run prior to being deployed because it require web browser usage." if Rails.env == "production"

      client = initialize_client_info user_email, environment, true
      # TODO Add the user_email to the flow options and then print back the authorization code returned by the OAuth service.
      flow = Google::APIClient::InstalledAppFlow.new(
        :client_id => client.authorization.client_id,
        :client_secret => client.authorization.client_secret,
        :scope => client.authorization.scope,
        :port => 3000
      )
      # This is purely here to pre-set the authorization email address into the authorization form.
      # This is something that's supported by Google's OAuth2 implementation but isn't a standard, so
      # they haven't directly implemented it in their Ruby lib.

      # Kindy hacky way to access a private instance variable
      flow_authorization = flow.instance_eval { @authorization }
      # Another hack to add accessors to allow us to set the user email
      flow_authorization.class_eval { attr_accessor :user_email }
      flow_authorization.user_email = user_email
      def flow_authorization.authorization_uri(options = {})
        uri = super(options)
        query_values = uri.query_values(Hash)
        query_values["login_hint"] = user_email
        uri.query_values = query_values

        uri
      end

      authorization = flow.authorize
      if authorization
        puts "VERY IMPORTANT!!!  Paste the following lines into the 'config/google_drive.yml' file to allow VFI Track full access to #{user_email}'s Drive data (don't overwrite any existing #{user_email} lines) :"
        puts "#{user_email}:"
        puts "  #{environment}:"
        puts "    refresh_token: #{authorization.refresh_token}"
      else
        puts "No authorization code / refresh token was generated.  Did you cancel the process?"
      end

      # The webserver that's started up by the app flow doesn't always shut down correctly.  We can kill it forceably
      # by issuing an interrupt to our current pid.
      Process.kill("INT", Process.pid)

      nil
    end

    def self.get_client user_email = nil
      user_email = default_user_account if user_email.blank?

      @@accounts ||= Hash.new {|hash, key| hash[key] = initialize_client_info(key)}
      @@accounts[user_email]
    end
    private_class_method :get_client

    def self.initialize_client_info user_email, environment = Rails.env, skip_authorization_code = false
      # We could cache authorization credentials to the filesystem, which I believe saves an http request, but we then have to also
      # deal with situations where multiple processes could be accessing the credential files at the same time (.ie delayed job).
      # As an extra http request is not really a big deal on the back end where this should exclusively be running, we'll not worry about
      # that for now.
      drive_data = YAML::load_file 'config/google_drive.yml'
      raise "No Google Drive Application information found for the #{environment} environment." unless drive_data[environment]

      client = Google::APIClient.new application_name: drive_data[environment]['application_name'], application_version: drive_data[environment]['application_version'], auto_refresh_token: true
      
      client.authorization.client_id = drive_data[environment]['client_id']
      client.authorization.client_secret = drive_data[environment]['client_secret']
      client.authorization.scope = "https://www.googleapis.com/auth/drive"
      client.authorization.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"

      # This refresh_token is essentially the unique identifier telling which user data we're attempting to access
      # and is the means the client uses to get a new access token.

      # We don't need this step if we're doing the initial backend authorization
      unless skip_authorization_code
        raise "No Google Drive account information found for user #{user_email} in the #{environment} environment." unless drive_data[user_email] && drive_data[user_email][environment]
        refresh_token = drive_data[user_email][environment]['refresh_token']
        if refresh_token.blank?
          raise "You must provide a refresh_token in the configuration for the #{user_email} account in the #{environment} environment."
        else
          client.authorization.refresh_token = refresh_token
        end
      end
      
      # Here's where we do the actual HTTPS request for an initial access token. The access token times out after X amount seconds
      # at which point you need to request a refresh token.  The client handles this all transparently behind the scenes.
      # Documented here just as an explanation.

      # We'll also see authorization errors thrown here if an account wasn't set up yet or if the VFI Track access was revoked
      client.authorization.fetch_access_token! unless skip_authorization_code
      api = client.discovered_api("drive", "v2")

      DriveClientInfo.new client, api
    end
    private_class_method :initialize_client_info

    class DriveClientInfo
      attr_reader :client, :drive
      delegate :authorization, :authorization=, :to => :client

      def initialize client, drive, known_folders = {}
        @client = client
        @drive = drive
      end

      def root_alias
        "root"
      end

      # Finds the google identifier (and download link for files) of the id specified by the provided path.  
      # If the path does not exist and we're not instructed to create it, then nil is returned for paths
      # that aren't present.
      # Returned hash keys are: :id, :downloadUrl
      #
      # path - a Pathname object pointing to the object to find (all paths passed to this method should be absolute paths .ie start with /)
      # parent_folder_id - represents the starting point for finding the object, can be the string folder id, or the internal standard hash structure of file objects
      # object_type - the type of object to find, one of: :file or :folder
      # create - if true, folders that are not present in the path will be created while searching for the object.  In the case
      # of finding folders, the object being found will also be created if this is set to true.
      def find_object_id path, parent_folder_id = nil, object_type = :file, create = false

        # The Drive API doesn't at all operate like a standard filesystem with file paths (no idea why they couldn't
        # at least emulate this at a query interface level), but we can emulate the path structure
        # so that we can keep the API consistent with our S3 API and make it a little easier to push files to our workflow 
        # directories.

        # Technically, I THINK we could cache the folder id (or the parent folder id for files) value against the 
        # passed in path/parent folder path since the ids are supposed to be totally unique and shouldn't change.
        # This would possibly save us # of path components HTTP requests.  For now, we'll just do the individual calls for each path segment
        # I did attempt to quickly cache these but validating cache hits (.ie making sure that the ids we've cached
        # are actually still in drive) becomes unwieldy to handle easily.  Work for another day.
        object_hash = nil

        parent_hash = {}
        if parent_folder_id.blank? || parent_folder_id.empty?
          # If no parent id is given, we're going to assume root
          parent_hash[:id] = root_alias
        elsif parent_folder_id.is_a? String
          parent_hash[:id] = parent_folder_id
        else
          parent_hash = parent_folder_id
        end

        split_path = path.to_s.split("/")
        split_path.delete_at(0) if split_path[0] == ""

        split_path.each_with_index do |name, x|
          # If we're at the end of our path, then look for the object using the current parent folder id
          if x == (split_path.length - 1)
            object_hash = find_object_in_parent parent_hash[:id], name, object_type, path
            if object_hash.nil? && object_type == :folder && create
              # We'll want to create this folder
              object_hash = create_folder name, parent_hash[:id], false
            end
          else
            # We're still descending the path object, so we'll be dealing with folders entirely at this point
            current_parent = parent_hash
            parent_hash = find_object_in_parent current_parent[:id], name, :folder, path

            # If the folder didn't exist create it if specified to do so, otherwise error out
            if parent_hash.nil?
              if create
                parent_hash = create_folder name, current_parent[:id], false
              else
                raise FileNotFoundError, "The folder named '#{name}' was not found in the path #{path}"
              end
            end
          end
        end

        return object_hash
      end

      # Returns a hash of information about the object being looked up.
      # For folders, just returns the :id, for files it returns the :id and :downloadUrl

      def find_object_in_parent parent_id, file_name, object_type, full_path
        object_hash = nil

        parameters = append_max_results("2", object_type == :file ? make_child_file_params(file_name, parent_id): make_child_folders_params(file_name, parent_id))

        object_identifier = object_type == :file ? "file" : "folder"

        # Technically, there can be more than one file or folder underneath the parent named the same thing
        # but we're not going to bother even attempting to support that.

        # The list returned here just returns the id of the child resources, it doesn't give any more 
        # information than that (ie. name, etc), which is fine for our purpose here.  If you need any
        # more information, then use the files.list api method
        result = execute_single_method! api_method: @drive.files.list, parameters: parameters
        results_found = result.items.length
        if results_found > 1
          raise "Found #{results_found} #{object_identifier.pluralize(results_found)} named '#{file_name}' in the path '#{full_path}'. Only a single #{object_identifier} should be present."
        elsif results_found == 1
          object_hash = {id: result.items[0].id}
          # Warning, I would have though that the schema objects constructed from the JSON responses 
          # would probably handle respond_to? so we could do result.items[0].respond_to?(:downloadUrl)
          # but they don't
          if object_type == :file 
            object_hash[:downloadUrl] = result.items[0].downloadUrl
          end
        end
        
        object_hash
      end

      # Creates a new folder, returning the id of the folder created.
      def create_folder folder_name, parent_id = "root", check_for_existing = true
        folder_id = nil

        if check_for_existing
          parameters = append_max_results("2", make_child_folders_params(folder_name, parent_id))
          result = execute_single_method! api_method: @drive.files.list, parameters: parameters
          folder_id = result.items[0].id if result.items.length > 0
        end

        unless folder_id
          folder = @drive.files.insert.request_schema.new({
              "title" => folder_name,
              "description" => folder_name,
              "mimeType" => folder_mime_type
            })

          folder.parents = [{"id" => parent_id}]

          # We're expecting a "file" resource json object as the response here
          # https://developers.google.com/drive/v2/reference/files#resource
          result = execute_single_method! :api_method => @drive.files.insert, :body_object => folder
          folder_id = result.id
        end
        
        folder_id ? {id: folder_id} : nil
      end

      def upload_file drive_path, file, options = {}
        folder_path, file_name = normalize_path drive_path

        # Find or create the folder we're going to put this file in
        parent_folder_id = find_object_id folder_path, nil, :folder, true

        options = {:overwrite_existing => false}.merge(options)
        mime_type = file_mime_type(file_name)

        # If we want to update an existing file instead of just throwing out a copy of
        # an existing one (since you can have identically named files in the same "folder")
        # we need to use the update api call instead of the insert one.  This also necessitates
        # finding the id of an existing file.
        api_method = nil
        body_object = nil
        parameters = {
          'uploadType' => 'multipart',
          'alt' => 'json'
        }

        if options[:overwrite_existing] == true
          existing_file_id = find_object_in_parent parent_folder_id[:id], file_name, :file, drive_path

          if existing_file_id
            api_method = @drive.files.update
            parameters['fileId'] = existing_file_id[:id]
            body_object = {}
          end
        end

        if api_method.nil?
          api_method = @drive.files.insert
          body_object = @drive.files.insert.request_schema.new({
            'title' => file_name,
            'description' => file_name,
            'mimeType' => mime_type,
            'parents' => [{"id" => parent_folder_id[:id]}]
          })
        end

        media = Google::APIClient::UploadIO.new(file, mime_type)

        # We should probably attempt to trap any transitory network issues and retry the upload.
        # For now, we'll just see how it goes without doing this.  Also, we may wish to 
        # attempt to implement ResumableUploads since those are chunked uploads and allow you to
        # send files in descreet chunks, retry just a single chunk if any network issues occur.

        # For now, a single upload request should be ok
        result = execute_single_method!({
          :api_method => api_method,
          :body_object => body_object,
          :media => media,
          :parameters => parameters
        })

        result.id
      end

      # Downloads the file data specified by the given drive_path to the provided IO object.
      # The IO object is flushed and rewound, ready to the read from.
      def download_file drive_path, io
        object_hash = find_object_id drive_path

        raise FileNotFoundError, "Failed to find Google Drive file #{drive_path}" unless object_hash && object_hash[:downloadUrl]

        # At this point, the Google ruby API (or more specifically, the faraday gem)
        # doesn't support streaming file downloads, so the whole file's data is downloaded 
        # to memory regardless of what we do.  This is supposed to be fixed soon.
        # So, for now, just write the data to the passed in IO instance.
        # Hopefully, in a release or so we can have the google gem download directly to our IO instance.
        result = client.execute! uri: object_hash[:downloadUrl]
        io.write result.body
        io.flush
        io.rewind
        nil
      end

      def delete_object object_id
        id = object_id.is_a?(String) ? object_id : object_id[:id]
        if id
          execute_single_method!(
            :api_method => @drive.files.delete, 
            :parameters => {'fileId' => id}
          )
        end
      end

      private 
        def file_mime_type file_name
          mime_type = nil

          types = MIME::Types.type_for(file_name)
          if types.length > 0
            # Avoid any X types if we can, drive doesn't like them
            mime_type = types.reject {|type| type.content_type.match(/\/x-/) }.first

            if mime_type.blank?
              mime_type = types.first
            end

            mime_type = mime_type.to_s
          else
            mime_type = "application/octet-stream"
          end

          mime_type
        end

        def make_child_folders_params name, parent_id
          params = {}
          append_parent_folder(parent_id, params)
          append_filename(name, params)
          append_folder_mime_type(params)
          append_not_deleted(params)

          params
        end

        def make_child_file_params name, parent_id
          params = {}
          append_parent_folder(parent_id, params)
          append_filename(name, params)
          append_standard_file_download_params(params)
          append_file_mime_type(params)
          append_not_deleted(params)

          params
        end

        def execute_single_method params
          execute params, false
        end

        def execute_single_method! params
          execute params, true
        end

        def execute params, raise_errors
          start = Time.now
          # What we get back here is information about the HTTP Response 
          # and then the actual JSON response data in the result.data object
          result = raise_errors ? @client.execute!(params) : @client.execute(params)

          if result.data?
            # This data should be the actual JSON data returned by the google API call
            # formatted into a drive schema object.
            result.data
          elsif result.error?
            raise
          else
            nil
          end
        end


        # This can be used for any API call that uses page tokens and has a "items[]" in its results
        # The call automatically iterates over the pages and populates the items[] array
        def execute_paginated_method params
          results = nil

          #Previous loop's result (carried between loops so we can generate the next page's request from the previous one's)
          single_result = nil

          # Loops over list while there's more pages of results
          begin
            if single_result != null
              params = single_result.next_page
            end

            single_result = execute_single_method! params
            if results == nil
              results = single_result
            else
              results.items += single_result.items
            end

          end while !single_result.next_page_token.blank?

          results
        end

        def append_not_deleted params
          append_search_param(params, "trashed = false")
          append_search_param(params, "hidden = false")
          params
        end

        def append_folder_mime_type params
          append_search_param(params, "mimeType = '#{folder_mime_type}'")
          params
        end

        def append_file_mime_type params
          append_search_param(params, "mimeType != '#{folder_mime_type}'")
          params
        end

        def append_parent_folder parent_id, params
          append_search_param(params, "'#{escape_search_term(parent_id)}' in parents")
          params
        end

        def folder_mime_type
          "application/vnd.google-apps.folder"
        end

        def append_filename filename, params, operator = "="
          append_search_param(params, "title #{operator} '#{escape_search_term(filename)}'")
          params
        end

        def append_max_results max, params
          params["maxResults"] = max
          params
        end

        def append_standard_file_download_params params
          params["fields"] = "nextPageToken,items(id,downloadUrl)"
        end

        def append_search_param params, search_value
          q = params["q"]
          if q
            q += " and "
          else
            q = ""
          end

          params["q"] = q + search_value
        end

        def escape_search_term term
          # Search terms must have apostrophe escaped w/ '\' e.g., 'Valentine\'s Day'.
          term.gsub("'", "\\'")
        end

        def normalize_path path
          n_path = path.to_s
          n_path = File::SEPARATOR + n_path unless n_path[0] == File::SEPARATOR

          full_path = Pathname.new n_path
          folder_path = full_path.parent
          file_name = full_path.basename.to_s

          [folder_path, file_name]
        end
    end

    class FileNotFoundError < StandardError
    end

  end
end