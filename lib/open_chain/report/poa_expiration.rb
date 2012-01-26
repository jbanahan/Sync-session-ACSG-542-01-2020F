module OpenChain
  module Report
    class POAExpiration
      # Run the report
      # settings = { 'poa_expiration_date' => Tue, 31 Jan 2012 }
      # somehow date string is converted to date between receiving
      # params and invoking this method
      def self.run_report(run_by, settings)
        raise 'Expiration date required.' unless settings['poa_expiration_date'] || settings['poa_expiration_date'].to_s.empty?
        begin
          date_str = settings["poa_expiration_date"].to_s
          Date.parse(date_str)
          POAExpiration.run(date_str)
        rescue ArgumentError => ae
          raise "Invalid expiration date"
        end
      end

      private
      def self.run(poa_expiration_date)
        wb = Spreadsheet::Workbook.new
        exp_sheet = wb.create_worksheet :name => "POA Expirations"

        heading = exp_sheet.row 0
        ["Company", "Start Date", "Expiration Date"].each do |head_lbl|
          heading.push head_lbl
        end

        expire_later = PowerOfAttorney.where(["expiration_date > ?", poa_expiration_date]).select(:company_id).map(&:company_id)
        poas = PowerOfAttorney.includes(:company).where(["expiration_date <= ?", poa_expiration_date]).order("companies.name ASC, expiration_date DESC").select do |poa|
          poa unless expire_later.include?(poa.company_id)
        end.uniq_by {|poa| poa.company_id}
        
        poas.each_with_index do |poa, idx|
          row = exp_sheet.row(idx + 1)
          row.push poa.company.name
          row.push poa.start_date
          row.push poa.expiration_date
        end

        report_file = Tempfile.new(['poa_expiration', '.xls'])
        wb.write report_file.path
        report_file
      end
    end
  end
end
