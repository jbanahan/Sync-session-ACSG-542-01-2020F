# == Schema Information
#
# Table name: summary_statements
#
#  created_at       :datetime         not null
#  customer_id      :integer          not null
#  id               :integer          not null, primary key
#  statement_number :string(255)
#  updated_at       :datetime         not null
#

class SummaryStatement < ActiveRecord::Base
  has_many :broker_invoices
  belongs_to :customer, class_name: "Company"
  validates :customer_id, :statement_number, presence: true

  def self.include? invoice_id
    !joins(:broker_invoices).where(broker_invoices: {id: invoice_id}).empty?
  end

  def belongs_to_customer? invoice_id
    broker_invoice = BrokerInvoice.where(id: invoice_id).first
    return false unless broker_invoice
    linked_co_qry = "SELECT companies.id
                     FROM companies
                      INNER JOIN entries ON companies.id = entries.importer_id
                      INNER JOIN broker_invoices ON entries.id = broker_invoices.entry_id
                      INNER JOIN linked_companies on parent_id = #{self.customer_id} AND entries.importer_id = child_id"
    broker_invoice.entry.importer == self.customer || !(ActiveRecord::Base.connection.execute linked_co_qry).count.zero?
  end

  def self.search_where(user)
    "customer_id in (#{user.available_importers.pluck(:id).join(', ')})"
  end

  def can_view? user
    user.view_broker_invoices?
  end

  def total
    broker_invoices.inject(0) { |acc, nxt| acc += nxt.invoice_total }
  end

  def add! invoice_id
    target = BrokerInvoice.find(invoice_id)
    raise "Invoice #{target.invoice_number} is already assigned to a statement." if SummaryStatement.include? target.id
    raise "Invoice #{target.invoice_number} does not belong to customer." unless belongs_to_customer? target.id
    broker_invoices << target
  end

  def remove! invoice_id
    target = BrokerInvoice.find(invoice_id)
    invoice_list = broker_invoices.pluck(:id)
    raise "Invoice #{target.invoice_number} is not on this statement." unless invoice_list.include? target.id
    target.summary_statement_id = nil
    target.save!
  end

end
