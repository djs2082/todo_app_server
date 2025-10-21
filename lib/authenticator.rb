class Authenticator
  class << self
    include CookieHelper

    def access_token_ttl
      seconds = ENV.fetch('ACCESS_TOKEN_TTL_SECONDS', '900').to_i
      seconds.seconds
    end

    def refresh_token_ttl
      seconds = ENV.fetch('REFRESH_TOKEN_TTL_SECONDS', '604800').to_i
      seconds.seconds
    end

    def generate_access_token(user)
      payload = {
        user_id: user.id,
        email: user.email,
        type: 'access',
        jti: SecureRandom.uuid
      }
      JsonWebToken.encode(payload, access_token_ttl.from_now)
    end

    def generate_refresh_token(user)
      payload = {
        user_id: user.id,
        type: 'refresh',
        jti: SecureRandom.uuid
      }
      JsonWebToken.encode(payload, refresh_token_ttl.from_now)
    end

    def generate_token_pair(user)
      {
        access_token: generate_access_token(user),
        refresh_token: generate_refresh_token(user)
      }
    end

    def decode_token(token)
      JsonWebToken.decode(token)
    end

    def verify_access_token(token)
      payload = decode_token(token)
      return nil unless payload && payload[:type] == 'access'
      return nil if blacklisted?(payload[:jti])

      User.find_by(id: payload[:user_id])
    end

    def verify_refresh_token(token)
      payload = decode_token(token)
      return nil unless payload && payload[:type] == 'refresh'
      return nil if blacklisted?(payload[:jti])

      User.find_by(id: payload[:user_id])
    end

    def refresh_access_token(refresh_token)
      user = verify_refresh_token(refresh_token)
      return nil unless user

      generate_access_token(user)
    end

    def extract_token_from_header(authorization_header)
      return nil unless authorization_header
      authorization_header.split(' ').last
    end

    def blacklist!(jti:, token_type:, expires_at:)
      JwtBlacklist.create!(jti: jti, token_type: token_type, expires_at: expires_at)
    rescue ActiveRecord::RecordNotUnique
      true
    end

    def blacklisted?(jti)
      return false if jti.blank?
      JwtBlacklist.active.exists?(jti: jti)
    end

    def set_refresh_token_cookie(response, cookies, refresh_token)
      response.set_cookie(:refresh_token, {
        value: refresh_token,
        httponly: true,
        expires: refresh_token_ttl.from_now
      }.merge(cookie_options))
    end

    def clear_refresh_token_cookie(cookies)
      response.delete_cookie(:refresh_token)
    end

    def get_refresh_token_from_cookies(cookies)
      cookies[:refresh_token]
    end

    def authenticate_request(authorization_header)
      token = extract_token_from_header(authorization_header)
      return nil unless token

      verify_access_token(token)
    end
  end
end
