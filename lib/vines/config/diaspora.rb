# ############################################################## #
# Do NOT touch this file you'll find the options in diaspora.yml #
# ############################################################## #

Vines::Config.configure do
  log AppConfig.chat.server.log.file.to_s do
    level AppConfig.chat.server.log.level.to_sym
  end

  certs AppConfig.chat.server.certs.to_s

  max_offline_msgs AppConfig.chat.server.max_offline_msgs.to_i

  host diaspora_domain do
    cross_domain_messages AppConfig.chat.server.cross_domain_messages
    accept_self_signed AppConfig.chat.server.accept_self_signed
    storage 'sql'
  end

  client AppConfig.chat.server.c2s.address.to_s, AppConfig.chat.server.c2s.port.to_i do
    max_stanza_size AppConfig.chat.server.c2s.max_stanza_size.to_i
    max_resources_per_account AppConfig.chat.server.c2s.max_resources_per_account.to_i
  end

  server AppConfig.chat.server.s2s.address.to_s, AppConfig.chat.server.s2s.port.to_i do
    max_stanza_size AppConfig.chat.server.s2s.max_stanza_size.to_i
    blacklist AppConfig.chat.server.s2s.blacklist.get
  end

  http AppConfig.chat.server.bosh.address.to_s, AppConfig.chat.server.bosh.port.to_i do
    bind AppConfig.chat.server.bosh.bind.to_s
    max_stanza_size AppConfig.chat.server.bosh.max_stanza_size.to_i
    max_resources_per_account AppConfig.chat.server.bosh.max_resources_per_account.to_i
    root 'public'
    vroute ''
  end
end
