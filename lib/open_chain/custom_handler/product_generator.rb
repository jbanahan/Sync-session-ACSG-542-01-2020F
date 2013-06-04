module OpenChain
  module CustomHandler
    # Generates product output files based on subclass implementing a few helper methods
    #
    # If subclass implements `sync_code` then class will write / update sync records after generating the file
    #
    # Subclass must implement `query` ande return a string representing the sql query to build the grid that will become the output file.  
    # The `query` method should check for a @custom_where variable to override the where clause of the query in case someone needs to run the generator for a specific product set
    # The first column in the query MUST be the products.id and will not be output in the file.
    #
    # Subclass must implmeent `ftp_credentials` if you want to call the `ftp_file` method.  `ftp_credentials` should return a hash like {:server=>'ftp.sample.com',:username=>'uname',:password=>'pwd',:folder=>'/ftp_folder',:remote_file_name=>'remote_name.txt'}
    # :folder & :remote_file_name are optional
    class ProductGenerator

      def initialize(opts={})
        @custom_where = opts[:where]
      end
      
      # do any preprocessing on the row results before passing to the sync_[file_format] methods
      # returns array of rows so you can add more rows into the process
      def preprocess_row row
        [row]
      end

      def sync
        synced_products = []
        rt = Product.connection.execute query
        row = {}
        rt.fields.each_with_index do |f,i|
          row[i-1] = f unless i==0
        end
        yield row if rt.count > 0
        rt.each_with_index do |vals,i|
          row = {}
          vals.each_with_index {|v,i| row[i-1] = v unless i==0}
          synced_products << vals[0]
          processed_rows = preprocess_row row
          processed_rows.each {|r| yield r}
        end
        if self.respond_to? :sync_code
          synced_products.in_groups_of(100,false) do |uids|
            x = uids
            Product.transaction do
              Product.connection.execute "DELETE FROM sync_records where trading_partner = \"#{sync_code}\" and syncable_id IN (#{x.join(",")});"
              Product.connection.execute "INSERT INTO sync_records (syncable_id,syncable_type,sent_at,confirmed_at,updated_at,created_at,trading_partner) 
   (select id, \"Product\",now(),now() + INTERVAL 1 MINUTE,now(),now(),\"#{sync_code}\" from products where products.id in (#{x.join(",")}));"
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

      # ftp the given file to the appropriate location for this product generator
      # will return true if subclass responds to ftp_credentials and file is sent without error
      # will return false if file is nil or doesn't exist
      def ftp_file file, delete_local=true
        return false unless self.respond_to? :ftp_credentials
        return false if file.nil? || !File.exists?(file.path)
        begin
          opts = {}
          c = ftp_credentials
          opts[:folder] = c[:folder] unless c[:folder].blank?
          opts[:remote_file_name] = c[:remote_file_name] unless c[:remote_file_name].blank?
          FtpSender.send_file(c[:server],c[:username],c[:password],file,opts)
        ensure
          file.unlink if delete_local
        end
        true
      end

      # Generate a subselect representing a custom value based on custom definition id
      def cd_s cd_id, suppress_alias = false
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
          end
          
          "(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = #{table_name}.id AND custom_definition_id = #{cd.id})#{build_custom_def_query_alias(suppress_alias, cd_id, cd)}"
        else
          #so report doesn't bomb if custom field is removed from system
          "(SELECT \"\")#{build_custom_def_query_alias(suppress_alias, cd_id, cd)}"
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
