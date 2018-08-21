# support LDAP(S) connections
if defined? ::Net::LDAP

  module Net::LDAP::Connection::FixSSLSocketSyncClose
    def close
      super
      # see: https://github.com/ruby-ldap/ruby-net-ldap/pull/314
      return if io.closed?
      io.close
    end
  end

  module TCR
    class RecordableTCPSocket
      include Net::LDAP::Connection::GetbyteForSSLSocket
      include Net::BER::BERParser
    end
  end
end
