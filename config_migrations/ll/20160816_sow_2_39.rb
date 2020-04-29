require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_pdf_generator'
module ConfigMigrations; module LL; class SOW239
  def up
    update_orders
    rename_ordln_pname
  end
  def down
  end

  def rename_ordln_pname
    fl = FieldLabel.where(model_field_uid:'ordln_pname').first
    fl = FieldLabel.new(model_field_uid:'ordln_pname')
    fl.label = 'Article Record Part Name'
    fl.save!
  end

  def update_orders
    cdefs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions [:ordln_old_art_number, :ordln_part_name, :prod_old_article]
    u = User.integration
    Order.includes(:order_lines).find_each do |o|
      needs_new_pdf = false
      o.order_lines.each do |ol|
        prod_art_hash = find_product_and_values(ol, cdefs)
        ol.update_custom_value!(cdefs[:ordln_old_art_number], prod_art_hash[:old_art])
        ol.update_custom_value!(cdefs[:ordln_part_name], prod_art_hash[:name])
        needs_new_pdf = true if prod_art_hash[:product].name != prod_art_hash[:name] || prod_art_hash[:current_old_art] != prod_art_hash[:old_art]
      end
      if needs_new_pdf
        OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator.create!(o, u)
      end
      o.create_snapshot u
    end
  end

  def find_product_and_values order_line, cdefs
    p = order_line.product
    es = p.entity_snapshots.where('created_at < ?', order_line.created_at).order('created_at desc').first
    old_art = nil
    name = nil
    if es
      h = es.snapshot_json
      old_art = h['entity']['model_fields'][cdefs[:prod_old_article].model_field_uid.to_s]
      name = h['entity']['model_fields']['prod_name']
    end
    current_old_art = p.custom_value(cdefs[:prod_old_article])
    if old_art.blank?
      old_art = current_old_art
    end
    if name.blank?
      name = p.name
    end
    return {
      product: p,
      name: name,
      old_art: old_art,
      current_old_art: current_old_art
    }
  end
end; end; end
