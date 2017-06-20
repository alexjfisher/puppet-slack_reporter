require 'puppet'
require 'puppet/util'
require 'yaml'
require 'fileutils'

begin
  require 'slack-notifier'
rescue LoadError => e
  Puppet.info 'You need the `slack-notifuer gem to use the slack report'
end

Puppet::Reports.register_report(:slack) do
  def process
    configfile = File.join([File.dirname(Puppet.settings[:config]), 'slack.yaml'])
    unless File.exist?(configfile)
      raise(Puppet::ParseError, "Slack report config file #{configfile} not readable")
    end
    config = YAML.load_file(configfile)
    Puppet.info "Sending report notification for #{host} to Slack."

    channel = if config['channel']
                config['channel']
              else
                '#default'
              end

    user = if config['username']
             config['username']
           else
             'puppet'
           end

    if config['proxy_url']
      uri = URI(config['proxy_url'])
      http_options = {
        proxy_address:  uri.hostname,
        proxy_port:     uri.port,
        proxy_from_env: false
      }
    else
      http_options = {}
    end

    # notifier = Slack::Notifier.new config['webhook'] do
    #   defaults channel:      channel,
    #            username:     user,
    #            http_options: http_options
    # end

    notifier = Slack::Notifier.new config['webhook'],
                                   channel: channel,
                                   username: user,
                                   http_options: http_options

    message = {
      author: 'Puppet Report',
      title:  "Puppet report for #{host}"
    }

    case status
    when 'changed'
      message.merge!(
        color: 'good',
        text:  "Puppet run completed on #{host} with changes",
        fallback: "Puppet run completed on #{host} with changes"
      )
    when 'failed'
      message.merge!(
        color: 'bad',
        text:  "Puppet run failed on #{host}",
        fallback: "Puppet run failed on #{host}"
      )
    when 'unchanged'
      message.merge!(
        color: 'good',
        text:  "Puppet run completed on #{host} with no changes",
        fallback: "Puppet run completed on #{host} with no changes"
      )
    end
    notifier.ping message[:fallback], attachments: [message]
  end
end
