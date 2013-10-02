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
  end
end
