module ActiveAdminTheme
  module Views
    # lazy_load(url: admin_account_history_path(account))
    # lazy_load(url: report_path, loading: "Building the report...", error: "No report")
    # lazy_load(url: report_path, eager: true)
    #
    # A placeholder that requests the URL with fetch when it scrolls into view
    # (a hidden tab loads when it is opened) and replaces its content with the
    # HTML of the reply. eager: true loads it as soon as the page is ready. The
    # endpoint answers an HTML fragment without the layout. A <script> in the
    # reply does not run. The element sends a bubbling `aat:lazy-load:loaded`
    # event after each load and reloads on `aat:lazy-load:reload`.
    #
    # Needs the opt-in module active_admin_theme/lazy_load; see
    # ActiveAdminTheme.javascripts.
    class LazyLoad < ActiveAdmin::Component
      builder_method :lazy_load

      METHODS = %i[get post put patch delete].freeze

      def build(options = {})
        options = options.dup
        url = options.delete(:url)
        method = (options.delete(:method) || :get).to_s.downcase.to_sym
        eager = options.delete(:eager)
        loading = options.delete(:loading) || I18n.t("active_admin_theme.lazy_load.loading", default: "Loading...")
        error = options.delete(:error) || I18n.t("active_admin_theme.lazy_load.error", default: "Could not load the content")
        raise ArgumentError, "lazy_load needs url:" if url.blank?
        raise ArgumentError, "lazy_load method must be one of #{METHODS.join(", ")}, got #{method.inspect}" unless METHODS.include?(method)

        super(options)
        add_class "aat-lazy-load"
        set_attribute "data-aat-lazy-load", ""
        set_attribute "data-url", url
        set_attribute "data-method", method.to_s.upcase
        set_attribute "data-error-text", error
        set_attribute "data-eager", "" if eager
        span(loading, class: "aat-lazy-load-placeholder", role: "status")
      end
    end
  end
end
