class JsonWebToken
  SECRET = ENV.fetch('JWT_SECRET') { Rails.application.secrets.secret_key_base || ENV['SECRET_KEY_BASE'] }

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET)
  end

  def self.decode(token)
    body = JWT.decode(token, SECRET)[0]
    HashWithIndifferentAccess.new body
  rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError => e
    nil
  end
end
