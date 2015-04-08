require 'spec_helper'

describe Lock do

  after :each do
    Lock.send(:flushall)
    Lock.class_variable_set :@@connection_pool, nil
  end

  describe "acquire_for_class" do
    it "should lock with fully qualified class name" do
      k = OpenChain::XLClient
      opts = {a:'b'}
      Lock.should_receive(:acquire).with('OpenChain::XLClient',opts).and_yield
      yield_value = Lock.acquire_for_class(k,opts) do
        'hello'
      end
      expect(yield_value).to eq 'hello'
    end
  end

  context :acquire do

    it "should lock while a process is running" do

      # Basically, we'll run two threads and make sure that the latter thread
      # blocks until the former one completes

      # Technically, we should also be checking across different processes but I have
      # no real clue how to do that at this time.

      sleepSeconds = 2
      run = false
      lockAcquired = false
      lock1ReturnValue = nil
      t1 = Thread.new {
        sleep (1.0 / 10.0) while !run
        ActiveRecord::Base.connection_pool.with_connection do
          lock1ReturnValue = Lock.acquire 'LockSpec' do
            lockAcquired = true
            # Make sure we can re-aquire the same lock from the same thread
            Lock.acquire 'LockSpec' do
              sleep sleepSeconds

              "Success"
            end
          end
        end
      }

      run = true
      start_blocking = nil
      end_blocking = nil
      t2 = Thread.new {
        sleep (1.0 / 100.0) while !lockAcquired
        start_blocking = Time.now
        # By using the lock's return value we're also validating
        # that Lock is correctly returning the block's value.
        ActiveRecord::Base.connection_pool.with_connection do
          end_blocking = Lock.acquire 'LockSpec' do
            Time.now
          end
        end
      }

      t1.join(10) if t1.status
      t2.join(1) if t2.status

      start_blocking.should_not be_nil
      end_blocking.should_not be_nil
      lock1ReturnValue.should == "Success"

      # Make sure the latter thread waited at least sleepSeconds to get the lock
      # (Due to thread scheduling and timing the sleeps might be slightly quicker that sleepSeconds)
      (end_blocking - start_blocking).should >= (sleepSeconds - 0.1)
      expect(Lock.send(:expires_in, 'LockSpec')).to be <= 300
      expect(Lock.send(:unlocked?, 'LockSpec')).to be_true
    end

    it "should release the lock if an error occurs in the first thread" do
      # Mainly verify the lock is released when something bad happens inside the passed in block

      started = false
      errored = nil
      t1 = Thread.new {
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            Lock.acquire 'LockSpec' do
              started = true
              raise Exception, "Failure"
            end
          end
        rescue Exception
          errored = true
        end
      }


      start_time = nil
      end_time = nil

      t2 = Thread.new {
        start_time = Time.now
        end_time = Lock.acquire 'LockSpec' do
          Time.now
        end
      }

      t1.join(5) if t1.status
      t2.join(1) if t2.status

      started.should be_true
      errored.should be_true
      start_time.should_not be_nil
      end_time.should_not be_nil

      # This is kind of an arbitrary amount of time to check for, but really
      # if the raised exception in the first thread doesn't release the lock
      # then the latter thread is going to block undefinitely anyway.
      (end_time - start_time).should <= 1.0
      expect(Lock.send(:expires_in, 'LockSpec')).to be <= 300
      expect(Lock.send(:unlocked?, 'LockSpec')).to be_true
    end

    it "yields inside of a transaction by default" do
      # By running in a thread, we can assert we're not in a transaction the
      # standard ActiveRecord way
      open_transactions = -1
      t = Thread.new {
        ActiveRecord::Base.connection_pool.with_connection do
          Lock.acquire('LockSpec', yield_in_transaction: true) {
            open_transactions = ActiveRecord::Base.connection.open_transactions
          }
        end
      }

      t.join(5) if t.status
      expect(open_transactions).to eq 1
    end

    it "yields outside a transaction if instructed" do
      # By running in a thread, we can assert we're not in a transaction the
      # standard ActiveRecord way
      open_transactions = -1
      t = Thread.new {
        ActiveRecord::Base.connection_pool.with_connection do
          Lock.acquire('LockSpec', yield_in_transaction: false) {
            open_transactions = ActiveRecord::Base.connection.open_transactions
          }
        end
      }

      t.join(5) if t.status
      expect(open_transactions).to eq 0
    end

    it "raises a timeout error when connection pool timesout" do
      # Need to rejigger the connection pool so it only allows a single connection checked out
      # at a time so we can force a timeout
      config = YAML.load_file('config/redis.yml')
      config['test']['pool_size'] = 1
      cp = ConnectionPool.new(size: 1, timeout: 1) do
        Lock.send(:get_redis_client, config['test'].with_indifferent_access)
      end
      Lock.stub(:get_connection_pool).and_return cp

      done = false
      lockAcquired = false
      end_time = Time.now + 3.seconds
      t1 = Thread.new {
        ActiveRecord::Base.connection_pool.with_connection do
          Lock.acquire('LockSpec') do
            lockAcquired = true
            sleep(0.1) while !done && Time.now < end_time
          end
        end
      }

      error = nil
      t2 = Thread.new {
        sleep (1.0 / 100.0) while !lockAcquired
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            Lock.acquire('LockSpec', timeout: 1) {}
          end
        rescue => e
          done = true
          error = e
        end
      }

      t1.join(5) if t1.status
      t2.join(1) if t2.status

      expect(error).not_to be_nil
      expect(error.message).to eq "Waited 1 second while attempting to acquire lock 'LockSpec'."
      # Just verify the backtrace has something about ConnectionPool in it...to show we're copying the backtrace
      # over
      expect(error.backtrace.first).to include("connection_pool")
    end

    it "raises timeout error when waiting for the semaphore lock times out" do
      done = false
      lockAcquired = false
      end_time = Time.now + 3.seconds
      t1 = Thread.new {
        ActiveRecord::Base.connection_pool.with_connection do
          Lock.acquire('LockSpec') do
            lockAcquired = true
            sleep(0.1) while !done && Time.now < end_time
          end
        end
      }

      error = nil
      t2 = Thread.new {
        sleep (1.0 / 100.0) while !lockAcquired
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            Lock.acquire('LockSpec', timeout: 1) {}
          end
        rescue => e
          done = true
          error = e
        end
      }

      t1.join(10) if t1.status
      t2.join(1) if t2.status

      expect(error).not_to be_nil
      expect(error.message).to eq "Waited 1 second while attempting to acquire lock 'LockSpec'."
      # Just verify the first frame of the backtrace comes from lock.rb, which means our code raised it
      # after a mutex timeout
      expect(error.backtrace.first).to include("lock.rb")
    end

    it "attempts to retry connecting if server is not reachable" do
      # Just have the connection pool raise the Redis::CannotConnectError, which tells our process
      # to sleep and try again to connect.
      Redis::Semaphore.any_instance.stub(:lock).and_raise Redis::CannotConnectError
      start = Time.now.to_i
      expect { Lock.acquire('LockSpec', timeout: 2) }.to raise_error Timeout::Error, "Waited 2 seconds while attempting to connect to lock server for lock 'LockSpec'."
      stop = Time.now.to_i
      expect(stop - start).to be >= 2
    end

    it "handles invalid UTF-8 encoded strings" do
      lock_name = "€foo\xA0"

      # Just short circuit the actual code by insisting the lock has already been seen to avoid
      # hassle of a bunch of other setup crap
      Lock.should_receive(:definitely_acquired?).with("€foo").and_return true

      locked = false
      Lock.acquire(lock_name) { locked = true}
      expect(locked).to be_true
    end

    it "transcodes lock names to UTF-8" do
      # Value used will be "foo", since € is not a valid ASCII char so the system won't
      # know how to translate when forcing the encoding
      lock_name = "€foo\xA0".force_encoding("ASCII")

      locked_name = nil
      Lock.should_receive(:definitely_acquired?) do |name|
        locked_name = name
        true
      end
      locked = false
      Lock.acquire(lock_name) { locked = true}
      expect(locked).to be_true
      expect(locked_name).to eq "foo"
      expect(locked_name.encoding.name).to eq "UTF-8"
    end
  end

  context :lock_with_retry do
    it "should lock an object and yield" do
      e = Factory(:entry)
      v = Lock.with_lock_retry(e) do
        e.update_attributes :entry_number => "123"
        "return val"
      end
      v.should == "return val"
      e.reload
      e.entry_number.should == "123"
    end

    it "should passthrough lock clause directory to with_lock call" do
      model = double("MyModel")
      model.should_receive(:with_lock).with("lock_clause")
      Lock.with_lock_retry(model, "lock_clause")
    end

    it "should retry lock aquisition 4 times by default" do
      e = double("MyModel")

      # We have to fake out the lock, since this test is, in-fact running in an open transaction
      Lock.should_receive(:inside_nested_transaction?).and_return false

      e.should_receive(:with_lock).and_raise ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"
      e.should_receive(:with_lock).and_raise ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"
      e.should_receive(:with_lock).and_raise ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"
      e.should_receive(:with_lock).and_raise ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"
      e.should_receive(:with_lock).once.ordered

      Lock.with_lock_retry(e)
    end

    it "should throw an error if it retries too many times" do
      # We have to fake out the lock, since this test is, in-fact running in an open transaction
      Lock.should_receive(:inside_nested_transaction?).and_return false

      # This also ensures that we're using the retry parameter
      e = double("MyModel")
      e.should_receive(:with_lock).exactly(3).and_raise ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"

      expect{Lock.with_lock_retry(e, true, 2)}.to raise_error ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"
    end
  end
end
