require 'fileutils'

class Domain
  attr_accessor :name
  attr_accessor :upstream

  def initialize(name, upstream, opts = {})
    @name = name
    @upstream = upstream if upstream.to_s != ''
    @opts = opts
  end

  def opt?(opt_key)
    @opts.has_key? opt_key.to_sym
  end

  def opt(opt_key)
    @opts[opt_key.to_sym]
  end

  def csr_path
    File.join(dir, 'domain.csr')
  end

  def signed_cert_path
    File.join(dir, 'signed.crt')
  end

  def chained_cert_path
    File.join(dir, 'chained.pem')
  end

  def key_path
    File.join(dir, 'domain.key')
  end

  def dir
    if NAConfig.production?
      "/var/lib/https-portal/#{name}"
    else
      "/var/lib/https-portal/#{name}-staging/"
    end
  end

  def www_root
    "/var/www/vhosts/#{name}"
  end

  def ensure_welcome_page
    return if upstream

    index_html = File.join(www_root, 'index.html')

    unless File.exists?(index_html)
      FileUtils.mkdir_p www_root

      File.open(index_html, 'w') do |file|
        file.write compiled_welcome_page
      end
    end
  end

  private

  def compiled_welcome_page
    binding_hash = {
      domain: self,
    }

    ERBBinding.new('/var/www/default/index.html.erb', binding_hash).compile
  end
end
