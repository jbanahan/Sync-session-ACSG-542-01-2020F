module OpenChain
  class DrawbackExportParser
    def self.parse_csv_file file_path, importer
      count = 0
      f = File.new(file_path)
      f.each_line do |line|
        unless count == 0
          ln = line.encode(Encoding.find("US-ASCII"),:undef=>:replace, :replace=>' ', :fallback=>' ')
          CSV.parse(ln) do |r|
            d = parse_csv_line r, count, importer
            d.save! unless d.nil?
          end
        end
        count += 1
      end
    end

    def self.parse_xlsx_file s3_path, importer
      count = 0
      f = OpenChain::XLClient.new(s3_path)
      f.all_row_values(0) do |line|
        unless count == 0
          ln = line.join(',').encode(Encoding.find("US-ASCII"),:undef=> :replace, replace: ' ', fallback:' ')
          CSV.parse(ln) do |r|
            d = parse_csv_line r, count, importer
            d.save! unless d.nil?
          end
        end
        count += 1
      end
    end

  end
end
