# ############################################################## #
# Do NOT touch this file you'll find the options in diaspora.yml #
# ############################################################## #

Vines::Config.configure do
  log AppConfig.server.chat.server.log.file.to_s do
    level AppConfig.server.chat.server.log.level.to_sym
  end

  certs AppConfig.server.chat.server.certs.to_s

  host diaspora_domain do
    cross_domain_messages true
    storage 'sql'
  end

  client AppConfig.server.chat.server.c2s.address.to_s, AppConfig.server.chat.server.c2s.port.to_i do
    max_stanza_size AppConfig.server.chat.server.c2s.max_stanza_size.to_i
    max_resources_per_account AppConfig.server.chat.server.c2s.max_resources_per_account.to_i
  end

  server AppConfig.server.chat.server.s2s.address.to_s, AppConfig.server.chat.server.s2s.port.to_i do
    max_stanza_size AppConfig.server.chat.server.s2s.max_stanza_size.to_i
  end

  http AppConfig.server.chat.server.bosh.address.to_s, AppConfig.server.chat.server.bosh.port.to_i do
    bind AppConfig.server.chat.server.bosh.bind.to_s
    max_stanza_size AppConfig.server.chat.server.bosh.max_stanza_size.to_i
    max_resources_per_account AppConfig.server.chat.server.bosh.max_resources_per_account.to_i
    root 'public'
    vroute ''
  end
end
