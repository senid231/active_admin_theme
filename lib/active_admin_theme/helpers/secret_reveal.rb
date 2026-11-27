require_relative "arbre_string"

module ActiveAdminTheme
  module Helpers
    module SecretReveal
      include ArbreString

      # The secret_reveal component as an HTML string, with the arguments of
      # `secret_reveal`: secret_reveal_tag(value: record.token) or
      # secret_reveal_tag(url: token_path). With neither, it is an inline
      # blank value and shows the "empty" text.
      def secret_reveal_tag(value: nil, url: nil, mask: nil, **options)
        options[:url] = url if url.present?
        options[:value] = value unless value.nil? && url.present?
        options[:mask] = mask if mask
        aat_arbre { secret_reveal(options) }
      end
    end
  end
end

ActiveSupport.on_load(:action_view) { include ActiveAdminTheme::Helpers::SecretReveal }
