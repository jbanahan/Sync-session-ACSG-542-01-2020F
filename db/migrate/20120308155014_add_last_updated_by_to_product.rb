class AddLastUpdatedByToProduct < ActiveRecord::Migration
  def self.up
    add_column :products, :last_updated_by_id, :integer
    Product.where('1=1').each_with_index do |p,i|
      s = p.last_snapshot
      p.update_attributes(:last_updated_by_id=>s.user_id) if s
      puts "Updated #{i} products" if i.modulo(50) ==0
    end
  end

  def self.down
    remove_column :products, :last_updated_by_id
  end
end
