require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module ConfigMigrations; module LL; class BackfillPatentCarbStatements
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def backfill_orders order_ids: nil, closed: false
    user = User.integration

    query = Order
    if order_ids
      query = query.where(id: order_ids)
    end

    if closed
      query = query.where("closed_at IS NOT NULL")
    else
      query = query.where("closed_at IS NULL")
    end

    query.find_each do |order|
      snapshot = false
      Lock.db_lock(order) do
        order.order_lines.each do |line|
          pva = product_vendor_assignment(order.vendor_id, line.product_id)
          if pva
            carb_updated = set_statement_value(pva, order, line, "CARB Statement", cdefs[:ordln_carb_statement])
            patent_updated = set_statement_value(pva, order, line, "Patent Statement", cdefs[:ordln_patent_statement])
            if carb_updated || patent_updated
              snapshot = true
            end
          end
        end

        order.create_snapshot(user, nil, "SOW 1522: Backfill CARB/Patent Statements") if snapshot
      end
    end
  end

  def product_vendor_assignment vendor_id, product_id
    @cache ||= Hash.new do |h, k|
      h[k] = ProductVendorAssignment.where(vendor_id: k[0], product_id: k[1]).first
    end

    @cache[[vendor_id, product_id]]
  end

  def backfill_product_vendor_assignments ids: nil
    user = User.integration

    query = ProductVendorAssignment
    query = query.where(id: ids) unless ids.blank?
    query.find_each do |pva|
      Lock.db_lock(pva) do
        snapshot = false

        if !pva.custom_value(cdefs[:prodven_carb]).blank? && pva.constant_text_for_date("CARB Statement").nil?
          pva.constant_texts.create! constant_text: fix_em_dashes(pva.custom_value(cdefs[:prodven_carb])), text_type: "CARB Statement", effective_date_start: Date.new(2000, 1, 1)
          snapshot = true
        end

        if !pva.custom_value(cdefs[:prodven_patent]).blank? && pva.constant_text_for_date("Patent Statement").nil?
          pva.constant_texts.create! constant_text: fix_em_dashes(pva.custom_value(cdefs[:prodven_patent])), text_type: "Patent Statement", effective_date_start: Date.new(2000, 1, 1)
          snapshot = true
        end

        pva.create_snapshot(user, nil, "SOW 1522: Backfill CARB/Patent Statements") if snapshot
      end
    end

    # Lumber wants to migrate all Carb Statements that have a code of "D- Back panel complies with California CA 93120 Phase 2 for formaldehyde"
    # to a new code of "Z - BACKER BOARD COMPLIES WITH TSCA TITLE VI AND CARB PHASE 2 FORMALDEHYDE EMISSION STANDARDS"
    ConstantText.where(text_type: "CARB Statement").where("constant_text LIKE 'D%'").each do |text|
      Lock.db_lock(text.constant_textable) do
        text.update_attributes! constant_text: "Z - BACKER BOARD COMPLIES WITH TSCA TITLE VI AND CARB PHASE 2 FORMALDEHYDE EMISSION STANDARDS"
        text.constant_textable.create_snapshot(user, nil, "SOW 1522: Migrate 'D' CARB codes to 'Z'")
      end
    end
  end

  private
    def cdefs
      @cdefs ||= self.class.prep_custom_definitions([:ordln_carb_statement, :ordln_patent_statement, :prodven_patent, :prodven_carb])
    end

    def set_statement_value pva, order, line, text_type, cdef
      text = pva.constant_text_for_date(text_type, reference_date: order.order_date).try(:constant_text)
      return false if text.blank?

      existing = line.custom_value(cdef)
      if text != existing
        line.update_custom_value! cdef, text
        return true
      else
        return false
      end
    end

    def fix_em_dashes string
      string.gsub("–", "-")
    end
end; end; end