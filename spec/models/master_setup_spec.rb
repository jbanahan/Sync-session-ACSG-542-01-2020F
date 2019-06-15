describe MasterSetup do
  describe 'custom_features_list' do
    before :each do
      @m = MasterSetup.new
      @m.custom_features = nil
    end
    it 'should take an array of custom features and return the array' do
      features = ['a','b','c']
      @m.custom_features_list = features
      expect(@m.custom_features_list).to eq(features)
    end
    it 'should take a string with line breaks and return the array' do
      features = ['a','b','c']
      @m.custom_features_list = features.join('\r\n')
      expect(@m.custom_features).to eq(features.join('\r\n'))
      @m.custom_features_list = features
    end
    it 'should check on custom_feature?' do
      features = ['a','b','c']
      @m.custom_features_list = features
      expect(@m).to be_custom_feature('a')
      expect(@m).not_to be_custom_feature('d')
    end
  end

  context "current_repository_version" do
    subject { described_class }

    context "with production setup" do
      before :each do 
        expect(subject).to receive(:production_env?).and_return true
      end

      it "uses git class to determine currently checked out release number" do
        expect(OpenChain::Git).to receive(:current_tag_name).with(allow_branch_name: false).and_return "tag_name"
        expect(subject.current_repository_version).to eq "tag_name"
      end
    end

    context "with non-production setup" do
      before :each do 
        expect(subject).to receive(:production_env?).and_return false
      end

      it "uses git class to determine currently checked out release number" do
        expect(OpenChain::Git).to receive(:current_tag_name).with(allow_branch_name: true).and_return "tag_name"
        expect(subject.current_repository_version).to eq "tag_name"
      end
    end

  end

  context "current_code_version" do
    before :each do 
      # Set a known value into the CURRENT_VERSION constant just to make sure that's what current_code_version
      # is utilizing
      @existing_version = MasterSetup::CURRENT_VERSION
      MasterSetup.send(:remove_const, 'CURRENT_VERSION')
      MasterSetup.send(:const_set, 'CURRENT_VERSION', 'testing')
    end

    after :each do
      MasterSetup.send(:remove_const, 'CURRENT_VERSION')
      MasterSetup.send(:const_set, 'CURRENT_VERSION', @existing_version)
    end

    it "should read the current version using the CURRENT_VERSION class var" do
      expect(MasterSetup.current_code_version).to eq "testing"
    end
  end

  context "need_upgrade?" do
    let! (:master_setup) { 
      ms = MasterSetup.create! target_version: "CURRENT"
      allow(MasterSetup).to receive(:get).with(false).and_return ms
      ms
    }
    
    it "should require an upgrade if the target version from the DB is not the same as the current code version" do
      master_setup.update_attributes! :target_version => "UPDATE ME!!!"
      expect(MasterSetup.need_upgrade?).to be_truthy
    end

    it "should not require an upgrade if the target version is same as current code version" do
      expect(MasterSetup).to receive(:current_code_version).and_return "CURRENT"
      expect(MasterSetup.need_upgrade?).to be_falsey
    end

    it "should not require an upgrade if the target version is blank" do
      master_setup.update_attributes :target_version => nil
      expect(MasterSetup.need_upgrade?).to be_falsey
    end
  end

  describe "get_migration_lock" do
    let! (:master_setup) { 
      ms = MasterSetup.first_or_create! 
      allow(MasterSetup).to receive(:first).and_return ms
      ms
    }
    subject { described_class }

    it "sets hostname into a blank migration lock" do
      expect(MasterSetup.get_migration_lock host: "host").to eq true
      expect(MasterSetup.first.migration_host).to eq "host"
    end

    it "does not set hostname if it's already set" do 
      master_setup.update_attributes! migration_host: "host2"
      expect(MasterSetup.get_migration_lock host: "host").to eq false
      expect(MasterSetup.first.migration_host).to eq "host2"
    end

    it "uses locking" do
      expect(Lock).to receive(:with_lock_retry).with(an_instance_of(MasterSetup)).and_yield
      expect(subject.get_migration_lock host: "host").to eq true
    end

    it "uses hostname syscall if host is not provided" do
      expect(subject).to receive(:hostname).with(nil).and_return 'host'

      expect(subject.get_migration_lock).to eq true
      expect(MasterSetup.first.migration_host).to eq "host"
    end
  end

  describe "release_migration_lock" do
    let! (:master_setup) { 
      ms = MasterSetup.first_or_create! 
      allow(MasterSetup).to receive(:first).and_return ms
      ms
    }
    subject { described_class }

    it "clears the migration host if it's set to the current host" do
      master_setup.update_attributes! migration_host: "host"
      subject.release_migration_lock host: "host"

      master_setup.reload
      expect(master_setup.migration_host).to be_nil
    end

    it "does not clear the host if the hostname is different" do
      master_setup.update_attributes! migration_host: "host"
      subject.release_migration_lock host: "host2"

      master_setup.reload
      expect(master_setup.migration_host).to eq "host"
    end

    it "uses locking" do
      master_setup.update_attributes! migration_host: "host"
      expect(Lock).to receive(:with_lock_retry).with(an_instance_of(MasterSetup)).and_yield
      subject.release_migration_lock host: "host"
    end

    it "uses hostname syscall if host is not provided" do
      expect(subject).to receive(:hostname).with(nil).and_return 'host'

      subject.release_migration_lock
    end

    it "allows force releasing" do
      master_setup.update_attributes! migration_host: "host"
      subject.release_migration_lock host: "host2", force_release: true

      master_setup.reload
      expect(master_setup.migration_host).to be_nil
    end
  end
  
  describe "config_true?" do

    it "returns false if config value isn't set" do
      expect(MasterSetup.config_true? :some_value).to eq false
    end

    it "returns true if config value is set" do
      Rails.application.config.vfitrack[:key] = true
      expect(MasterSetup.config_true? :key).to eq true
    end

    it "returns true if config value is set to string value 'true'" do
      Rails.application.config.vfitrack[:key] = 'true'
      expect(MasterSetup.config_true? :key).to eq true
    end

    it "returns false if config value is anything else" do 
      Rails.application.config.vfitrack[:key] = Object.new
      expect(MasterSetup.config_true? :key).to eq false
    end

    it "yields block if value is true" do
      Rails.application.config.vfitrack[:key] = true
      expect { |b| MasterSetup.config_true?(:key, &b) }.to yield_control
    end

    it "does not yield if value is not true" do
      Rails.application.config.vfitrack[:key] = false
      expect { |b| MasterSetup.config_true?(:key, &b) }.not_to yield_control
    end
  end

  describe "config_value" do 
    
    context "with a config value" do
      before :each do
        Rails.application.config.vfitrack[:key] = "value"
      end

      it "returns configuration value" do
        expect(MasterSetup.config_value(:key)).to eq "value"
      end

      it "yields the configuration value" do
        expect { |b| MasterSetup.config_value(:key, &b)}.to yield_with_args("value")
      end

      it "yields config value over default" do
        expect { |b| MasterSetup.config_value(:key, default: "default", &b)}.to yield_with_args("value")
      end

      it "only yields if yield_if_equals value matches" do
        expect { |b| MasterSetup.config_value(:key, yield_if_equals: "value", &b)}.to yield_with_args("value")
      end

      it "does not yield if yield_if_equals value does not match" do
        expect { |b| MasterSetup.config_value(:key, yield_if_equals: "not the value", &b)}.not_to yield_control
      end
    end

    it "returns nil if configuration is nil" do
      expect(MasterSetup.config_value(:key)).to eq nil
    end

    it "does not yield if configuration is nil" do
      expect {|b| MasterSetup.config_value(:key, &b)}.not_to yield_control
    end

    it "returns default value if key is nil" do
      expect(MasterSetup.config_value(:key, default: "key")).to eq "key"
    end

    it "yields default if key is nil" do
      expect { |b| MasterSetup.config_value(:key, default: "default", &b)}.to yield_with_args("default")
    end

    it "uses default value as yield_if_equals value if key is nil" do
      expect { |b| MasterSetup.config_value(:key, default: "default", yield_if_equals: "default", &b)}.to yield_with_args("default")
    end
  end
  
  describe "production?" do
    let (:master_setup) {  }

    it "returns true if a production custom_feature is set" do
      expect((MasterSetup.new custom_features: "production").production?).to eq true
    end

    it "returns false if a production custom feature is not set" do
      expect(MasterSetup.new.production?).to eq false
    end
  end

  describe "ftp_enabled?" do

    let! (:master_setup) {
      ms = stub_master_setup
    }

    it "returns false when not in production, regardless of master setup value" do
      expect(MasterSetup).to receive(:production_env?).and_return false
      expect(master_setup).not_to receive(:suppress_ftp?)
      expect(MasterSetup.ftp_enabled?).to eq false
    end

    it "returns negation of suppress ftp when in production" do
      expect(MasterSetup).to receive(:production_env?).and_return true
      expect(master_setup).to receive(:suppress_ftp?).and_return false
      expect(MasterSetup.ftp_enabled?).to eq true
    end
  end

  describe "email_enabled?" do

    let! (:master_setup) {
      ms = stub_master_setup
    }

    it "returns false when not in production, regardless of master setup value" do
      expect(MasterSetup).to receive(:production_env?).and_return false
      expect(master_setup).not_to receive(:suppress_email?)
      expect(MasterSetup.email_enabled?).to eq false
    end

    it "returns negation of suppress email when in production" do
      expect(MasterSetup).to receive(:production_env?).and_return true
      expect(master_setup).to receive(:suppress_email?).and_return false
      expect(MasterSetup.email_enabled?).to eq true
    end
  end

  let! (:database_config) {
    {adapter: "mysql2", database: "database_name", username: "user", password: "password", host: "db.host.com", port: 3306, pool: 15, timeout: 5000, flags: 2}
  }

  describe "database_host" do 
    before :each do 
      allow(OpenChain::DatabaseUtils).to receive(:primary_database_configuration).and_return database_config
    end

    it "returns host db config value" do
      expect(MasterSetup.database_host).to eq "db.host.com"
    end

    it "returns only the machine name" do
      expect(MasterSetup.database_host machine_name_only: true).to eq "db"
    end
  end

  describe "database_name" do
    before :each do 
      allow(OpenChain::DatabaseUtils).to receive(:primary_database_configuration).and_return database_config
    end

    it "returns database config value" do
      expect(MasterSetup.database_name).to eq "database_name"
    end
  end
  
  describe "upgrades_allowed?" do
    let! (:ms) { stub_master_setup }
    let (:config) { {} }
    before :each do 
      allow(MasterSetup).to receive(:vfitrack_config).and_return(config)
    end

    it "returns true by default" do
      expect(MasterSetup.upgrades_allowed?).to eq true
    end

    it "returns false if 'Prevent Upgrades' custom feature is enabled" do
      expect(ms).to receive(:custom_feature?).with("Prevent Upgrades").and_return true
      expect(MasterSetup.upgrades_allowed?).to eq false
    end

    it "returns false if 'prevent_upgrades' is true in config" do 
      config[:prevent_upgrades] = true
      expect(MasterSetup.upgrades_allowed?).to eq false
    end

    it "returns true if 'prevent_upgrades' is false in config" do 
      config[:prevent_upgrades] = false
      expect(MasterSetup.upgrades_allowed?).to eq true
    end
  end

  describe "production_env?" do 
    let (:production) { ActiveSupport::StringInquirer.new "production" }
    let (:test) { ActiveSupport::StringInquirer.new "test" }

    subject { described_class }

    it "returns true if using production rails environment" do
      expect(subject).to receive(:rails_env).and_return production
      expect(subject.production_env?).to eq true
    end

    it "returns false if not production rails environment" do
      expect(subject).to receive(:rails_env).and_return test
      expect(subject.production_env?).to eq false
    end
  end

  describe "test_env?" do 
    let (:production) { ActiveSupport::StringInquirer.new "production" }
    let (:test) { ActiveSupport::StringInquirer.new "test" }

    subject { described_class }

    it "returns true if using test rails environment" do
      expect(subject).to receive(:rails_env).and_return test
      expect(subject.test_env?).to eq true
    end

    it "returns false if not test rails environment" do
      expect(subject).to receive(:rails_env).and_return production
      expect(subject.test_env?).to eq false
    end
  end

  describe "test_env?" do 
    let (:production) { ActiveSupport::StringInquirer.new "production" }
    let (:dev) { ActiveSupport::StringInquirer.new "development" }

    subject { described_class }

    it "returns true if using dev rails environment" do
      expect(subject).to receive(:rails_env).and_return dev
      expect(subject.development_env?).to eq true
    end

    it "returns false if not dev rails environment" do
      expect(subject).to receive(:rails_env).and_return production
      expect(subject.development_env?).to eq false
    end
  end

  describe "rails_env" do
    subject { described_class }

    it 'returns Rails.env' do
      # force equality comparison based on the actual object id to ensure the right value is getting used
      expect(subject.rails_env.object_id).to eq Rails.env.object_id
    end
  end

  describe "instance_directory" do
    subject { described_class }

    it "returns Rails.root" do
      expect(subject.instance_directory).to eq Rails.root
    end
  end
end
