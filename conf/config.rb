Vines::Config.configure do
  # Set the logging level to debug, info, warn, error, or fatal. The debug
  # level logs all XML sent and received by the server.
  # If you want logging to STDOUT remove the path
  # e.g. `log 'log/vines.log' do` becomes `log do`
  log 'log/vines.log' do
    level :info
  end

  # Set the directory in which to look for virtual hosts' TLS certificates.
  # This is optional and defaults to the conf/certs directory created during
  # `vines init`.
  certs 'conf/certs'

  # Setup a pepper to generate the encrypted password.
  pepper "065eb8798b181ff0ea2c5c16aee0ff8b70e04e2ee6bd6e08b49da46924223e39127d5335e466207d42bf2a045c12be5f90e92012a4f05f7fc6d9f3c875f4c95b"

  host 'diaspora' do
    cross_domain_messages true
    storage 'sql'
  end

  # Configure the client-to-server port. The max_resources_per_account attribute
  # limits how many concurrent connections one user can have to the server.
  client '0.0.0.0', 5222 do
    max_stanza_size 65536
    max_resources_per_account 5
  end

  # Configure the server-to-server port. The max_stanza_size attribute should be
  # much larger than the setting for client-to-server.
  server '0.0.0.0', 5269 do
    max_stanza_size 131072
    hosts []
  end

  # Configure the built-in HTTP server that serves static files and responds to
  # XEP-0124 BOSH requests. This allows HTTP clients to connect to
  # the XMPP server.
  http '0.0.0.0', 5280 do
    bind '/xmpp'
    max_stanza_size 65536
    max_resources_per_account 5
    root 'public'
    vroute ''
  end
end
