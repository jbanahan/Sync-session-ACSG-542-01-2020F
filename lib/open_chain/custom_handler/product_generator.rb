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

      attr_reader :row_count, :custom_where

      def initialize(opts={})
        @custom_where = opts[:where]
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

          processed_rows = preprocess_row row, last_result: (rt.size == (i + 1))
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
          end
          
        end
        if self.respond_to? :sync_code
          synced_products.keys.in_groups_of(100,false) do |uids|
            Product.transaction do
              ActiveRecord::Base.connection.execute "DELETE FROM sync_records where trading_partner = \"#{sync_code}\" and syncable_id IN (#{uids.join(",")}); "
              inserts = uids.collect do |y|
                fp = ActiveRecord::Base.sanitize synced_products[y]
                "(#{y},\"Product\",now()#{auto_confirm? ? ',now() + INTERVAL 1 MINUTE' : ''},now(),now(),\"#{sync_code}\",#{has_fingerprint ? fp : 'null'})"
              end
              ActiveRecord::Base.connection.execute "INSERT INTO sync_records (syncable_id,syncable_type,sent_at#{auto_confirm? ? ',confirmed_at' : ''},updated_at,created_at,trading_partner,fingerprint)
                VALUES #{inserts.join(",")}; "
            end
          end
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
          f.unlink
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

      

      # Generate a subselect representing a custom value based on custom definition id
      def cd_s cd_id, opts = {}
        opts = {suppress_alias: false, suppress_ifnull: false, suppress_data: false}.merge opts

        @definitions ||= {}
        if @definitions.empty?
          CustomDefinition.all.each {|cd| @definitions[cd.id] = cd}
        end
        cd = @definitions[cd_id]

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
            return missing_custom_def opts[:suppress_alias], cd_id, cd
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

          select_clause += build_custom_def_query_alias(opts[:suppress_alias], cd_id, cd)

        else
          #so report doesn't bomb if custom field is removed from system
          missing_custom_def opts[:suppress_alias], cd_id, cd
        end
      end
      
      #remove new lines and optionally quotes from string values
      def clean_string_values values, strip_quotes=false
        values.each do |v| 
          next unless v.respond_to?(:gsub!)
          if strip_quotes
            v.gsub!(/[\r\n\"]/,' ')
          else
            v.gsub!(/[\r\n]/,' ')
          end
        end
      end

      private 
        def missing_custom_def suppress_alias, cd_id, cd
          "(SELECT \"\")#{build_custom_def_query_alias(suppress_alias, cd_id, cd)}"
        end

        def build_custom_def_query_alias suppress_alias, cd_id, cd
          if suppress_alias
            ""
          else
            cd ? " as `#{cd.label}`" : " as `Custom #{cd_id}`"
          end
        end
    end
  end
end
