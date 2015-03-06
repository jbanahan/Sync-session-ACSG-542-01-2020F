module OpenChain; module ModelFieldGenerator; module BrokerInvoiceEntryFieldGenerator
  def make_broker_invoice_entry_field sequence_number, mf_uid,field_reference,label,data_type,ent_exp_lambda,can_view_lambda=nil
    h = {:data_type=>data_type,
        :import_lambda => lambda {|inv,data| "#{label} cannot be set via invoice upload."},
        :export_lambda => lambda {|inv| inv.entry.blank? ? "" : ent_exp_lambda.call(inv.entry)},
        :qualified_field_name => "(SELECT #{field_reference} FROM entries where entries.id = broker_invoices.entry_id)"
      }
    h[:can_view_lambda]=can_view_lambda unless can_view_lambda.nil?
    [sequence_number,mf_uid,field_reference,label,h]
  end
end; end; end
