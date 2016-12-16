require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_change_comparator'
module ConfigMigrations; module LL; class PriceRevised
  def up
    cdefs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions [:ordln_price_revised_date,:ord_price_revised_date,:ord_customs_entry_note]
    set_field_validator_rules cdefs
    revise_pricing_on_open_orders
  end
  def down
  end

  def revise_pricing_on_open_orders
    k = OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator
    Order.where("closed_at is null or closed_at > '2016-10-01 00:00'").each do |o|
      prev = nil
      o.entity_snapshots.order(:id).each do |es|
        od = nil
        if prev
          od = k::OrderData.build_from_hash prev.snapshot_hash
        end
        nd = k::OrderData.build_from_hash es.snapshot_hash
        k.set_price_revised_dates(o,od,nd)
        prev = es
      end
    end
  end

  def set_field_validator_rules cdefs
    set_customs_entry_note_fvr cdefs[:ord_customs_entry_note]
  end

  def set_customs_entry_note_fvr cdef
    User.integration.groups << Group.use_system_group('TRADECOMP',name:'Trade Compliance', create:true) unless User.integration.in_group?('TRADECOMP')
    fvr = FieldValidatorRule.where(model_field_uid:cdef.model_field_uid).first_or_create!
    fvr.update_attributes(can_view_groups:'TRADECOMP',can_edit_groups:'TRADECOMP')
    ModelField.reload
  end
end; end; end
