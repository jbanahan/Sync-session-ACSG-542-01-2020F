require 'open_chain/google_api_support'

# 
# For all methods in this class that accept a path, to use a team drive simply prefix the path
# with "Team Drives/" followed by the Team Drive name -> "Team Drives/My Drive/folder/file.txt"
# 
module OpenChain; class GoogleDrive
  extend OpenChain::GoogleApiSupport

  # Downloads the Google Drive data specified by the user/path.  The tempfile
  # created will attempt to use the filename from the path as a template for naming the tempfile created.
  # Meaning, at a minimum, the file name name should retain the same file extension that
  # it currently has on the Drive file system.
  #
  # If a block is passed, the tempfile is yielded to the block as the sole argument and cleanup
  # of the tempfile is handled transparently to the caller.  The tempfile will be set to read from the
  # beginning of the file when yielded.
  def self.download_to_tempfile path, google_account_name: nil
    tempfile = nil
    begin
      with_team_drive_id(path, google_account_name: google_account_name) do |client, team_drive_id, relative_path|
        tempfile = Tempfile.new([File.basename(relative_path, ".*"), File.extname(relative_path)])
        tempfile.binmode
        Attachment.add_original_filename_method tempfile, File.basename(relative_path)

        client.download_file relative_path, tempfile, team_drive_id: team_drive_id

        if block_given?
          return yield tempfile
        else
          return tempfile
        end
      end
    rescue Exception
      errored = true
      raise $!
    ensure
      tempfile.close! if tempfile && (errored || block_given?)
    end
  end
  
  # Uploads the provided file to the specified path under the user account specified.
  # 
  # user_email - a drive email account that has already been authorized for access (.ie there's a reference to it in google_drive.yml)
  # If blank/nil, the system default will be used.
  # path - a standard path like 'folder/subfolder/file.txt'.  The path may consist solely of a filename, but it MUST have a name.
  # file - a IO/File object or a string path to the file to upload
  def self.upload_file path, file, overwrite_existing: true, google_account_name: nil
    with_team_drive_id(path, google_account_name: google_account_name) do |client, team_drive_id, relative_path|
      # Returns the new file's id
      Lock.acquire("DRIVE:#{google_account_name.presence || "default"}:#{path}", yield_in_transaction: false) do
        hashify_file(client.upload_file relative_path, file, overwrite_existing: overwrite_existing, query_fields: "#{file_fields}", team_drive_id: team_drive_id)
      end
    end
  end

  # Perminently deletes the file object this path references.
  # 
  # Delete ONLY works if you are the Drive owner of the file.  In general, 
  # if you're removing files using a service account, you'll want to utilize the
  # remove_file_from_folder method.
  def self.delete_file path, google_account_name: nil
    with_team_drive_id(path, google_account_name: google_account_name) do |client, team_drive_id, relative_path|
      client.delete_file relative_path, team_drive_id: team_drive_id
    end
    
    nil
  end

  # Perminently deletes the folder object this path references.
  #
  # Delete ONLY works if you are the Drive owner of the file.  In general, 
  # if you're removing files using a service account, you'll want to utilize the
  # remove_file_from_folder method.
  #
  # BEWARE - This also deletes EVERYTHING below the folder too.
  def self.delete_folder path, google_account_name: nil
    with_team_drive_id(path, google_account_name: google_account_name) do |client, team_drive_id, relative_path|
      client.delete_folder relative_path, team_drive_id: team_drive_id
    end
    nil
  end

  # Returns a hash about the file found at the given path
  # {id:, name: created_time: modified_time: size:}
  # returns nil if no file is found at the given path
  def self.find_file path, google_account_name: nil
    with_team_drive_id(path, google_account_name: google_account_name) do |client, team_drive_id, relative_path|
      file = client.find_file relative_path, file_query_fields: "files(#{file_fields})", team_drive_id: team_drive_id
      hashify_file(file)
    end
  end

  # Returns a hash about the folder found at the given path
  # {id:, name: created_time: modified_time: size:}
  # returns nil if no file is found at the given path
  def self.find_folder path, google_account_name: nil
    with_team_drive_id(path, google_account_name: google_account_name) do |client, team_drive_id, relative_path|
      file = client.find_folder relative_path, file_query_fields: "files(#{folder_fields})", error_if_missing: false, team_drive_id: team_drive_id
      hashify_folder(file)
    end
  end

  # Deletes a drive object by id (can be a file/folder, anything)
  #
  # Note: if this is a folder, anything stored below the folder will be deleted too
  def self.delete_by_id id, google_account_name: nil
    get_client(google_account_name: google_account_name).delete_by_id id
  end

  def self.find_folder_by_id id, google_account_name: nil
    folder = get_client(google_account_name: google_account_name).find_by_id id, file_query_fields: folder_fields
    hashify_folder(folder)
  end

  def self.find_file_by_id id, google_account_name: nil
    file = get_client(google_account_name: google_account_name).find_by_id id, file_query_fields: file_fields
    hashify_file(file)
  end
  

  def self.get_client google_account_name: nil, path_cache: nil
    service = drive_service(google_account_name: google_account_name)
    cache = path_cache.presence || get_path_cache
    DriveClient.new(service, get_path_cache)
  end
  private_class_method :get_client

  def self.get_path_cache
    # At some point, we really should devise a way to cache all the path lookups, so we don't have to
    # keep walking the folder heirarchy for every upload...for now though, this works well enough.
    {}
  end
  private_class_method :get_path_cache

  def self.hashify_file file
    return nil if file.nil?

    {id: file.id, name: file.name, created_time: file.created_time, modified_time: file.modified_time, size: file.size, parents: Array.wrap(file.parents), team_drive_id: file.team_drive_id}
  end
  private_class_method :hashify_file

  def self.file_fields
    "id, name, createdTime, modifiedTime, size, parents, teamDriveId"
  end
  private_class_method :file_fields

  def self.hashify_folder file
    return nil if file.nil?

    {id: file.id, name: file.name, created_time: file.created_time, modified_time: file.modified_time, parents: Array.wrap(file.parents), team_drive_id: file.team_drive_id}
  end
  private_class_method :hashify_folder

  def self.folder_fields
    "id, name, createdTime, modifiedTime, parents, teamDriveId"
  end
  private_class_method :folder_fields

  def self.with_team_drive_id full_path, google_account_name: nil, path_cache: nil
    team_drive_name, team_drive_relative_path = split_team_drive_path(full_path)
    drive = get_client(google_account_name: google_account_name, path_cache: nil)
    team_drive_id = nil
    if !team_drive_name.nil?
      team_drive = drive.find_team_drive_id team_drive_name
      team_drive_id = team_drive.id unless team_drive.nil?
    end
    private_class_method :with_team_drive_id

    return yield drive, team_drive_id, team_drive_relative_path
  end

  def self.split_team_drive_path full_path
    path = Pathname.new(full_path).each_filename.to_a

    if path[0].to_s == "Team Drives"
      [path[1], path[2..-1].join("/")]
    else
      [nil, path.join("/")]
    end
  end
  private_class_method :split_team_drive_path

  # This class handles all the nitty gritty of interfacing w/ the google API
  class DriveClient

    def initialize service, path_cache
      @drive = service
      @path_cache = path_cache
    end

    def download_file path, io, team_drive_id: nil
      file = find_file(path, error_if_missing: true, team_drive_id: team_drive_id)
      get_drive.get_file(file.id, download_dest: io, supports_team_drives: true)
      io.rewind
      nil
    end

    def find_team_drive_id team_drive_name
      response = get_drive.list_teamdrives fields: "teamDrives(id, name)"
      response.team_drives.find {|d| d.name == team_drive_name }
    end

    def upload_file path, io, overwrite_existing: true, query_fields: "id, name", team_drive_id: nil
      parent_path, file_name = split_path(path)

      parent_folder = find_folder(parent_path, create_missing_paths: true, team_drive_id: team_drive_id)

      # If we want to update an existing file instead of just throwing out a copy of
      # an existing one (since you can have identically named files in the same "folder")
      # we need to use the update api call instead of the insert one.  This also necessitates
      # finding the id of an existing file.
      file_id = nil
      if overwrite_existing
        existing_file = find_file_in_folder(parent_folder.id, file_name, team_drive_id: team_drive_id)
        file_id = existing_file.id if existing_file
      end
      
      if file_id.nil?
        drive_file = get_drive.create_file({name: file_name, parents: [parent_folder.id]}, fields: query_fields, upload_source: io, supports_team_drives: true)
      else
        drive_file = get_drive.update_file(file_id, {}, fields: query_fields, upload_source: io, supports_team_drives: true)
      end

      drive_file
    end

    def delete_file path, team_drive_id: nil
      file = find_file(path, team_drive_id: team_drive_id)
      delete_by_id(file.id) if file
      nil
    end

    def delete_folder path, team_drive_id: nil
      folder = find_folder(path, error_if_missing: false, team_drive_id: team_drive_id)
      delete_by_id(folder.id) if folder
      nil
    end

    def delete_by_id id
      get_drive.delete_file(id, supports_team_drives: true)
    rescue Google::Apis::ClientError => e
      # the api raises an error on a 404 for delete requests, just return nil in this case...it's delete
      # we don't care if the command didn't execute, functionally we got what we want..a file that's not there
      return nil if e.status_code == 404
      raise e
    end

    def root_alias 
      "root"
    end

    def get_drive
      @drive
    end

    def cache_put path, folder_id
      if @path_cache[path].nil?
        @path_cache[path] = folder_id
        @cache_dity = true
      end
      nil
    end

    def cached_path path
      @path_cache[path]
    end

    def use_cached_folder_id path
      folder_id = cached_path(path)
      if folder_id.nil?
        folder_id = yield
      end

      cache_put(path, folder_id)
      folder_id
    end

    def find_file path, file_query_fields: "files(id, name)", error_if_missing: false, team_drive_id: nil
      path_components = Pathname.new(path).each_filename.to_a
      parent_path, file_name = split_path(path)

      parent = find_folder(parent_path, error_if_missing: error_if_missing, team_drive_id: team_drive_id)
      return nil if parent.nil?

      find_file_in_folder(parent.id, file_name, query_fields: file_query_fields, team_drive_id: team_drive_id)
    end

    def find_file_in_folder folder_id, file_name, query_fields: "files(id, name)", team_drive_id: nil
      query = "#{file_mime_type_query} and #{trashed_query} and #{parents_query folder_id} and #{name_query file_name}"

      parameters = {fields: query_fields, q: query, supports_team_drives: true}
      add_team_drive_list_parameters(parameters, team_drive_id) unless team_drive_id.nil?
      response = get_drive.list_files parameters

      if response.files.length > 1
        raise "Multiple files named #{file_name} found in folder id #{folder_id}."
      else
        response.files.first
      end
    end

    def find_folder path, file_query_fields: "files(id, name)", create_missing_paths: false, error_if_missing: true, team_drive_id: nil
      if path.blank?
        return team_drive_id.nil? ? root_alias : team_drive_id
      end

      path_so_far = [team_drive_id]
      cache_key = team_drive_id.nil? ? path : "#{team_drive_id}:#{path}"

      use_cached_folder_id(cache_key) do 
        path_components = Pathname.new(path).each_filename.to_a

        parent_id = nil
        folder = nil
        path_components.each_with_index do |path_segment, x|
          path_so_far << path_segment

          folder = find_folder_inside_folder(parent_id, path_segment, file_query_fields: file_query_fields, team_drive_id: team_drive_id)

          if folder.nil?
            if create_missing_paths
              folder = create_folder(parent_id, path_segment, team_drive_id: team_drive_id)
            elsif error_if_missing
              raise "Failed to find path '#{path_so_far.join("/")}'"  
            end
          end

          if !folder.nil?
            folder = folder
            parent_id = folder.id
          end
        end

        folder
      end
    end

    def find_by_id folder_id, file_query_fields: "files(id, name)"
      get_drive.get_file folder_id, fields: file_query_fields, supports_team_drives: true
    rescue Google::Apis::ClientError => e
      # Annoyingly, the api raises an error on a 404 for get requests, instead of just returning nil.
      return nil if e.status_code == 404
      raise e
    end

    def split_path path
      path_components = Pathname.new(path).each_filename.to_a
      parent_path, file_name = nil
      raise "No filename given." if path_components.length == 0
      if path_components.length < 2
        parent_path = nil
        file_name = path_components[0]
      else
        parent_path = path_components[0..-2].join "/"
        file_name = path_components[-1]
      end

      [parent_path, file_name]
    end

    def find_folder_inside_folder source_folder_id, folder_name, file_query_fields: "files(id, name)", team_drive_id: nil
      if source_folder_id.blank?
        source_folder_id = team_drive_id.presence || root_alias
      end

      query = "#{folder_mime_type_query} and #{trashed_query} and #{parents_query source_folder_id} and #{name_query folder_name}"

      parameters = {fields: file_query_fields, q: query, supports_team_drives: true}
      add_team_drive_list_parameters(parameters, team_drive_id) unless team_drive_id.nil?

      response = get_drive.list_files parameters

      if response.files.length > 1
        raise "Multiple folders named #{folder_name} found in folder id #{source_folder_id}."
      else
        response.files.first
      end
    end

    def create_folder source_folder_id, folder_name, fields: "id, name", team_drive_id: nil
      if source_folder_id.nil?
        source_folder_id = team_drive_id.nil? ? root_alias : source_folder_id
      end

      get_drive.create_file({name: folder_name, mime_type: folder_mime_type, parents: [source_folder_id]}, fields: fields, supports_team_drives: true)
    end

    def folder_mime_type
      "application/vnd.google-apps.folder"
    end

    def folder_mime_type_query
      "mimeType = '#{folder_mime_type}'"
    end

    def file_mime_type_query
      "mimeType != '#{folder_mime_type}'"
    end

    def trashed_query trashed = false
      "trashed = #{trashed}"
    end

    def parents_query parent_id
      "'#{parent_id}' in parents"
    end

    def name_query name, operator: "="
      "name #{operator} '#{escape_query_term name}'"
    end

    def escape_query_term term
      # Search terms must have apostrophe escaped w/ '\' e.g., 'Valentine\'s Day'.
      term.gsub("'", "\\'")
    end

    def add_team_drive_list_parameters p, team_drive_id
      p[:include_team_drive_items] = true
      p[:corpora] = "teamDrive"
      p[:team_drive_id] = team_drive_id
    end
  end

end; end;
