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

    it "unwraps exception cause and examines that error instead" do
      e = ActiveRecord::StatementInvalid.new "Derrr..something broke"
      allow(e).to receive(:cause).and_return deadlock
      expect(subject.deadlock_error? e).to eq true
    end

    it "identifies ActiveRecord::TransactionIsolationConflict as a deadlock" do
      expect(subject.deadlock_error? ActiveRecord::TransactionIsolationConflict.new("Error")).to eq true
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
          "timeout" => 5000,
          "encoding" => "enc",
          "collation" => "coll"
        }
      }

      before :each do 
        allow(subject).to receive(:database_config).and_return database_config
      end

      it "parses standard database config" do
        config = subject.primary_database_configuration
        expect(config).not_to be_nil
        expect(config.size).to eq 7
        expect(config[:adapter]).to eq "adapter"
        expect(config[:database]).to eq "database"
        expect(config[:username]).to eq "username"
        expect(config[:host]).to eq "host"
        expect(config[:port]).to eq 1000
        expect(config[:encoding]).to eq "enc"
        expect(config[:collation]).to eq "coll"
      end

      it "parses database config with URL" do
        database_config.clear
        database_config['url'] = "adapter://username:password@host:1000/database?pool=1&timeout=1000&encoding=enc&collation=coll"

        config = subject.primary_database_configuration
        expect(config).not_to be_nil
        expect(config.size).to eq 7
        expect(config[:adapter]).to eq "adapter"
        expect(config[:database]).to eq "database"
        expect(config[:username]).to eq "username"
        expect(config[:host]).to eq "host"
        expect(config[:port]).to eq 1000
        expect(config[:encoding]).to eq "enc"
        expect(config[:collation]).to eq "coll"
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
                "timeout" => 5000,
                "encoding" => "enc",
                "collation" => "coll"
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
        expect(config.size).to eq 7
        expect(config[:adapter]).to eq "adapter_makara"
        expect(config[:database]).to eq "database"
        expect(config[:username]).to eq "username"
        expect(config[:host]).to eq "host"
        expect(config[:port]).to eq 1000
        expect(config[:encoding]).to eq "enc"
        expect(config[:collation]).to eq "coll"
      end

      it "parses database config with URL" do
        master_config = database_config["makara"]["connections"].first
        ["adapter", "database", "username", "host", "port"].each { |k| master_config.delete k }
        master_config['url'] = "adapter://username:password@host:1000/database?pool=1&timeout=1000&encoding=enc&collation=coll"

        config = subject.primary_database_configuration
        expect(config).not_to be_nil
        expect(config.size).to eq 7
        expect(config[:adapter]).to eq "adapter_makara"
        expect(config[:database]).to eq "database"
        expect(config[:username]).to eq "username"
        expect(config[:host]).to eq "host"
        expect(config[:port]).to eq 1000
        expect(config[:encoding]).to eq "enc"
        expect(config[:collation]).to eq "coll"
      end
    end
  end

  describe "mysql_deadlock_error_message?" do
    it "identifies 'Lock wait' message" do
      expect(subject.mysql_deadlock_error_message? "Something something, LOCK Wait timeout exceeded message").to eq true
    end

    it "identifies 'Deadlock' message" do
      expect(subject.mysql_deadlock_error_message? "Something something Deadlock found when trying to get lock message").to eq true
    end

    it "does not identify other messages" do 
      expect(subject.mysql_deadlock_error_message? "this is a generic error message").to eq false
    end
  end

  describe "run_in_separate_connection" do
    it "runs code in separate database connection context" do
      current_connection = ActiveRecord::Base.connection
      current_connection_count = ActiveRecord::Base.connection_pool.connections.length
      new_connection = nil
      result = subject.run_in_separate_connection do 
        # This ensures that the call above opened up a new distinct connection
        new_connection = ActiveRecord::Base.connection
        true
      end

      expect(current_connection.object_id).not_to eq new_connection.object_id
      expect(result).to eq true
    end

    it "utilizes connection pool checkouts" do
      # This test is kinda hacky, because it's basically just testing distinct method calls are being
      # executed, but it's important enough to ensure that these exact calls are used (since they
      # prevent database connection leakages from occuring) that I'm writing this test to ensure
      # they're utilized as so.
      
      expect(ActiveRecord::Base.connection_pool).to receive(:with_connection).and_yield
      expect(ActiveRecord::Base).to receive(:connection_pool).times.and_call_original


      subject.run_in_separate_connection { true }
    end
  end
end