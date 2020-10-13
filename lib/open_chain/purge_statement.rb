module OpenChain; class PurgeStatement
  def self.run_schedulable
    self.purge
  end

  def self.purge received_date = 5.years.ago, final_received_date = 5.years.ago
    MonthlyStatement.where("received_date < ? OR (received_date IS NULL AND final_received_date < ?)", received_date, final_received_date).destroy_all
  end
end; end
