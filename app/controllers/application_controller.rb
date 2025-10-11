class ApplicationController < ActionController::API

	private
	def authenticate_request
    	token = request.headers['Authorization']&.split(' ')&.last
    	payload = JsonWebToken.decode(token)
    	@current_user = User.find_by(id: payload[:user_id]) if payload
    	render_failure(message: 'Not Authorized', status: :unauthorized) unless @current_user
	end
	
	def current_user
		@current_user
	end

	def render_success(message: "Success", data: {})
		render json: { message: message, data: data }, status: :ok
	end

	def render_created(message: "Created", data: {})
		render json: { message: message, data: data }, status: :created
	end

	def render_failure(message: "Failure", errors: [], status: :unprocessable_entity)
		render json: { message: message, errors: errors }, status: status
	end

	def render_unauthorized(message: "Not Authorized")
		render json: { message: message }, status: :unauthorized
	end
end