module ConfigMigrations; module LL; class Sow1387

  def up
    fl = FieldLabel.create!(model_field_uid:'shp_departure_last_foreign_port_date',label:'Depart From Transship Port')
  end

  def down
    FieldLabel.where(model_field_uid:'shp_departure_last_foreign_port_date').first.delete
  end

end; end; end