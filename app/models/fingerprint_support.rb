require 'digest'

# Included by default in core object support, can only be used on models that have model fields.
module FingerprintSupport
  extend ActiveSupport::Concern

  # This method takes a hash that defines which model fields and associations
  # to use to create the fingerprint.  A fingerprint_definition for something like
  # an entry would look like:
  #
  # {model_fields: [:ent_brok_ref, :ent_entry_num],
  #   commercial_invoices: {
  #     model_fields: [:ci_invoice_number, :ci_vendor_name],
  #     commercial_invoice_lines: {
  #       model_fields: [:cil_line_number, :cil_part_number],
  #       commercial_invoice_tariffs: {
  #         model_fields: [:cit_hts_code]
  #       }
  #     }
  #   }
  # },
  #   broker_invoices: {
  #     model_fields: [:bi_invoice_number],
  #     broker_invoice_lines: {
  #       model_fields: [:bil_charge_amount]
  #     }
  #   }
  # }
  def generate_fingerprint fingerprint_definition, user
    fingerprint_source = CoreObjectFingerprinter.new.process_fingerprint(self, fingerprint_definition, user)
    Digest::SHA1.hexdigest(fingerprint_source.join("\n"))
  end

  # Class here primarily for encapsulation of logic...don't want to expose these methods to classes including this module
  class CoreObjectFingerprinter

    def process_fingerprint obj, fingerprint_definition, user
      values = []
      model_fields = fingerprint_definition[:model_fields]
      values << get_field_values(obj, model_fields, user) unless model_fields.nil?

      fingerprint_definition.each_pair do |key, value|
        next if key == :model_fields
        # This raises an error if the association doesn't exist...it's not a very helpful error though, raise our own
        association = obj.association(key) rescue nil
        raise "No #{key} association exists for #{obj.class}" unless association

        target = association.load_target
        if target.blank?
          values << field_value_array(association.reflection.klass.name, [])
        else
          target = [target] unless association.reflection.collection?
          target.each do |child_object|
            # Skip lines that are meant to be deleted
            next if child_object.marked_for_destruction? || child_object.destroyed?

            # Keep all the values we get back flat, not nested at the entity level.
            values.push *process_fingerprint(child_object, value, user)
          end
        end
      end

      values
    end

    def get_field_values obj, model_fields, user
      field_values = model_fields.map do |field|
        mf = ModelField.find_by_uid(field)
        raise "Invalid model field key: #{field}." if mf.nil?
        val = mf.process_export(obj, user, true)
        val = val.nil? ? "nil" : val
      end

      field_value_array(obj.class.name, field_values)
    end

    def field_value_array object_name, values
      values.unshift object_name
      values.join("~") + "\n"
    end
  end
end