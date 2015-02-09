module OpenChain; module CustomHandler; module Lenox; class LenoxShipmentStatusParser
  attr_accessor :user
  #required to support CustomFile
  def initialize attachable
    @attachable = attachable
  end
  
  def self.can_view? user
    user.view_shipments? && (user.company.master? || user.company.system_code == 'LENOX') && MasterSetup.get.custom_feature?("Lenox OOCL")
  end

  #required to support CustomFile
  def can_view? user
    self.class.can_view? user
  end

  #required to support CustomFile
  def process user
    @user = user
    begin
      raise "Processing Failed because you cannot view this file." unless self.class.can_view? user
      self.parse OpenChain::XLClient.new_from_attachable(@attachable)
      user.messages.create!(subject:'Lenox Shipment Status Processing Complete',body:"Shipment status file complete.")
    rescue
      user.messages.create!(subject:'Lenox Shipment Status Processing Complete WITH ERRORS',body:"Shipment status file complete with the following error: #{$!.message}") if user.persisted?
    end
  end

  def parse xlclient
    Shipment.transaction do
      shp = []
      last_bol = nil
      xlclient.all_row_values do |xlrow|
        container = xlrow[11].to_s
        next if container.blank? || !container.match(/^[A-Z]{4}/)
        bol = xlrow[9]
        if !shp.empty? && bol!=last_bol
          process_shipment shp
          shp = []
        end
        last_bol = bol
        shp << xlrow
      end
      process_shipment(shp) unless shp.empty?
    end
  end

  def process_shipment rows
    @lenox ||= Company.find_by_system_code 'LENOX'
    r = rows.first
    shp_ref = "LENOX-#{r[9]}"
    shp = Shipment.where(importer_id:@lenox.id,reference:shp_ref).first
    if shp.nil?
      shp = Shipment.new(importer_id:@lenox.id,reference:shp_ref) unless shp
      shp.house_bill_of_lading = r[9]
      shp.lading_port = Port.find_by_name r[6].strip
      raise "Invalid port name #{r[6].strip} for lading port." unless shp.lading_port
      shp.unlading_port = Port.find_by_name(clean_us_port_name(r[8].strip))
      raise "Invalid port name #{r[8].strip} for unlading port." unless shp.unlading_port
      shp.est_departure_date = r[7]
      shp.vessel = r[10]
      rows.each_with_index {|row, i| process_line shp, row, i+i}
      raise "You do not have permission to edit this shipment." unless shp.can_edit?(@user)
      shp.save!
    end
  end

  private
  def process_line shp, r, line_number
    con = shp.containers.find {|c| c.container_number == r[11]}
    con = shp.containers.build(container_number:r[11]) unless con
    con.container_size = r[12]
    con.seal_number = r[17]
    r[4] = r[4].to_s.gsub(/\.0/,'')
    prod = Product.find_by_unique_identifier("LENOX-#{r[4]}")
    raise "Product #{r[4]} for shipment #{shp.house_bill_of_lading} was not found in product database." unless prod
    order = Order.find_by_order_number "LENOX-#{r[3]}"
    raise "Order #{r[3]} for shipment #{shp.house_bill_of_lading} was not found in product database." unless order
    sl = shp.shipment_lines.build(line_number:line_number,product_id:prod.id,quantity:r[5],gross_kgs:r[14],carton_qty:r[15],cbms:r[16])
    ol = find_order_line(order,sl)
    raise "No order line matches product #{r[4]}, order #{r[3]}." unless ol
    sl.linked_order_line_id = ol.id
    sl.container = con
  end

  def find_order_line order, shipment_line
    ord_lns = order.order_lines.where(product_id:shipment_line.product_id).to_a
    ord_lns.sort {|a,b| 
      a_diff = (a.unshipped_qty - shipment_line.quantity)
      b_diff = (b.unshipped_qty - shipment_line.quantity)
      a_diff.abs - b_diff.abs
    }.first
  end

  STATES ||= {
    "Alabama" =>"AL",
    "Alaska" =>"AK",
    "Arizona" =>"AZ",
    "Arkansas" =>"AR",
    "California" =>"CA",
    "Colorado" =>"CO",
    "Connecticut" =>"CT",
    "Delaware" =>"DE",
    "Florida" =>"FL",
    "Georgia" =>"GA",
    "Hawaii" =>"HI",
    "Idaho" =>"ID",
    "Illinois" =>"IL",
    "Indiana" =>"IN",
    "Iowa" =>"IA",
    "Kansas" =>"KS",
    "Kentucky" =>"KY",
    "Louisiana" =>"LA",
    "Maine" =>"ME",
    "Maryland" =>"MD",
    "Massachusetts" =>"MA",
    "Michigan" =>"MI",
    "Minnesota" =>"MN",
    "Mississippi" =>"MS",
    "Missouri" =>"MO",
    "Montana" =>"MT",
    "Nebraska" =>"NE",
    "Nevada" =>"NV",
    "New Hampshire" =>"NH",
    "New Jersey" =>"NJ",
    "New Mexico" =>"NM",
    "New York" =>"NY",
    "North Carolina" =>"NC",
    "North Dakota" =>"ND",
    "Ohio" =>"OH",
    "Oklahoma" =>"OK",
    "Oregon" =>"OR",
    "Pennsylvania" =>"PA",
    "Rhode Island" =>"RI",
    "South Carolina" =>"SC",
    "South Dakota" =>"SD",
    "Tennessee" =>"TN",
    "Texas" =>"TX",
    "Utah" =>"UT",
    "Vermont" =>"VT",
    "Virginia" =>"VA",
    "Washington" =>"WA",
    "West Virginia" =>"WV",
    "Wisconsin" =>"WI",
    "Wyoming" =>"WY"
  }
  def clean_us_port_name raw
    city, state = raw.split(', ')
    state_code = STATES[state]
    "#{city}, #{state_code.blank? ? state : state_code}"
  end
end; end; end; end