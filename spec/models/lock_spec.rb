require 'spec_helper'

describe Lock do

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

        lock1ReturnValue = Lock.acquire 'LockSpec' do
          lockAcquired = true
          # Make sure we can re-aquire the same lock from the same thread
          Lock.acquire 'LockSpec' do
            sleep sleepSeconds

            "Success"
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
        end_blocking = Lock.acquire 'LockSpec' do

          Time.now
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
    end

    it "should release the lock if an error occurs in the first thread" do
      # Mainly verify the lock is released when something bad happens inside the passed in block

      started = false
      errored = nil
      t1 = Thread.new {
        begin
          Lock.acquire 'LockSpec' do
            started = true
            raise Exception, "Failure"
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
    end

    it "allows for temp locks to be used that clean up the lock name record" do
      started = nil
      Lock.acquire 'LockSpecTemp', :temp_lock=>true do
        started = true
      end

      expect(started).to be_true
      expect(Lock.find_by_name('LockSpecTemp')).to be_nil
    end

    it "removes temp locks when errors occur in yield block" do
      expect {
        Lock.acquire 'LockSpecTemp', :temp_lock=>true do
          raise "Blah"
        end  
      }.to raise_error "Blah"
      
      expect(Lock.find_by_name('LockSpecTemp')).to be_nil
    end

    it "handles temp locks being deleted by retrying transaction when attempting to lock" do
      lock = Lock.create! name: "TempLock"

      # To simulate the lock missing, we need to stub out the find_by_name method so that it returns
      # nil when it attempts to lock the Lock record the first time.  This should force a retry
      Lock.should_receive(:find_by_name).ordered.twice.with("TempLock").and_return(lock)
      Lock.should_receive(:find_by_name).ordered.twice.with("TempLock", lock: true).and_return(nil, lock)

      block_ran = false
      Lock.acquire('TempLock', temp_lock: true) { block_ran = true}
      expect(block_ran).to be_true
      expect(Lock.where(name:"TempLock").first).to be_nil
    end
  end

  context :retry_lock_aquire do

    it "should attempt to acquire lock multiple times" do
      Lock.should_receive(:acquired_lock).and_raise ActiveRecord::StatementInvalid, "Mysql2::Error: Lock wait timeout exceeded; try restarting transaction:"
      Lock.should_receive(:acquired_lock).and_raise ActiveRecord::StatementInvalid, "Mysql2::Error: Lock wait timeout exceeded; try restarting transaction:"
      Lock.should_receive(:acquired_lock).and_return true

      started = false
      Lock.acquire 'LockSpec', times: 2 do
        started = true
      end

      started.should be_true
    end

    it "should not attempt to retry and aquire locks when a lock wait timeout occurs inside the yielded block" do
      Lock.should_not_receive(:lock_wait_timeout?)

      started = false
      expect {
        Lock.acquire 'LockSpec', times: 5 do
          started = true
          raise ActiveRecord::StatementInvalid, "Mysql2::Error: Lock wait timeout exceeded; try restarting transaction:"
        end
      }.to raise_error ActiveRecord::StatementInvalid, "Mysql2::Error: Lock wait timeout exceeded; try restarting transaction:"

      started.should be_true
      Lock.definitely_acquired?('LockSpec').should be_false
    end

    it "should not attempt to retry lock acquisition on other errors" do 
      Lock.should_receive(:acquired_lock).and_raise ActiveRecord::StatementInvalid, "Mysql2::Error: ERROR!"

      started = false
      expect {
        Lock.acquire 'LockSpec', times: 5 do
          started = true
        end
      }.to raise_error ActiveRecord::StatementInvalid, "Mysql2::Error: ERROR!"

      started.should be_false
    end
  end

  context :lock_wait_timeout? do
    it "should identify a lock wait timeout exception by the message" do
      object = double()
      object.stub(:message).and_return "Mysql2::Error: Lock wait timeout exceeded; try restarting transaction:"

      Lock.lock_wait_timeout?(object).should be_true
    end

    it "should not-identify other exeptions as timeouts" do
      object = double()
      object.stub(:message).and_return "Runtime error"
      Lock.lock_wait_timeout?(object).should be_false
    end

    it "should be defensive about the error object" do
      object = double()
      object.stub(:message).and_return nil
      Lock.lock_wait_timeout?(object).should be_false
    end
  end

  context :locK_with_retry do
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
      e.should_receive(:with_lock).and_raise ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"
      e.should_receive(:with_lock).and_raise ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"
      e.should_receive(:with_lock).and_raise ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"
      e.should_receive(:with_lock).and_raise ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"
      e.should_receive(:with_lock).once.ordered

      Lock.with_lock_retry(e)
    end

    it "should throw an error if it retries too many times" do
      # This also ensures that we're using the retry parameter
      e = double("MyModel")
      e.should_receive(:with_lock).exactly(3).and_raise ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"

      expect{Lock.with_lock_retry(e, true, 2)}.to raise_error ActiveRecord::StatementInvalid, "Error: Lock wait timeout exceeded"
    end
  end
end