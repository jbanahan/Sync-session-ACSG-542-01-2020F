module OpenChain; module CustomHandler; class EcellerateShipmentActivityParser
  #required to support CustomFile
  def initialize attachable
    @attachable = attachable
  end
  
  def self.can_view? user
    user.edit_shipments? && user.company.master? && MasterSetup.get.custom_feature?("ecellerate")
  end

  #required to support CustomFile
  def can_view? user
    self.class.can_view? user
  end

  def process user
    raise "Processing Failed because you cannot view this file." unless self.can_view? user
    @user = user
    self.parse OpenChain::XLClient.new_from_attachable(@attachable)
  end

  def parse xlclient
    row_number = 0
    shipment_cache = {}
    missing_house_bills = []
    xlclient.all_row_values do |r|
      row_number += 1
      next unless r[0] == 'House Bill'
      hbol = r[1]
      next if missing_house_bills.include? hbol
      importer = get_importer r[5]
      next unless importer
      s = shipment_cache[hbol]
      s = Shipment.includes(:shipment_lines).where(house_bill_of_lading:hbol,importer_id:importer.id).first unless s
      if s
        shipment_cache[hbol] = s
        s.est_departure_date = r[33]
        s.departure_date = r[34]
        s.est_arrival_port_date = r[35]
        s.arrival_port_date = r[36]
        s.cargo_on_hand_date = r[38]
        s.est_delivery_date = r[41]
        s.delivered_date = r[42]
      else
        missing_house_bills << hbol
      end
    end
    shipment_cache.values.each {|s| s.save!}
    if !missing_house_bills.empty?
      msg = <<MSG
The following House Bills are on the shpment activity report but haven't had their XML pushed from ECellerate:

#{missing_house_bills.join("\r\n")}
MSG
      OpenMailer.send_simple_text('ecellerate@vandegriftinc.com','ECellerate Missing HBOLs',msg).deliver!
    end
  end

  private
  def get_importer ior_code
    return nil if ior_code.blank?
    Company.find_by_ecellerate_customer_number ior_code
  end

end; end; end;