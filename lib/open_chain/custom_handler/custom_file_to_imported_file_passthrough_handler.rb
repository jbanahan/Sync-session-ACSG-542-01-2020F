require 'open_chain/custom_handler/custom_file_csv_excel_parser'

# This module does most of the heavy lifting when you want to create a custom translation for files
# uploaded as CustomFiles that will then feed into the system as ImportedFiles (.ie files uploaded
# through the search interface).
#
# The reason for doing this is simple.
# 1) It allows the user access to the log for uploaded files.
# 2) It uses the same codebase for importing files - which uses the same validations (.ie valid hts numbers, etc)
#
# To use this module you must implement the following methods:
# - translate_file_line(line) - receives an array which is a line from the file being processed.  You can return a regular array
# to represent a 1-1 line mapping or you can return a multi-dimensional array consisting of 1 or more arrays representing multiple lines
# that will go into the actual file processed by the ImportedFile#process call that ultimately happens.
#
# - search_setup_attributes(file, user) - the search setup attributes to use to create/find the search setup to use for the imported file
#
# - search_column_uids - an array of model field uids that define the file import columns.  These define the file layout
# that your translate_file_line method should adhere to.
#
# You process method (which is what you must implement for the CustomFile interface) should call this module's
# process_file method, all the rest will be done for you then.
module OpenChain; module CustomHandler; module CustomFileToImportedFilePassthroughHandler
  extend ActiveSupport::Concern
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  # Processes the custom file passed in, turning it into an ImportedFile and then
  # processing the imported file.
  #
  # If skip_headers option is set to true, the first row read from the incoming CustomFile will be skipped
  #
  # If skip blank lines is true, any lines that have no data will not passed to your implementation of the
  # translate_file_line method.
  def process_file custom_file, user, skip_headers: false, skip_blank_lines: true
    new_filename = [File.basename(custom_file.path, ".*"), ".csv"]
    imported_file = nil
    Tempfile.open(new_filename) do |outfile|
      Attachment.add_original_filename_method outfile, new_filename.join

      foreach(custom_file, skip_headers: skip_headers, skip_blank_lines: skip_blank_lines) do |row|
        lines = translate_file_line row
        # See if lines is a multi-dimensional array or not...if not, the wrap it in an array
        if !lines.first.is_a?(Enumerable)
          lines = [lines]
        end

        lines.each {|line|  outfile << line.to_csv }
      end
      outfile.flush
      outfile.rewind

      imported_file = generate_imported_file outfile, user
    end

    imported_file.process user
  end

  def generate_imported_file file, user
    search_setup = find_or_create_search_setup file, user
    imported_file = search_setup.imported_files.build update_mode: "any", starting_row: 1, starting_column: 1, module_type: search_setup.module_type, user_id: user.id
    imported_file.attached = file
    imported_file.save!

    imported_file
  end

  def find_or_create_search_setup file, user
    attrs = search_setup_attributes(file, user)
    search_setup = SearchSetup.where(attrs).first
    if search_setup
      validate_search_setup(search_setup)
    else
      search_setup = create_search_setup attrs
    end

    search_setup
  end

  def validate_search_setup search_setup
    # All we need to do is verify that the expected search columns are in the right order
    columns = search_setup.search_columns.sort {|a, b| a.rank <=> b.rank }
    search_column_uids.each_with_index do |uid, x|
      if columns[x].nil? || columns[x].model_field_uid.to_s != uid.to_s
        expected_model_field_label = ModelField.find_by_uid(uid).label

        actual_model_field_label = columns[x].nil? ? "blank" : ModelField.find_by_uid(columns[x].model_field_uid.to_s).label

        raise ArgumentError, "Expected to find the field '#{expected_model_field_label}' in column #{x + 1}, but found field '#{actual_model_field_label}' instead."
      end
    end
  end

  def create_search_setup setup_attributes
    setup = SearchSetup.new setup_attributes
    search_column_uids.each_with_index do |uid, x|
      setup.search_columns.build rank: x, model_field_uid: uid.to_s
    end
    setup.save!
    setup
  end

end; end; end