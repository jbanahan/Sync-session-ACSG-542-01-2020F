# This monkey patch fixes an issue in SFTP where it's attempted to close a socket on session end that
# is already closed by the server - which then raises an error on the session.
# Our fenixapp.vfitrack.net server exhibits this issues, this patch merely swallows all errors encountered in
# the session close.

module Net; module SFTP

  def self.start(host, user, options={}, &block)
    raise "A block must be given to the Net::SFTP.start method." unless block_given?

    begin
      Net::SSH.start(host, user, options) do |session|
        sftp = Net::SFTP::Session.new(session, &block).connect!
        sftp.loop
      end
    rescue Object => e
      # This is just handling a case where the server is closing the connect and the underlying socket is
      # actually closed, however it's not marked closed, but when ruby tries to actually close it
      # it raises an error.  There's basically nothing to be done here, so just swallow it.
      raise e unless e.is_a?(IOError) && e.message =~ /closed stream/i
    end
  end

end; end