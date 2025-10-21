module CookieHelper
  def cookie_options
    if Rails.env.production?
      {
        domain: '.karya-app.com',
        secure: true,
        same_site: :lax
      }
    else
      {
        domain: 'localhost', # works with lvh.me for local subdomains
        secure: false,
        same_site: :none
      }
    end
  end
end