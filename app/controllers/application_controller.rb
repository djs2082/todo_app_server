class ApplicationController < ActionController::API
	include ActionController::Cookies

	private
	def authenticate_request
		@current_user = Authenticator.authenticate_request(request.headers['Authorization'])
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