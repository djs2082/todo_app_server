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

		def render_failure(message: "Failure", errors: [], status: :unprocessable_entity, data: nil)
			payload = { message: message, errors: errors }
			payload[:data] = data unless data.nil?
			render json: payload, status: status
		end

	def render_unauthorized(message: "Not Authorized")
		render json: { message: message }, status: :unauthorized
	end

	# Override to add Sentry integration
	def rescue_with_handler(exception)
		if defined?(Sentry)
			Sentry.with_scope do |scope|
				scope.set_tags(handled_by: 'controller_rescue')
				scope.set_extras(
					params: request.filtered_parameters,
					path: request&.path,
					controller: self.class.name,
					action: action_name
				) rescue nil
				if respond_to?(:current_user) && current_user
					scope.set_user(id: current_user.id, email: current_user.email) rescue nil
				end
			end
			Sentry.capture_exception(exception)
		end
		super
	end

		# Helper for manual begin/rescue blocks in actions/services
	def capture_exception(exception, context: {})
		return unless defined?(Sentry)
		Sentry.with_scope do |scope|
			scope.set_tags(manual_capture: true)
			scope.set_extras(context) if context.present?
			Sentry.capture_exception(exception)
		end
	end
end