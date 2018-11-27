# Parse and return the domain from an Internet addr-spec.  Return value is
# normalised to lowercase.
#
# This implementation is the simplest thing that could possibly work.  Do
# not use this function to parse generalised mailbox or group addresses.
#
# See section 3.4 of RFC 2822.
def domain_from_addrspec(addrspec)
	(addrspec.split("@", 2)[1] or "").downcase
end
