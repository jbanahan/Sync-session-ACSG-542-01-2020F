module OpenChain

  module CentralData

    class Version
      attr_accessor :name, :upgrade_password

      def self.all
        get_versions 
      end

      def self.create! name, upgrade_password
        r = nil
        a, idx = find name
        if idx
          v = a[idx]
          v.upgrade_password = upgrade_password
          r = v
        else
          new_v = Version.new
          new_v.name = name
          new_v.upgrade_password = upgrade_password
          a << new_v
          r = new_v
        end
        write_versions a
        r
      end

      def self.destroy name
        a, idx = find name
        if !idx.nil?
          a.delete_at idx
          write_versions a
        end
      end

      def self.destroy_all
        write_versions []
      end

      def self.get name
        a, idx = find name
        return idx.nil? ? nil : a[idx]
      end

      private
      #get array of versions from s3 or return [] 
      def self.get_versions
        connect {
          r = AWS::S3::S3Object.exists?(key_name,"chain-io") ? AWS::S3::S3Object.value(key_name, "chain-io") : nil
          a = r.blank? ? [] : ActiveSupport::JSON.decode(r)
          a.collect {|vh| make_obj(vh)}
        }
      end
      def self.write_versions version_array
        connect {
          AWS::S3::S3Object.store "#{Rails.env.to_s}/CentralData/Version", version_array.to_json, "chain-io"
        }
      end
      def self.key_name
        "#{Rails.env.to_s}/CentralData/Version"
      end
      def self.connect 
        base = YAML.load(IO.read("config/s3.yml"))
        y = {} #need to convert string keys into symbols
        base.each do |k,v|
          y[k.to_sym] = v
        end
        begin
          AWS::S3::S3Object.establish_connection!(y) unless AWS::S3::S3Object.connected?
          yield
        ensure
          AWS::S3::S3Object.disconnect if AWS::S3::S3Object.connected?
        end
      end
      #return array with get_versions result and found index (or nil as second element if not found)
      def self.find name
        a = get_versions
        obj = a.index {|ver| ver.name==name} 
        [a,obj]
      end
      def self.make_obj version_hash
        v = Version.new
        v.name = version_hash['name']
        v.upgrade_password = version_hash['upgrade_password']
        v
      end
    end

  end

end
