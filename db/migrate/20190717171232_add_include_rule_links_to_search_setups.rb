class AddIncludeRuleLinksToSearchSetups < ActiveRecord::Migration
  def change
    add_column :search_setups, :include_rule_links, :boolean
  end
end
