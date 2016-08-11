require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
module ConfigMigrations; module LL; class VendorMaintSearches

  def up
    create_search_table_configs make_config_hashes
  end
  def down
    delete_search_table_configs make_config_hashes
  end

  def create_search_table_configs config_hashes
    config_hashes.each do |ch|
      stc = SearchTableConfig.where(page_uid:ch[:page_uid],name:ch[:name]).first
      stc = SearchTableConfig.new(page_uid:ch[:page_uid],name:ch[:name]) unless stc
      stc.config_hash = ch[:config_hash]
      stc.save!
    end
  end

  def delete_search_table_configs config_hashes
    config_hashes.each do |ch|
      SearchTableConfig.where(page_uid:ch[:page_uid],name:ch[:name]).destroy_all
    end
  end

  def make_config_hashes
    defs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions [
      :prodven_risk, :prod_merch_cat_desc, :ord_planned_handover_date, :ord_ship_confirmation_date
    ]
    ship_conf_uid = defs[:ord_ship_confirmation_date].model_field_uid.to_s
    ph_uid = defs[:ord_planned_handover_date].model_field_uid.to_s
    ord_columns = ['ord_ord_num','ord_ord_date','ord_rule_state','ord_window_end',ph_uid,'ord_approval_status']
    r = [
      make_prodven_risk('Risk: All',nil,defs),
      make_prodven_risk('Risk: Low','Low',defs),
      make_prodven_risk('Risk: Medium','Medium',defs),
      make_prodven_risk('Risk: High','High',defs),
      make_prodven_risk('Risk: None','',defs)
    ]
    h = {
      page_uid: 'vendor-order',
      name: 'All',
      config_hash: {
        columns: ord_columns,
        sorts: [
          {field:'ord_ord_date',order:'A'}
        ]
      }
    }
    r.push h
    h = {
      page_uid: 'vendor-order',
      name: 'Open - All',
      config_hash: {
        columns: ord_columns,
        sorts: [
          {field:'ord_ord_date',order:'A'}
        ],
        criteria: [
          {field:'ord_closed_at',operator:'null'}
        ]
      }
    }
    r.push h
    h = {
      page_uid: 'vendor-order',
      name: 'Open - Shipped',
      config_hash: {
        columns: ord_columns,
        sorts: [
          {field:'ord_ord_date',order:'A'}
        ],
        criteria: [
          {field:'ord_closed_at',operator:'null'},
          {field:ship_conf_uid,operator:'notnull'}
        ]
      }
    }
    r.push h
    h = {
      page_uid: 'vendor-order',
      name: 'Open - Not Shipped',
      config_hash: {
        columns: ord_columns,
        sorts: [
          {field:'ord_ord_date',order:'A'}
        ],
        criteria: [
          {field:'ord_closed_at',operator:'null'},
          {field:ship_conf_uid,operator:'null'}
        ]
      }
    }
    r.push h
    h = {
      page_uid: 'vendor-address',
      name: 'All',
      config_hash: {
        columns: ["add_name", "add_full_address", "add_shipping"],
        sorts: [{"field"=>"add_name", "order"=>"A"}]
      }
    }
    r.push h
    r
  end

  def make_prodven_risk label, level, defs
    pvr_uid = defs[:prodven_risk].model_field_uid.to_s
    r = {
      page_uid: 'vendor-product',
      name: label,
      config_hash: {
        columns: ['prodven_puid','prodven_pname',"#{defs[:prod_merch_cat_desc].model_field_uid}_product_vendor_assignment",pvr_uid],
        criteria: [
        ],
        sorts: [
          {field:'prodven_puid',order:'A'}
        ]
      },
    }
    r[:config_hash][:criteria] << {field:pvr_uid,operator:'eq',val:level} unless level.nil?
    r
  end


end; end end
