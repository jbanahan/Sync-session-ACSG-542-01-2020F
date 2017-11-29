class DailyStatementEntryFee < ActiveRecord::Base

  belongs_to :daily_statement_entry, inverse_of: :daily_statement_entry_fees
  
end