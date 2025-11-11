class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    begin
      @user = User.from_omniauth(request.env["omniauth.auth"])

      if @user.persisted?
        auth = request.env["omniauth.auth"]
        @user.update(
          gmail_token: auth.credentials.token,
          gmail_refresh_token: auth.credentials.refresh_token
        )

        sign_in_and_redirect @user, event: :authentication
      else
        session["devise.google_data"] = request.env["omniauth.auth"].except(:extra)
        redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
      end
    rescue => e
      Rails.logger.error "OAuth error: #{e.message}"
      redirect_to root_path, alert: "Authentication failed. Please try again."
    end
  end

  def failure
    redirect_to root_path, alert: "Authentication failed. Please try again."
  end
end
