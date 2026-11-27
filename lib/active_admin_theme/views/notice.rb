require_relative "../helpers/notice"

module ActiveAdminTheme
  module Views
    # notice "Check the dates before you export", kind: :warning
    # notice(kind: :danger) { para "Payment failed" }
    #
    # A note inside the page: a tinted box with a colored edge, readable in
    # dark mode. `kind:` is info (the default), success, warning or danger.
    # A warning or danger is role="alert", the others role="status". The CSS
    # is components/notice.css. In ERB, use `notice_tag`: a view's own
    # `notice` is the flash text.
    class Notice < ActiveAdmin::Component
      builder_method :notice

      KINDS = %i[info success warning danger].freeze
      ALERT_KINDS = %i[warning danger].freeze

      def build(text = nil, options = {})
        text, options = nil, text if text.is_a?(Hash)
        options = options.dup
        kind = (options.delete(:kind) || :info).to_s.to_sym
        raise ArgumentError, "notice kind must be one of #{KINDS.join(", ")}, got #{kind.inspect}" unless KINDS.include?(kind)

        super(options)
        add_class "aat-notice"
        set_attribute "data-kind", kind.to_s
        set_attribute "role", ALERT_KINDS.include?(kind) ? "alert" : "status"
        text_node text.to_s if text
      end
    end
  end
end

# Loads every string helper as one module, ActiveAdminTheme::Helpers::Tags.
require_relative "../helpers/tags"
