require 'open_chain/ftp_file_support'

module OpenChain
  module CustomHandler
    # Generates product output files based on subclass implementing a few helper methods
    #
    # If subclass implements `sync_code` then class will write / update sync records after generating the file
    #
    # If subcless implements `trim_fingerprint` then class will pass in the raw SQL result array and expect back an array where the first position is the record's fingerprint and the second is the row array with the fingerprint removed
    #
    # If subclass implements `auto_confirm?` and returns false, the sync records will not automatically be marked as confirmed
    #
    # Subclass must implement `query` and return a string representing the sql query to build the grid that will become the output file.  
    # The `query` method should check for a @custom_where variable to override the where clause of the query in case someone needs to run the generator for a specific product set
    # The first column in the query MUST be the products.id and will not be output in the file.
    #
    # Subclass must implmeent `ftp_credentials` if you want to call the `ftp_file` method.  `ftp_credentials` should return a hash like {:server=>'ftp.sample.com',:username=>'uname',:password=>'pwd',:folder=>'/ftp_folder',:remote_file_name=>'remote_name.txt'}
    # :folder & :remote_file_name are optional
    class ProductGenerator
      include OpenChain::FtpFileSupport

      attr_reader :row_count, :custom_where, :synced_product_ids

      def initialize(opts={})
        @custom_where = opts[:where]
        if opts[:custom_definitions]
          @defintions = opts[:custom_definitions]
        end
      end
      
      # do any preprocessing on the row results before passing to the sync_[file_format] methods
      # returns array of rows so you can add more rows into the process
      #
      # If nil or a blank array is returned then this row of sync data is skipped and will not be included
      # in the output, nor will the product be marked as synced.
      def preprocess_row row, opts = {}
        [row]
      end

      # do any preprocessing on the row results before passing to the sync_[file_format] methods
      # returns hash value
      #
      # If nil or a blank hash is returned then this row of header data is skipped and will not be included
      # in the output
      def preprocess_header_row row, opts = {}
        [row]
      end

      def auto_confirm?
        true
      end

      def sync
        @row_count = 0
        reset_synced_product_ids

        has_fingerprint = self.respond_to? :trim_fingerprint
        synced_products = {}
        rt = Product.connection.execute query
        header_row = {}
        rt.fields.each_with_index do |f,i|
          header_row[i-1] = f unless i==0
        end

        header_row = preprocess_header_row header_row
        rt.each_with_index do |vals,i|
          fingerprint = nil
          if has_fingerprint
            fingerprint, clean_vals = trim_fingerprint(vals) 
          else
            clean_vals = vals
          end
          row = {}
          clean_vals.each_with_index {|v,i| row[i-1] = v unless i==0}

          processed_rows = nil
          preprocessed = false
          # What we're doing here is allowing preprocess_row to throw a :mark_synced symbol to denote
          # that there's no output from preprocess_row, but that it DOES want the row to be marked as synced.
          # This is handy in cases where output is buffered inside preprocess_row, since if it doesn't return
          # a value, the product won't have its ID recorded in the synced_products hash
          catch(:mark_synced) do 
            processed_rows = preprocess_row row, last_result: (rt.size == (i + 1)), product_id: vals[0]
            preprocessed = true
          end
          
          # Allow for preprocess_row to "reject" the row and not process it in this sync pass.
          # Allows for more complicated code based handling of sync data that might not be able to be
          # done via the query.
          if processed_rows && processed_rows.length > 0
            # Don't send a header row until we actually have confirmed we have something to send out
            unless header_row.blank?
              header_row.each do |r|
                yield r
                @row_count += 1
              end
              header_row = nil
            end
            
            synced_products[clean_vals[0]] = fingerprint
            processed_rows.each do |r| 
              yield r
              @row_count += 1
            end
          elsif !preprocessed
            synced_products[clean_vals[0]] = fingerprint
          end
          
        end
        write_sync_records synced_products if self.respond_to? :sync_code
      end

      def write_sync_records synced_products
        has_fingerprint = self.respond_to? :trim_fingerprint

        now = Time.zone.now
        confirmed_at = auto_confirm? ? (now + 1.minute) : nil
        code = sync_code

        synced_products.keys.in_groups_of(100,false) do |product_ids|
          Product.transaction do
            SyncRecord.where(trading_partner: sync_code, syncable_id: product_ids).delete_all
            records = []
            
            product_ids.each do |id|
              records << SyncRecord.new(syncable_type: "Product", syncable_id: id, trading_partner: code, sent_at: now, confirmed_at: confirmed_at, fingerprint: (has_fingerprint ? synced_products[id] : nil))
            end

            SyncRecord.import! records
            add_synced_product_ids product_ids
          end
        end
      end

      def reset_synced_product_ids
        @synced_product_ids = []
      end

      def add_synced_product_ids ids
        @synced_product_ids ||= []
        @synced_product_ids.push *ids
      end

      def set_ftp_session_for_synced_products ftp_session
        return nil unless self.respond_to? :sync_code

        trading_partner = sync_code
        Array.wrap(@synced_product_ids).in_groups_of(1000, false) do |ids|
          Product.transaction do
            SyncRecord.where(syncable_type: "Product", syncable_id: ids, trading_partner: trading_partner).update_all(ftp_session_id: ftp_session.id)
          end
        end
      end

      def ftp_file file, option_overrides = {}
        super(file, option_overrides) do |session|
          # It's technically possible that we get back a session that hasn't been saved, in which case, there's
          # no id value to set for the products.  So just skip it.
          set_ftp_session_for_synced_products(session) if session.persisted?
        end
      end

      #output a csv file or return nil if no rows written
      def sync_csv include_headers=true, csv_opts={}
        f = Tempfile.new(['ProductSync','.csv'])
        cursor = 0
        sync do |rv|
          if include_headers || cursor > 0
            max_col = rv.keys.sort.last
            row = []
            (0..max_col).each do |i|
              v = rv[i]
              v = "" if v.blank?
              row << v.to_s
            end
            row = before_csv_write cursor, row
            f << row.to_csv(csv_opts)
          end
          cursor += 1
        end
        f.flush
        if cursor > 0
          return f
        else
          f.close!
          return nil
        end
      end

      #stub for callback to intercept array of values to be written as CSV and return changed/corrected values
      def before_csv_write row_num_zero_based, values_array
        values_array 
      end
      
      #output a fixed position file based on the layout provided by the subclass in the `fixed_position_map` method
      #
      # `fixed_position_map` should return an array of hashes that include length and an optional to_s lambda like: 
      # [{:len=>5},{:len=>8,:to_s=>lambda {|o| o.strftime("%Y%m%d")}]
      #
      # The `fixed_position_map` array should start with the second element from the query response since the first should
      # always be the products.id and is ignored
      # 
      # The default to_s formatter will left pad strings and right pad anything that responds true to o.is_a?(Numeric)
      # it will truncate strings that are too long.  You should always override date formatting.
      def sync_fixed_position
        f = Tempfile.new(['ProductSync','.txt'])
        map = fixed_position_map #subclass must implement this
        cursor = 0
        sync do |rv|
          cursor += 1
          next if cursor == 1
          row = ""
          map.each_with_index do |settings,i|
            v = rv[i] 
            to_s = settings[:to_s] ? settings[:to_s] : lambda {|o| o.to_s}
            val = to_s.call(v)
            len = settings[:len]
            val = val[0,len] if val.length > len
            val = v.is_a?(Numeric) ? val.rjust(len) : val.ljust(len)
            row << val
          end
          f << "#{row}\n"
        end
        f.flush
        if cursor > 1
          return f
        else 
          f.unlink
          return nil
        end
      end
      #output an excel file with headers
      def sync_xls
        wb = Spreadsheet::Workbook.new
        sht = wb.create_worksheet :name=>'Results'
        cursor = 0
        sync do |rv|
          row = sht.row(cursor)
          rv.each {|k,v| row[k] = v}
          cursor += 1
        end
        if cursor > 0
          t = Tempfile.new(['ProductSync','.xls'])
          wb.write t
          return t
        else
          return nil
        end
      end

      def sync_xml
        # We're going to force the implementing class to require the specific xml declarations (or they can include xml_builder)
        # rather than having them declared here and xml required for all that may not need it.
        f = Tempfile.new(['ProductSync-', ".xml"])
        cursor = 0
        column_names = nil
        error = false
        xml, root = nil
        begin
          sync do |rv|
            row = []
            (0..rv.keys.sort.last).each do |i|
              row << rv[i]
            end
          
            # Even if we're not using the default XML output, there's no need to pass the headers as the first row to that method.
            if column_names.nil? && cursor == 0
              column_names = row
            else
              if xml.nil?
                xml, root = xml_document_and_root_element
              end

              if self.respond_to?(:write_row_to_xml)
                write_row_to_xml(root, cursor, row)
              else
                default_write_xml_elements(root, cursor, column_names, row)
              end
              cursor += 1
            end
          end
        rescue => e
          error = true
          raise e
        ensure
          if error || cursor == 0
            f.close! if f && !f.closed?
            # If we return nil when an error is raised, it actually stops the error from propigating...which we don't want.
            return nil unless error
          else
            formatter = xml_formatter
            formatter.write(xml, f)
            f.flush
            f.rewind
            return f
          end
        end
      end

      def xml_document_and_root_element
        xml_declaration = '<?xml version="1.0" encoding="UTF-8"?>'
        doc = REXML::Document.new("#{xml_declaration}<#{default_root_element_name}/>")
        [doc, doc.root]
      end

      def default_root_element_name
        "Products"
      end

      def default_product_xml_element_name
        "Product"
      end

      def xml_formatter
        REXML::Formatters::Default.new
      end

      def default_write_xml_elements parent, cursor, column_names, values
        # By default, we're just going to use the column names from the query as element names..
        child = parent.add_element(default_product_xml_element_name)

        if self.respond_to?(:before_xml_write)
          values = before_xml_write(cursor, values)
        end

        column_names.each_with_index do |name, index|
          value = values[index]
          unless value.nil?
            el = child.add_element(name)
            el.text = value
          end
        end
      end

      # Generate a subselect representing a custom value based on custom definition id
      def cd_s cd_id, opts = {}
        opts = {suppress_alias: false, suppress_ifnull: false, suppress_data: false}.merge opts

        cd = nil
        if cd_id.is_a?(CustomDefinition)
          cd = cd_id
          cd_id = cd.id
        else
          @definitions ||= {}
          if @definitions.empty?
            CustomDefinition.all.each {|cd| @definitions[cd.id] = cd}
          end
          cd = @definitions[cd_id]
        end
        

        if cd
          table_name = ''
          case cd.module_type
          when 'Product'
            table_name = 'products'
          when 'Classification'
            table_name = 'classifications'
          when 'TariffRecord'
            table_name = 'tariff_records'
          else
            # This shouldn't really happen in prod, but it can in dev for any ids that are hardcoded and the hardcoded id links to a field 
            # for a different module
            return missing_custom_def opts[:suppress_alias], cd_id, cd, opts[:query_alias]
          end

          select_clause = nil
          
          if opts[:suppress_data]
            select_clause = "NULL"
          elsif opts[:suppress_ifnull]
            select_clause = "(SELECT #{cd.data_column} FROM custom_values WHERE customizable_id = #{table_name}.id AND custom_definition_id = #{cd.id})"
          else
            select_clause = "(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = #{table_name}.id AND custom_definition_id = #{cd.id})"
          end

          if opts[:boolean_y_n]
            boolean_y_value = opts[:boolean_y_query_value].blank? ? "1" : opts[:boolean_y_query_value]
            select_clause = "(CASE #{select_clause} WHEN #{boolean_y_value} THEN 'Y' ELSE 'N' END)"
          end

          select_clause += build_custom_def_query_alias(opts[:suppress_alias], cd_id, cd, opts[:query_alias])

        else
          #so report doesn't bomb if custom field is removed from system
          missing_custom_def opts[:suppress_alias], cd_id, cd
        end
      end
      
      #remove new lines and optionally quotes from string values
      def clean_string_values values, strip_quotes=false, strip_tabs=false
        regex = ["\r", "\n"]
        regex << '"' if strip_quotes
        regex << "\t" if strip_tabs

        regex = "[" + regex.join("") + "]"
        values.each do |v| 
          next unless v.respond_to?(:gsub!)
          v.gsub!(/#{regex}/,' ')
        end
      end

      private 
        def missing_custom_def suppress_alias, cd_id, cd, alternate_alias = nil
          "(SELECT \"\")#{build_custom_def_query_alias(suppress_alias, cd_id, cd, alternate_alias)}"
        end

        def build_custom_def_query_alias suppress_alias, cd_id, cd, alternate_alias = nil
          q_alias = nil
          if suppress_alias
            q_alias = ""
          else
            q_alias = alternate_alias.nil? ? (cd ? " as `#{cd.label}`" : " as `Custom #{cd_id}`") : " as `#{alternate_alias}`"    
          end
          q_alias
        end
    end
  end
end
