describe OpenChain::DatabaseUtils do 

  subject { described_class }

  describe "deadlock_error?" do
    let (:deadlock) { Mysql2::Error.new "deadlock found when trying to get lock" }
    let (:lock_wait) { Mysql2::Error.new "lock wait timeout exceeded"}

    it "identifies Mysql2 deadlock error" do
      expect(subject.deadlock_error? deadlock).to eq true
    end

    it "identifies Mysql2 lock wait error" do
      expect(subject.deadlock_error? lock_wait).to eq true
    end

    it "returns false for other error types" do
      expect(subject.deadlock_error? StandardError.new("test")).to eq false
    end

    it "identifies a wrapped StatementInvalid error" do
      e = ActiveRecord::StatementInvalid.new "#{deadlock.class.name}: #{deadlock.message}"
      expect(subject.deadlock_error? e).to eq true
    end
  end

  describe "primary_database_configuration" do
    context "with standard rails database config" do

      let (:database_config) {
        {
          "adapter" => "adapter",
          "database" => "database",
          "username" => "username",
          "password" => "password",
          "host" => "host",
          "port" => 1000,
          "pool" => 1,
          "timeout" => 5000
        }
      }

      before :each do 
        allow(subject).to receive(:database_config).and_return database_config
      end

      it "parses standard database config" do
        config = subject.primary_database_configuration
        expect(config).not_to be_nil
        expect(config.size).to eq 5
        expect(config[:adapter]).to eq "adapter"
        expect(config[:database]).to eq "database"
        expect(config[:username]).to eq "username"
        expect(config[:host]).to eq "host"
        expect(config[:port]).to eq 1000
      end

      it "parses database config with URL" do
        database_config.clear
        database_config['url'] = "adapter://username:password@host:1000/database?pool=1&timeout=1000"

        config = subject.primary_database_configuration
        expect(config).not_to be_nil
        expect(config.size).to eq 5
        expect(config[:adapter]).to eq "adapter"
        expect(config[:database]).to eq "database"
        expect(config[:username]).to eq "username"
        expect(config[:host]).to eq "host"
        expect(config[:port]).to eq 1000
      end
    end

    context "with makara database config" do

      let (:database_config) {
        {
          "adapter" => "adapter_makara",
          "makara" => {
            "id" => "test_id",
            "connections" => [
              {
                "role" => "master",
                "name" => "primary",
                "adapter" => "adapter",
                "database" => "database",
                "username" => "username",
                "password" => "password",
                "host" => "host",
                "port" => 1000,
                "pool" => 1,
                "timeout" => 5000
              },
              {
                "name" => "replica",
                "adapter" => "replica_adapter",
                "database" => "replica_database",
                "username" => "replica_username",
                "password" => "replica_password",
                "host" => "replica_host",
                "port" => 1000,
                "pool" => 1,
                "timeout" => 5000
              }
            ]
          }
        }
      }

      before :each do 
        allow(subject).to receive(:database_config).and_return database_config
      end

      it "parses makara database config" do
        config = subject.primary_database_configuration
        expect(config).not_to be_nil
        expect(config.size).to eq 5
        expect(config[:adapter]).to eq "adapter_makara"
        expect(config[:database]).to eq "database"
        expect(config[:username]).to eq "username"
        expect(config[:host]).to eq "host"
        expect(config[:port]).to eq 1000
      end

      it "parses database config with URL" do
        master_config = database_config["makara"]["connections"].first
        ["adapter", "database", "username", "host", "port"].each { |k| master_config.delete k }
        master_config['url'] = "adapter://username:password@host:1000/database?pool=1&timeout=1000"

        config = subject.primary_database_configuration
        expect(config).not_to be_nil
        expect(config.size).to eq 5
        expect(config[:adapter]).to eq "adapter_makara"
        expect(config[:database]).to eq "database"
        expect(config[:username]).to eq "username"
        expect(config[:host]).to eq "host"
        expect(config[:port]).to eq 1000
      end
    end
  end
end