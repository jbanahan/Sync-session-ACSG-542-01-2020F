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
end