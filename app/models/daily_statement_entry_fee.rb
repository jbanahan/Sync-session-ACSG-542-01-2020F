# == Schema Information
#
# Table name: daily_statement_entry_fees
#
#  id                       :integer          not null, primary key
#  daily_statement_entry_id :integer
#  code                     :string(255)
#  description              :string(255)
#  amount                   :decimal(11, 2)
#  preliminary_amount       :decimal(11, 2)
#
# Indexes
#
#  index_daily_statement_entry_fees_on_daily_statement_entry_id  (daily_statement_entry_id)
#

class DailyStatementEntryFee < ActiveRecord::Base

  belongs_to :daily_statement_entry, inverse_of: :daily_statement_entry_fees
  
end
