module ConfigMigrations; module Common; class ProductInactiveSow1610

  def up
    ss = SearchSetup.where(name: "ADVAN/CQ Parts Upload (Do Not Delete or Modify!)")
    ss.each do |s| 
      r = SearchColumn.where(search_setup_id: s.id).order("rank DESC").first
      SearchColumn.create!(
        search_setup_id: s.id, 
        model_field_uid: 'prod_inactive',
        rank: r.rank + 1)
    end
  end

  def down
    SearchColumn.where(model_field_uid: 'prod_inactive').destroy_all
    nil
  end

end; end; end
