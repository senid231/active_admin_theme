require_relative "arbre_string"

module ActiveAdminTheme
  module Helpers
    module StatusTag
      include ArbreString

      # The status_tag component as an HTML string, with the arguments of
      # `status_tag`: status_tag_tag("Late", color: "#b91c1c").
      def status_tag_tag(status, label: nil, **options)
        options[:label] = label if label
        aat_arbre { status_tag(status, options) }
      end
    end
  end
end

ActiveSupport.on_load(:action_view) { include ActiveAdminTheme::Helpers::StatusTag }
