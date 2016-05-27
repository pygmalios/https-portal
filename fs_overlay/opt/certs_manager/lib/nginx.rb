require 'base64'

module Nginx
  def self.setup
    compiled_basic_config = ERBBinding.new('/var/lib/nginx-conf/nginx.conf.erb').compile

    File.open("/etc/nginx/nginx.conf" , 'w') do |f|
      f.write compiled_basic_config
    end
  end

  def self.config_http(domain)
    File.open("/etc/nginx/conf.d/#{domain.name}.conf" , 'w') do |f|
      f.write compiled_domain_config(domain, false)
    end

    reload
  end

  def self.config_ssl(domain)
    File.open("/etc/nginx/conf.d/#{domain.name}.ssl.conf" , 'w') do |f|
      f.write compiled_domain_config(domain, true)
    end

    reload
  end

  def self.start
    system 'nginx -q'
  end

  def self.reload
    system 'nginx -s reload'
  end

  def self.stop
    system 'nginx -s stop'
  end

  private

  def self.compiled_domain_config(domain, ssl)
    binding_hash = {
      domain: domain,
      acme_challenge_location: acme_challenge_location_snippet,
      dhparam_path: NAConfig.dhparam_path,
      hsts_opts: hsts_opts(domain),
      proxy_ssl_trusted_certificate_opts: proxy_ssl_trusted_certificate_opts(domain)
    }

    ERBBinding.new(template_path(domain, ssl), binding_hash).compile
  end

  def self.template_path(domain, ssl)
    ssl_ext = ssl ? '.ssl' : ''

    override = "/var/lib/nginx-conf/#{domain.name}#{ssl_ext}.conf.erb"
    default = "/var/lib/nginx-conf/default#{ssl_ext}.conf.erb"

    if File.exist? override
      override
    else
      default
    end
  end

  def self.acme_challenge_location_snippet
    <<-SNIPPET
      location /.well-known/acme-challenge/ {
          alias /var/www/default/challenges/;
          try_files $uri =404;
      }
    SNIPPET
  end

  def self.hsts_opts(domain)
    if domain.opt? :hsts
      hsts_max_age = domain.opt(:hsts) || 31536000
      hsts_opts = ["max-age=#{hsts_max_age}"]
      hsts_opts << 'includeSubDomains' if domain.opt? :hsts_subdomains
      hsts_opts << 'preload' if domain.opt? :hsts_preload
      hsts_opts_string = hsts_opts.join ';'
      "add_header Strict-Transport-Security \"#{hsts_opts_string}\";"
    else
      ''
    end
  end

  def self.proxy_ssl_trusted_certificate_opts(domain)
    if domain.opt? :proxy_ssl_trusted_certificate
      cert_tag = (domain.opt :proxy_ssl_trusted_certificate).upcase
      cert_path = "/tmp/ssl_trusted_certificate_#{cert_tag}"

      unless File.exist? cert_path
        cert_content = Base64.decode64 ENV[cert_tag]
        File.open cert_path, 'w' do |f|
          f.write cert_content
        end

        unless ENV[cert_tag]
          raise StandardError.new "Trusted certificate with tag #{cert_tag} is missing"
        end
      end

      "proxy_ssl_trusted_certificate #{cert_path};"
    else
      ''
    end
  end
end
