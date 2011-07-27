require 'aws'

module OpenChain

  module CentralData

    class Version
      attr_accessor :name, :upgrade_password

      def self.all
        r = []
        d.items.each do |item|
          v = Version.new
          v.name = item.name
          v.upgrade_password = item.attributes['upgrade_password'].values.first
          r << v
        end
        r
      end

      def self.create! name, upgrade_password
        d = domain
        d.items[name].attributes['upgrade_password'].set upgrade_password
        get name
      end

      def destroy
        item = domain.items[self.name]
        item.delete
      end

      def self.destroy_all
        domain.items.each {|item| item.delete}
      end

      def self.get name
        p = domain.items[name].attributes['upgrade_password'].values
        if p.blank?
          return nil
        else
          v = Version.new
          v.name = name
          v.upgrade_password = p.first
          v
        end
      end

      private
      def self.domain
        d = AWS::SimpleDB.new.domains["#{Rails.env.to_s}-Version"]
        d = AWS::SimpleDB.new.domains.create "#{Rails.env.to_s}-Version" unless d.exists?
        d
      end
      def domain
        d = AWS::SimpleDB.new.domains["#{Rails.env.to_s}-Version"]
        d = AWS::SimpleDB.new.domains.create "#{Rails.env.to_s}-Version" unless d.exists?
        d
      end
    end

  end

end
