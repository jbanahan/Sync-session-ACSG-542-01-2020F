class DailyStatementEntry < ActiveRecord::Base

  belongs_to :daily_statement, inverse_of: :daily_statement_entries
  has_many :daily_statement_entry_fees, dependent: :destroy, autosave: true, inverse_of: :daily_statement_entry
  belongs_to :port, class_name: "Port", foreign_key: "port_code", primary_key: "schedule_d_code"
  belongs_to :entry, inverse_of: :daily_statement_entry

end