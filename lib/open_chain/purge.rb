module OpenChain; class Purge

  def self.run_schedulable config
    now = Time.zone.now.change(sec: 0, usec: 0)
    reference_date = now

    years_ago = config['years_ago'].to_i
    if years_ago > 0
      reference_date = reference_date - years_ago.years
    end

    months_ago = config['months_ago'].to_i
    if months_ago > 0
      reference_date = reference_date - months_ago.months
    end

    days_ago = config['days_ago'].to_i
    if days_ago > 0
      reference_date = reference_date - days_ago.days
    end

    raise "You have not configured a data purge retention period." if now == reference_date

    purge_data_prior_to reference_date
  end

  def self.purge_data_prior_to reference_date
    History.delay.purge reference_date
    DebugRecord.delay.purge reference_date
    ErrorLogEntry.delay.purge reference_date
    FtpSession.delay.purge reference_date
    SentEmail.delay.purge reference_date
    CustomFile.delay.purge reference_date
    InboundFile.delay.purge reference_date
    # Use "Standard" timeframes for the following
    Message.delay.purge_messages
    ReportResult.delay.purge
    EntityComparatorLog.delay.purge

    # We don't want to use the reference_date because we retain an audit trail for 2 years
    RunAsSession.delay.purge
    RequestLog.delay.purge
  end

end; end;
