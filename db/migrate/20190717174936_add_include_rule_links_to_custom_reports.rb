class AddIncludeRuleLinksToCustomReports < ActiveRecord::Migration
  def change
    add_column :custom_reports, :include_rule_links, :boolean
  end
end
