module OpenChain; class DemoAgeIncrementer
  def initialize
    @modules ||= ["Product", "Order", "Shipment", "SecurityFiling", "Entry", "BrokerInvoice", "Invoice"]
    @updated_records = 0
    @failed_records = 0
  end

  def self.run_schedulable(opts={})
    self.new.run(User.integration, opts['days_to_increment'])
  end

  def run_custom_value_queries(days_to_increment)
    hours_to_increment = (days_to_increment.to_i * 24)

    CustomValue.where('custom_values.date_value IS NOT NULL').where(customizable_type: @modules).
        update_all(["custom_values.date_value=DATE_ADD(custom_values.date_value, INTERVAL ? DAY)", days_to_increment])

    CustomValue.where('custom_values.datetime_value IS NOT NULL').where(customizable_type: @modules).
        update_all(["custom_values.datetime_value=ADDTIME(custom_values.datetime_value, '?:00:00')", hours_to_increment])
  end

  def run(user, days_to_increment="30")
    return unless MasterSetup.get.custom_feature?("Demo Aging")
    run_custom_value_queries(days_to_increment)

    days_to_increment = days_to_increment.to_i

    @modules.each do |klass|
      klass = klass.constantize

      fields = klass.columns.select { |column| column.sql_type == "datetime" || column.sql_type == "date" }.map { |column| column.name }

      klass.all.find_each do |record|
        begin
          fields.each do |field|
              initial_value = record.public_send(field)
              record.public_send("#{field}=", initial_value + days_to_increment.days) unless initial_value == nil
            end
            record.save!
            @updated_records += 1
        rescue
          @failed_records += 1
        end
      end
    end
  end
end; end