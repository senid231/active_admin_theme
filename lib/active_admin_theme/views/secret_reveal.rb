require_relative "../helpers/secret_reveal"

module ActiveAdminTheme
  module Views
    # secret_reveal(url: secret_admin_account_path(account))
    # secret_reveal(url: token_path, mask: "*****", method: :post)
    #
    # Shows the mask. A click requests the URL with fetch and shows the
    # `value` of the JSON reply; a second click hides it again. Nothing secret
    # is in the page until then. The endpoint must answer `{"value": "..."}`.
    #
    # secret_reveal(value: record.token)
    #
    # Inline mode: the value is in the page source, in an inert <template>,
    # and a click shows it without a request. It is always shown as text, even
    # an html_safe string, and may span lines. A blank value renders the
    # "empty" text. Prefer url: for credentials: it can be authorised and
    # logged per reveal.
    #
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
        inline = options.key?(:value)
        value = options.delete(:value)
        mask = options.delete(:mask) || "••••••••"
        method = (options.delete(:method) || :get).to_s.downcase.to_sym
        raise ArgumentError, "secret_reveal takes url: or value:, not both" if inline && url.present?
        raise ArgumentError, "secret_reveal needs url: or value:" if !inline && url.blank?
        raise ArgumentError, "secret_reveal method must be one of #{METHODS.join(", ")}, got #{method.inspect}" unless METHODS.include?(method)

        super(options)
        if inline && value.blank?
          add_class "attributes-table-empty-value"
          return text_node(I18n.t("active_admin.empty"))
        end

        add_class "aat-secret-reveal"
        set_attribute "data-aat-secret-reveal", ""
        unless inline
          set_attribute "data-url", url
          set_attribute "data-method", method.to_s.upcase
        end
        set_attribute "data-mask", mask
        button(type: "button", class: "aat-secret-reveal-toggle", title: "Click to reveal") do
          text_node EYE_ICON.html_safe
          text_node EYE_OFF_ICON.html_safe
          span(mask, class: "aat-secret-reveal-value")
        end
        # String.new drops html_safe, so the value is escaped like any text.
        text_node %(<template data-aat-secret-reveal-value>#{ERB::Util.html_escape(String.new(value.to_s))}</template>).html_safe if inline
        span("", class: "aat-secret-reveal-error", role: "alert", hidden: true)
      end
    end
  end
end
