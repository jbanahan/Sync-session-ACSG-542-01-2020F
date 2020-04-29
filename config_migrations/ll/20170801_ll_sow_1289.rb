require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module ConfigMigrations; module LL; class LlSow1289
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def up
    # configure_vendor_permissions
    create_searches
    create_allport
    create_booking_unlocked_date
    nil
  end

  def down
    SearchTableConfig.where(page_uid: page_uid, name: search_names).destroy_all
    nil
  end

  def configure_vendor_permissions
    if MasterSetup.get.custom_feature? "Production"
      intl_vendor_codes = ['0000100199', '0000100156', '0000100243', '0000100130', '0000100131', '0000100268', '0000206816', '0000100286',
        '0000100232', '0000100151', '0000300035', '0000300015', '0000100137', '0000300175', '0000100261', '0000100168', '0000100252',
        '0000100143', '0000100121', '0000300165', '0000100170', '0000100202', '0000100222', '0000300007', '0000100128', '0000300206',
        '0000100336', '0000300240', '0000100242', '0000100037', '0000100278', '0000100296']
      intl_vendors = Company.where(vendor: true, system_code: intl_vendor_codes)
    else
      intl_vendors = Company.where(vendor: true)
    end

    # Set all configured users belonging to the specified companies to have all the necessary booking permissions
    user_ids = User.where(company_id: intl_vendors).pluck :id
    update_user_permissions(user_ids) if user_ids.length > 0
    nil
  end

  def update_user_permissions user_ids
    User.where(id: user_ids).update_all(
      shipment_view:true,
      shipment_edit:true,
      shipment_comment:true,
      shipment_attach:true,
      order_view:true,
      order_edit:true,
      order_comment:true,
      order_attach:true,
      product_view:true
    )

    User.where(id: user_ids).each do |user|
      subscriptions = user.event_subscriptions

      ['SHIPMENT_COMMENT_CREATE', 'SHIPMENT_BOOK_REQ'].each do |event_type|
        sub = subscriptions.find {|s| s.event_type == event_type }
        if sub
          sub.update_attributes! system_message: true
        else
          user.event_subscriptions.create! event_type: event_type, system_message: true
        end
      end
    end
  end

  def search_names
    ["Not Booked", "Booking Requested", "All"]
  end

  def page_uid
    "chain-vp-shipment-panel"
  end

  def create_searches
    search_names.each do |name|
      case name
      when "Not Booked"
        create_search "Not Booked", {hiddenCriteria: [{field:'shp_booking_received_date', operator:'null'}]}
      when "Booking Requested"
        create_search("Booking Requested",
          {hiddenCriteria: [
            {field:'shp_booking_received_date', operator:'notnull'},
            {field:'shp_booking_confirmed_date', operator:'null'}
          ]}
        )
      when "All"
        create_search("All", {hiddenCriteria: []})
      else
        raise "Unexpected search name: #{name}"
      end
    end

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

  def create_allport
    allport = Company.where(system_code:'allport').first_or_create!(forwarder:true, name:'Allport Cargo Services')
    master = Company.where(master:true).first
    master.linked_companies << allport unless master.linked_companies.include?(allport)
    allport
  end

  def create_booking_unlocked_date
    cd = self.class.prep_custom_definitions([:shp_booking_unlocked_date])[:shp_booking_unlocked_date]
    fvr = FieldValidatorRule.where(custom_definition_id: cd.id, module_type: "Shipment", model_field_uid: cd.model_field_uid).first_or_create!
    fvr.update_attributes! mass_edit: true, can_mass_edit_groups: "LOGISTICS", can_edit_groups: "LOGISTICS", allow_everyone_to_view: true
    fvr
  end
end; end; end