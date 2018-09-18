# Errors of this type have been logged as part of InboundFile processing, but are also thrown by the
# IntegrationClientParser framework (unlike LoggedParserRejectionError).  Using or extending errors of this class
# simply avoids the double-InboundFile-logging of the error.  Since this class does not extend UnreportedError, the
# error will make the error log when it's thrown by IntegrationClientParser. Example usage: an expected importer
# record, one that is NOT looked up from some value in the file, is not found.  Errors of this type typically represent
# mistakes of ours (e.g. supporting data we forgot to set up, code bugs) rather than goofs in the data being parsed.
class LoggedParserFatalError < StandardError
end