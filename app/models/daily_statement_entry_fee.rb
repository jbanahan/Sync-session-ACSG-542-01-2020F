# == Schema Information
#
# Table name: daily_statement_entry_fees
#
#  amount                   :decimal(11, 2)
#  code                     :string(255)
#  daily_statement_entry_id :integer
#  description              :string(255)
#  id                       :integer          not null, primary key
#  preliminary_amount       :decimal(11, 2)
#
# Indexes
#
#  index_daily_statement_entry_fees_on_daily_statement_entry_id  (daily_statement_entry_id)
#

class DailyStatementEntryFee < ActiveRecord::Base

  belongs_to :daily_statement_entry, inverse_of: :daily_statement_entry_fees
  
end
