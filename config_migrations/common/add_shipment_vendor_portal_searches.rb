module ConfigMigrations; module Common; class AddShipmentVendorPortalSearches

  def up 
    create_searches
  end

  def down
    SearchTableConfig.where(page_uid: page_uid, name: search_names).destroy_all
    nil
  end

  def search_names
    ["Not Booked", "Booked - Not Confirmed", "Booked - Not Shipped", "Shipped", "All"]
  end

  def page_uid
    "chain-vp-shipment-panel"
  end

  def create_searches
    search_names.each do |name|
      case name
      when "Not Booked"
        create_search "Not Booked", {hiddenCriteria: [{field:'shp_booking_received_date',operator:'null'}]}
      when "Booked - Not Confirmed"
        create_search("Booked - Not Confirmed", 
          {hiddenCriteria: [
            {field:'shp_booking_received_date',operator:'notnull'},
            {field:'shp_booking_confirmed_date',operator:'null'}
          ]}
        )
      when "Booked - Not Shipped"
        create_search("Booked - Not Shipped", 
          {hiddenCriteria: [
            {field:'shp_booking_received_date',operator:'notnull'},
            {field:'shp_booking_confirmed_date',operator:'notnull'},
            {field:'shp_departure_date',operator:'null'}
          ]}
        )
      when "Shipped"
        create_search("Shipped", 
          {hiddenCriteria: [
            {field:'shp_departure_date',operator:'notnull'}
          ]}
        )
      when "All"
        create_search("All", {hiddenCriteria: []})
      else
        raise "Unexpected search name: #{name}"
      end
    end


    create_search("Shipped", 
      {hiddenCriteria: [
        {field:'shp_departure_date',operator:'notnull'}
      ]}
    )

    create_search("All", {hiddenCriteria: []})
    nil
  end

  def create_search name, config
    SearchTableConfig.where(page_uid: page_uid, name: name).first_or_create! config_json: merge_config_with_base(config)
  end

  def merge_config_with_base config
    ActiveSupport::JSON.encode(base_shipment_config.merge config)
  end

  def base_shipment_config
    {
      columns: [
        'shp_ref',
        'shp_booking_received_date',
        'shp_booking_confirmed_date',
        'shp_departure_date'
      ],
      sorts: [
        {field:'shp_booking_received_date'},
        {field:'shp_ref'}
      ]
    }
  end

end; end; end;