# Errors of this type have been logged as part of InboundFile processing, and typically describe errors with data
# in the file being processed rather than transient errors like a database lock preventing a save; something
# the entity that provided the file could potentially fix on their end.  An example of this might be an 850 document
# that is missing a PO number.
class LoggedParserRejectionError < UnreportedError
end