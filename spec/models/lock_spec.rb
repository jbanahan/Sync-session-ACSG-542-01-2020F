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
  end

  context :retry_lock_aquire do

    it "should attempt to acquire lock multiple times" do
      Lock.should_receive(:acquired_lock).and_raise ActiveRecord::StatementInvalid, "Mysql2::Error: Lock wait timeout exceeded; try restarting transaction:"
      Lock.should_receive(:acquired_lock).and_raise ActiveRecord::StatementInvalid, "Mysql2::Error: Lock wait timeout exceeded; try restarting transaction:"
      Lock.should_receive(:acquired_lock).and_return true

      started = false
      Lock.acquire 'LockSpec', 2 do
        started = true
      end

      started.should be_true
    end

    it "should not attempt to retry and aquire locks when a lock wait timeout occurs inside the yielded block" do
      Lock.should_not_receive(:lock_wait_timeout?)

      started = false
      expect {
        Lock.acquire 'LockSpec', 5 do
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
        Lock.acquire 'LockSpec', 5 do
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
end