class ManufacturerId < ActiveRecord::Base

  def self.load_mid_records mid_rows
    Array.wrap(mid_rows).each do |row|
      next if row.nil?

      mid = ManufacturerId.where(mid: row[0].try(:strip)).first_or_initialize

      mid.name = row[1].try(:strip)
      mid.address_1 = row[2].try(:strip)
      mid.address_2 = row[3].try(:strip)
      mid.city = row[4].try(:strip)
      mid.postal_code = row[5].try(:strip)
      mid.country = row[6].try(:strip)
      mid.active = row[7].to_s.strip != "N"

      mid.save! 
    end
  end
end