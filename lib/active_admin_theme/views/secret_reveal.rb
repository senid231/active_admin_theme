module ActiveAdminTheme
  module Views
    # secret_reveal(url: secret_admin_account_path(account))
    # secret_reveal(url: token_path, mask: "*****", method: :post)
    #
    # Shows the mask. A click requests the URL with fetch and shows the
    # `value` of the JSON reply; a second click hides it again. Nothing secret
    # is in the page until then. The endpoint must answer `{"value": "..."}`.
    # Needs the opt-in module active_admin_theme/secret_reveal; see
    # ActiveAdminTheme.javascripts.
    class SecretReveal < ActiveAdmin::Component
      builder_method :secret_reveal

      METHODS = %i[get post put patch delete].freeze
      EYE_ICON = %(<svg class="aat-secret-reveal-icon" data-icon="reveal" role="img" aria-label="Reveal secret" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/></svg>).freeze
      EYE_OFF_ICON = %(<svg class="aat-secret-reveal-icon" data-icon="hide" role="img" aria-label="Hide secret" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.88 9.88a3 3 0 1 0 4.24 4.24"/><path d="M10.73 5.08A10.4 10.4 0 0 1 12 5c6.5 0 10 7 10 7a13.2 13.2 0 0 1-1.67 2.68"/><path d="M6.61 6.61A13.5 13.5 0 0 0 2 12s3.5 7 10 7a9.7 9.7 0 0 0 5.39-1.61"/><path d="m2 2 20 20"/></svg>).freeze

      def tag_name
        "span"
      end

      def build(options = {})
        options = options.dup
        url = options.delete(:url)
        mask = options.delete(:mask) || "••••••••"
        method = (options.delete(:method) || :get).to_s.downcase.to_sym
        raise ArgumentError, "secret_reveal needs url:" if url.blank?
        raise ArgumentError, "secret_reveal method must be one of #{METHODS.join(", ")}, got #{method.inspect}" unless METHODS.include?(method)

        super(options)
        add_class "aat-secret-reveal"
        set_attribute "data-aat-secret-reveal", ""
        set_attribute "data-url", url
        set_attribute "data-method", method.to_s.upcase
        set_attribute "data-mask", mask
        button(type: "button", class: "aat-secret-reveal-toggle", title: "Click to reveal") do
          text_node EYE_ICON.html_safe
          text_node EYE_OFF_ICON.html_safe
          span(mask, class: "aat-secret-reveal-value")
        end
        span("", class: "aat-secret-reveal-error", role: "alert", hidden: true)
      end
    end
  end
end
