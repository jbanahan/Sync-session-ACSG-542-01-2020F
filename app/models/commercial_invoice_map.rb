class CommercialInvoiceMap < ActiveRecord::Base
  #generate a commercial invoice based on the given shipment lines (which all must be from the same shipment)
  def self.generate_invoice! user, shipment_lines, field_override_hash = {}
    CommercialInvoice.transaction do 
      shipments = shipment_lines.collect {|sl| sl.shipment}.uniq
      if shipments.size != 1
        raise "Cannot generate invoice with lines from multiple shipments."   
      end
      header_map, line_map, tariff_map = get_maps
      shipment = shipments.first
      obj_map = {CoreModule::SHIPMENT=>shipment,
        CoreModule::SHIPMENT_LINE=>shipment_lines.first,
        CoreModule::PRODUCT=>shipment_lines.first.product,
        CoreModule::ORDER_LINE=>shipment_lines.first.order_lines.first
      }
      obj_map[CoreModule::ORDER] = shipment_lines.first.order_lines.first.order unless obj_map[CoreModule::ORDER_LINE].blank?
      ci = CommercialInvoice.create!
      header_map.each do |src,dest|
        val = src.process_export(obj_map[src.core_module],user)
        if val && dest.custom?
          ci.update_custom_value! dest.custom_id, val
        elsif val
          dest.process_import ci, val
        end
      end
      field_override_hash.each do |uid,val|
        mf = ModelField.find_by_uid uid
        if !val.blank? && mf && mf.core_module == CoreModule::COMMERCIAL_INVOICE
          if mf.custom?
            ci.update_custom_value! mf.custom_id, val
          else
            mf.process_import ci, val
          end
        end
      end
      ship_to = shipment.ship_to
      ship_invoice_map = {}
      shipment_lines.each do |sl|
        obj_map[CoreModule::SHIPMENT_LINE]=sl
        obj_map[CoreModule::PRODUCT]=sl.product
        obj_map[CoreModule::ORDER_LINE]=sl.order_lines.first
        obj_map[CoreModule::ORDER]=obj_map[CoreModule::ORDER_LINE].order if obj_map[CoreModule::ORDER_LINE]
        c_line = ci.commercial_invoice_lines.build
        ship_invoice_map[sl] = c_line
        ct = nil
        line_map.each do |src,dest|
          val = src.process_export(obj_map[src.core_module],user)
          dest.process_import c_line, val if val
        end
        if tariff_map.size > 0
          ct = c_line.commercial_invoice_tariffs.build
          line_map.each do |src,dest|
            val = src.process_export(obj_map[src.core_module],user)
            dest.process_import ct, val if val
          end
        end
        if field_override_hash[:lines] && field_override_hash[:lines][sl.id.to_s]
          field_override_hash[:lines][sl.id.to_s].each do |mfid,val|
            mf = ModelField.find_by_uid mfid
            if val && mf
              case mf.core_module
              when CoreModule::COMMERCIAL_INVOICE_LINE
                mf.process_import c_line, val
              when CoreModule::COMMERCIAL_INVOICE_TARIFF
                ct ||= c_line.commercial_invoice_tariffs.build
                mf.process_import ct, val
              end
            end
          end
        end
        if ship_to && ship_to.country_id
          cf = sl.product.classifications.where(:country_id=>ship_to.country_id).first
          if cf
            tar = cf.tariff_records.first
            if tar
              ct ||= c_line.commercial_invoice_tariffs.build
              ct.hts_code = tar.hts_1
            end
          end
        end
        c_line.value = c_line.quantity * c_line.unit_price if !c_line.quantity.nil? && !c_line.unit_price.nil?
      end
      ci.save!
      ship_invoice_map.each do |sl,cl|
        if sl.order_lines.blank?
          PieceSet.create!(:shipment_line_id=>sl.id,:commercial_invoice_line_id=>cl.id,:quantity=>sl.quantity)
        else
          ps = PieceSet.where(:shipment_line_id=>sl.id,:order_line_id=>sl.order_lines.first.id).first
          ps = PieceSet.new(:shipment_line_id=>sl.id,:order_line_id=>sl.order_lines.first.id,:quantity=>sl.quantity) unless ps
          ps.update_attributes(:commercial_invoice_line_id=>cl.id)
        end
      end
      ci
    end
  end

  private
  def self.get_maps
    map = CommercialInvoiceMap.all
    header_map = {}
    line_map = {}
    tariff_map = {}
    map.each do |m|
      mf = ModelField.find_by_uid m.destination_mfid
      map_to_use = nil
      case mf.core_module
      when CoreModule::COMMERCIAL_INVOICE
        map_to_use = header_map
      when CoreModule::COMMERCIAL_INVOICE_LINE
        map_to_use = line_map
      when CoreModule::COMMERCIAL_INVOICE_TARIFF
        map_to_use = tariff_map
      else
        raise "Cannot map when destination is not a commercial invoice field #{m.destination_mfid}"
      end
      map_to_use[ModelField.find_by_uid(m.source_mfid)] = ModelField.find_by_uid(m.destination_mfid)
    end
    [header_map,line_map,tariff_map]
  end
end
