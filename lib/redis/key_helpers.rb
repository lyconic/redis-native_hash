class Redis
  module KeyHelpers

    def key
      @key ||= generate_key
    end

    def generate_key
      t = Time.now
      t.strftime('%Y%m%d%H%M%S.') + t.usec.to_s.rjust(6,'0') + '.' + SecureRandom.hex(16)
    end

    def redis_key(key = nil)
      key ||= self.key
      namespace.nil? ? key : "#{namespace}:#{key}"
    end

    def convert_key(key)
      key.to_s
    end
  end
end

