require 'open_chain/purge_options_support'

module OpenChain; class PurgeStatement
  include OpenChain::PurgeOptionsSupport

  def self.run_schedulable opts = {}
    # Definined in PurgeOptionsSupport
    execute_purge(opts, default_years_ago: 5)
  end

  def self.purge older_than:
    ids = MonthlyStatement.where("received_date < ? OR (received_date IS NULL AND final_received_date < ?)", older_than, older_than).order(:id).pluck(:id)

    ids.each_slice(500) do |batched_ids|
      statements = MonthlyStatement.where(id: batched_ids)

      statements.each do |statement|
        statement.destroy
      rescue StandardError => e
        e.log_me "Failed to purge monthly statement id #{statement.id}."
      end
    end
  end
end; end
