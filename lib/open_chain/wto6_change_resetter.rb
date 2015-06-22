module OpenChain; class Wto6ChangeResetter
  def self.run_schedulable opts
    Product.where('updated_at >= ?',opts['last_started_at']).each do |p|
      reset_fields_if_changed(p,opts['change_date_field'],opts['fields_to_reset'])
    end
  end

  def self.reset_fields_if_changed product, change_date_field, fields_to_reset
    mf_cd = ModelField.find_by_uid(change_date_field)
    cd = mf_cd.process_export(product,nil,true)
    if cd && product.wto6_changed_after?(cd)
      fields_to_reset.each do |uid| 
        ModelField.find_by_uid(uid).process_import(product,nil,User.integration)
      end
      product.save!
      product.create_snapshot(User.integration)
    end
    nil #no return value
  end
end; end