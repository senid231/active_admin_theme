require_relative "arbre_string"

module ActiveAdminTheme
  module Helpers
    module Notice
      include ArbreString

      # The notice component as an HTML string, with the arguments of
      # `notice`: notice_tag("Check the dates", kind: :warning). A block builds
      # the body with Arbre tags. In a view `notice` alone is the flash text,
      # so ERB uses this.
      def notice_tag(text = nil, **options, &block)
        arguments = [text, options].compact
        aat_arbre do
          body = block && proc { instance_exec(&block) }
          notice(*arguments, &body)
        end
      end
    end
  end
end

ActiveSupport.on_load(:action_view) { include ActiveAdminTheme::Helpers::Notice }
